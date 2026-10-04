import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTSharedUI
import LUTJobs
import LUTFormats

@MainActor
final class FalseColourDocumentContractsTests:XCTestCase {
    private func settings()throws->TransformSettings {
        TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.sonySGamut3Cine,outputSpace:.sonySGamut3Cine,
            inputRange:.data,outputRange:.data,exposureStops:0,falseColour:try FalseColourSettings())
    }
    func testProjectDiskCubeIndependentNodesGammaEditSnapshotAnd1DRefusal() async throws {
        let domain=try LUTDomain(min:RGB64(-0.5,-0.5,-0.5),max:RGB64(16,16,16))
        var doc=try LUTProjectDocument(new:ProjectManifest(settings:settings(),cubeSize:33,domain:domain))
        let request=try doc.makeGenerationRequest(),folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:folder)}
        let project=folder.appendingPathComponent("false-colour.lutcalc")
        try doc.makeFileWrapper().write(to:project,options:.atomic,originalContentsURL:nil)
        let reopened=try LUTProjectDocument(fileWrapper:FileWrapper(url:project))
        XCTAssertEqual(reopened.manifest.settings.falseColour,try settings().falseColour)
        let editor=EditorSession();try editor.openProject(at:project)
        XCTAssertEqual(try editor.makeSnapshot().plan.settings.falseColour,try settings().falseColour)
        let file=folder.appendingPathComponent("false-colour.cube"),spi=folder.appendingPathComponent("false-colour.spi1d")
        _=try await NativeExportService().generate(request,to:file)
        let cube=try CubeParser.parse(Data(contentsOf:file))
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bytes=try Data(contentsOf:root.appendingPathComponent("tests/fixtures/native-contracts/false-colour-independent-defaults33.f64"))
        XCTAssertEqual(cube.samples.count,33*33*33)
        for i in 0..<cube.samples.count{for c in 0..<3{
            let bits=bytes.withUnsafeBytes{$0.loadUnaligned(fromByteOffset:(i*3+c)*8,as:UInt64.self)},y=Double(bitPattern:UInt64(littleEndian:bits))
            XCTAssertLessThanOrEqual(abs(cube.samples[i][c]-y)/max(1,abs(y)),2e-12)
        }}
        do{_=try await NativeExportService().generate(request,to:spi);XCTFail("False Colour must reject 1D")}
        catch{XCTAssertEqual(error as? SPI1DFailure,SPI1DFailure(.lossyRepresentation,line:0))}
        XCTAssertFalse(FileManager.default.fileExists(atPath:spi.path))
        let draft=ParameterizedGammaDraft(exponent:"2",linearSlope:"1",offset:"0",linearCut:"0",encodedCut:"")
        try doc.applyParameterizedGamma(draft,slot:.input,expectedRevision:doc.revision)
        try doc.applyParameterizedGamma(draft,slot:.output,expectedRevision:doc.revision)
        XCTAssertEqual(doc.manifest.settings.falseColour,request.plan.settings.falseColour)
        XCTAssertTrue(doc.undo());XCTAssertTrue(doc.redo());XCTAssertEqual(request.plan.settings.outputTransfer,.linearScene)
    }
    func testWorkersAndStage5Abort() async throws {
        let plan=try TransformPlan(settings:settings());var previous:[RGB64]?
        for workers in [1,4]{let sink=InMemoryCubeSink()
            _=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:plan,size:33,domain:.unit,workerCount:workers),sink:sink)
            let samples=await sink.samples
            if let previous{XCTAssertEqual(previous,samples)}else{previous=samples}
        }
        let d=Double.greatestFiniteMagnitude*0.95,domain=try LUTDomain(min:RGB64(d,d,d),max:RGB64(d*1.04,d*1.04,d*1.04)),sink=InMemoryCubeSink()
        do{_=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:plan,size:17,domain:domain,workerCount:1),sink:sink);XCTFail("Expected stage5 failure")}
        catch{XCTAssertEqual(error as? PlanError,.numeric(stageID:5,sampleIndex:0))}
        let state=await sink.state;XCTAssertEqual(state,.aborted)
    }
}

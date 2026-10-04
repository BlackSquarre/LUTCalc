import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTSharedUI
import LUTJobs
import LUTFormats

@MainActor
final class FinalOutputDocumentContractsTests:XCTestCase {
    private func settings()throws->TransformSettings {
        TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,finalOutput:try FinalOutputSettings(mode:.both,minimumCode10:-1023))
    }
    private func root()->URL {URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()}
    func testDiskCubeSPI1DIndependentNodesGammaEditAndSnapshot() async throws {
        let domain=try LUTDomain(min:RGB64(-0.5,-0.5,-0.5),max:RGB64(2,2,2))
        var doc=try LUTProjectDocument(new:ProjectManifest(settings:settings(),cubeSize:33,domain:domain))
        let request=try doc.makeGenerationRequest(),folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:folder)}
        let project=folder.appendingPathComponent("final-output.lutcalc")
        try doc.makeFileWrapper().write(to:project,options:.atomic,originalContentsURL:nil)
        let reopened=try LUTProjectDocument(fileWrapper:FileWrapper(url:project)),editor=EditorSession();try editor.openProject(at:project)
        XCTAssertEqual(reopened.manifest.settings.finalOutput,request.plan.settings.finalOutput)
        XCTAssertEqual(try editor.makeSnapshot().plan.settings.finalOutput,request.plan.settings.finalOutput)
        let cubeURL=folder.appendingPathComponent("final-output.cube"),spiURL=folder.appendingPathComponent("final-output.spi1d")
        _=try await NativeExportService().generate(request,to:cubeURL);_=try await NativeExportService().generate(request,to:spiURL)
        let cube=try CubeParser.parse(Data(contentsOf:cubeURL)),spi=try SPI1DParser.parse(Data(contentsOf:spiURL))
        let bytes=try Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/final-output-independent-data33.f64"))
        XCTAssertEqual(cube.samples.count,33*33*33)
        for i in 0..<cube.samples.count{for c in 0..<3{let bits=bytes.withUnsafeBytes{$0.loadUnaligned(fromByteOffset:(i*3+c)*8,as:UInt64.self)},y=Double(bitPattern:UInt64(littleEndian:bits))
            XCTAssertLessThanOrEqual(abs(cube.samples[i][c]-y)/max(1,abs(y)),2e-12)}}
        let f=try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/final-output-independent-reference.json"))) as! [String:Any]
        let expected=(f["axis1024"] as! [String]).map{Double($0)!};XCTAssertEqual(spi.lut.samples.count,1024)
        for i in 0..<1024{for c in 0..<3{XCTAssertLessThanOrEqual(abs(spi.lut.samples[i][c]-expected[i])/max(1,abs(expected[i])),2e-12)}}
        let draft=ParameterizedGammaDraft(exponent:"2",linearSlope:"1",offset:"0",linearCut:"0",encodedCut:"")
        try doc.applyParameterizedGamma(draft,slot:.input,expectedRevision:doc.revision);try doc.applyParameterizedGamma(draft,slot:.output,expectedRevision:doc.revision)
        XCTAssertEqual(doc.manifest.settings.finalOutput,request.plan.settings.finalOutput)
        XCTAssertTrue(doc.undo());XCTAssertTrue(doc.redo());XCTAssertEqual(request.plan.settings.outputTransfer,.linearScene)
    }
    func testWorkersAndStage19Abort() async throws {
        let plan=try TransformPlan(settings:settings());var previous:[RGB64]?
        for workers in [1,4]{let sink=InMemoryCubeSink()
            _=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:plan,size:33,domain:.unit,workerCount:workers),sink:sink)
            let samples=await sink.samples;if let previous{XCTAssertEqual(previous,samples)}else{previous=samples}
        }
        let domain=try LUTDomain(min:RGB64(1e306,1e306,1e306),max:RGB64(2e306,2e306,2e306)),sink=InMemoryCubeSink()
        do{_=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:plan,size:17,domain:domain,workerCount:1),sink:sink);XCTFail("Expected stage19 failure")}
        catch{XCTAssertEqual(error as? PlanError,.numeric(stageID:19,sampleIndex:0))}
        let state=await sink.state;XCTAssertEqual(state,.aborted)
    }
}

import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTSharedUI
import LUTJobs
import LUTFormats

@MainActor
final class DisplayConversionDocumentContractsTests:XCTestCase {
    private func root()->URL {URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()}
    private func settings()->TransformSettings {
        TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,
            displayConversion:DisplayConversionSettings(baseCurve:.rec709,outputCurve:.sceneReflectance,baseGamut:.rec2020,outputGamut:.p3DCI))
    }
    func testDiskCubeAndSPI1DIndependentReferenceGammaEditsAndSnapshot() async throws {
        let domain=try LUTDomain(min:RGB64(-0.5,-0.5,-0.5),max:RGB64(2,2,2))
        var doc=try LUTProjectDocument(new:ProjectManifest(settings:settings(),cubeSize:33,domain:domain))
        let request=try doc.makeGenerationRequest()
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:folder)}
        let project=folder.appendingPathComponent("display.lutcalc")
        try doc.makeFileWrapper().write(to:project,options:.atomic,originalContentsURL:nil)
        let reopened=try LUTProjectDocument(fileWrapper:FileWrapper(url:project))
        XCTAssertEqual(reopened.manifest.settings.displayConversion,settings().displayConversion)
        let editor=EditorSession();try editor.openProject(at:project)
        XCTAssertEqual(try editor.makeSnapshot().plan.settings.displayConversion,settings().displayConversion)
        let cubeURL=folder.appendingPathComponent("display.cube"),spiURL=folder.appendingPathComponent("display.spi1d")
        _=try await NativeExportService().generate(request,to:cubeURL)
        _=try await NativeExportService().generate(request,to:spiURL)
        let cube=try CubeParser.parse(Data(contentsOf:cubeURL)),spi=try SPI1DParser.parse(Data(contentsOf:spiURL))
        let expected=try Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/display-conversion-independent-p3dci33.f64"))
        XCTAssertEqual(cube.samples.count,33*33*33)
        for i in 0..<cube.samples.count {for c in 0..<3{
            let bits=expected.withUnsafeBytes{$0.loadUnaligned(fromByteOffset:(i*3+c)*8,as:UInt64.self)},y=Double(bitPattern:UInt64(littleEndian:bits))
            XCTAssertLessThanOrEqual(abs(cube.samples[i][c]-y)/max(1,abs(y)),2e-12)
        }}
        let axis=try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/display-conversion-export-reference.json"))) as! [String:Any]
        let expected1D=(axis["axis1024"] as! [String]).map{Double($0)!}
        XCTAssertEqual(spi.lut.samples.count,1024)
        for i in 0..<1024{for c in 0..<3{XCTAssertLessThanOrEqual(abs(spi.lut.samples[i][c]-expected1D[i])/max(1,abs(expected1D[i])),2e-12)}}
        XCTAssertNotEqual(cube.samples[32],try RGB64(expected1D[1023],expected1D[0],expected1D[0]))
        let draft=ParameterizedGammaDraft(exponent:"2",linearSlope:"1",offset:"0",linearCut:"0",encodedCut:"")
        try doc.applyParameterizedGamma(draft,slot:.input,expectedRevision:doc.revision)
        try doc.applyParameterizedGamma(draft,slot:.output,expectedRevision:doc.revision)
        XCTAssertEqual(doc.manifest.settings.displayConversion,settings().displayConversion)
        XCTAssertTrue(doc.undo());XCTAssertTrue(doc.redo())
        XCTAssertEqual(request.plan.settings.outputTransfer,.linearScene)
        XCTAssertEqual(request.plan.settings.displayConversion,settings().displayConversion)
    }
    func testWorkerDeterminismAndStage16Abort() async throws {
        let s=try settings().withGamutLimiter(GamutLimiterSettings(postLevel:0.6,secondarySpace:.srgb))
        let plan=try TransformPlan(settings:s);var previous:[RGB64]?
        for workers in [1,4]{
            let sink=InMemoryCubeSink()
            _=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:plan,size:33,domain:.unit,workerCount:workers),sink:sink)
            let samples=await sink.samples
            if let previous{XCTAssertEqual(previous,samples)}else{previous=samples}
        }
        let extreme=try TransformPlan(settings:settings().withDisplayConversion(DisplayConversionSettings(baseCurve:.gamma26,outputCurve:.sceneIRE)))
        let domain=try LUTDomain(min:RGB64(1e200,1e200,1e200),max:RGB64(2e200,2e200,2e200)),sink=InMemoryCubeSink()
        do{_=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:extreme,size:17,domain:domain,workerCount:1),sink:sink);XCTFail("Expected stage 16 failure")}
        catch{XCTAssertEqual(error as? PlanError,.numeric(stageID:16,sampleIndex:0))}
        let state=await sink.state;XCTAssertEqual(state,.aborted)
    }
}

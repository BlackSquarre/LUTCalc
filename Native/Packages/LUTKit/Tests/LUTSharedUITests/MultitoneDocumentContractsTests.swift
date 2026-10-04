import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTCatalog
import LUTSharedUI
import LUTFormats
import LUTJobs

@MainActor
final class MultitoneDocumentContractsTests: XCTestCase {
    func testStoredDocumentCubeReadbackUndoGammaSnapshotAnd1DRefusal() async throws {
        let mt=try MultitoneSettings(saturationByStop:Array(repeating:0.25,count:17),tones:[])
        let settings=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,
            inputSpace:.sonySGamut3Cine,outputSpace:.sonySGamut3Cine,inputRange:.data,outputRange:.data,
            exposureStops:0,multitone:mt)
        var doc=try LUTProjectDocument(new:ProjectManifest(settings:settings,cubeSize:33,domain:.unit))
        let snapshot=try doc.makeGenerationRequest()
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:folder)}
        let project=folder.appendingPathComponent("multitone.lutcalc")
        try doc.makeFileWrapper().write(to:project,options:.atomic,originalContentsURL:nil)
        let reopened=try LUTProjectDocument(fileWrapper:FileWrapper(url:project))
        XCTAssertEqual(reopened.manifest.settings.multitone,mt)
        let editor=EditorSession();try editor.openProject(at:project)
        XCTAssertEqual(try editor.makeSnapshot().plan.settings.multitone,mt)
        let cubeURL=folder.appendingPathComponent("multitone.cube")
        _=try await NativeExportService().generate(snapshot,to:cubeURL)
        let cube=try CubeParser.parse(Data(contentsOf:cubeURL))
        let l=0.21507582011558750019/32
        XCTAssertEqual(cube.samples[1].r,l+0.25*(1.0/32-l),accuracy:2e-12)
        XCTAssertEqual(cube.samples[1].g,l*0.75,accuracy:2e-12)
        let spiURL=folder.appendingPathComponent("invalid.spi1d")
        do{_=try await NativeExportService().generate(snapshot,to:spiURL);XCTFail("Coupling cannot be 1D")}
        catch{XCTAssertEqual((error as? SPI1DFailure)?.category,.lossyRepresentation)}
        XCTAssertFalse(FileManager.default.fileExists(atPath:spiURL.path))
        try doc.applyParameterizedGamma(ParameterizedGammaDraft(exponent:"2",linearSlope:"1",offset:"0",linearCut:"0",encodedCut:""),slot:.input,expectedRevision:doc.revision)
        XCTAssertEqual(doc.manifest.settings.multitone,mt)
        XCTAssertTrue(doc.undo());XCTAssertEqual(doc.manifest.settings.multitone,mt)
        XCTAssertTrue(doc.redo());XCTAssertEqual(doc.manifest.settings.multitone,mt)
        XCTAssertEqual(snapshot.plan.settings.multitone,mt)
    }
    func testWorkersAreDeterministicAndOverflowAbortsAtStage9() async throws {
        let settings=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,
            inputSpace:.sonySGamut3Cine,outputSpace:.sonySGamut3Cine,inputRange:.data,outputRange:.data,
            exposureStops:0,multitone:try MultitoneSettings(saturationByStop:Array(repeating:0.5,count:17),
                tones:[MultitoneTone(stop:0,hue:17,saturation:245)]))
        let plan=try TransformPlan(settings:settings)
        var previous:[RGB64]?
        for workers in [1,4] {
            let sink=InMemoryCubeSink()
            _=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:plan,size:33,domain:.unit,
                blockNodes:997,workerCount:workers),sink:sink)
            let samples=await sink.samples
            if let previous{XCTAssertEqual(previous,samples)}else{previous=samples}
        }
        XCTAssertThrowsError(try LUT1DGenerationRequest(plan:plan,size:1024,domain:.unit))
        let extreme=Double.greatestFiniteMagnitude
        let domain=try LUTDomain(min:RGB64(extreme*0.95,extreme*0.95,extreme*0.95),max:RGB64(extreme,extreme,extreme))
        let sink=InMemoryCubeSink()
        do{_=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:plan,size:17,domain:domain),sink:sink);XCTFail("Expected overflow")}
        catch{XCTAssertEqual(error as? PlanError,.numeric(stageID:9,sampleIndex:0))}
        let state=await sink.state;XCTAssertEqual(state,.aborted)
    }
}

import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTSharedUI
import LUTJobs
import LUTFormats

@MainActor
final class KneeDocumentContractsTests:XCTestCase {
    func testDiskRoundtripGenerationSnapshotsAndGammaEdits() async throws {
        let knee=try KneeSettings(startStops:-2,clipStops:4,clipSlope:1,smoothness:0.35,legal:false)
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,knee:knee)
        var doc=try LUTProjectDocument(new:ProjectManifest(settings:s,cubeSize:33,domain:.unit))
        let request=try doc.makeGenerationRequest()
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:folder)}
        let project=folder.appendingPathComponent("knee.lutcalc")
        try doc.makeFileWrapper().write(to:project,options:.atomic,originalContentsURL:nil)
        let reopened=try LUTProjectDocument(fileWrapper:FileWrapper(url:project))
        XCTAssertEqual(reopened.manifest.settings.knee,knee)
        let editor=EditorSession();try editor.openProject(at:project)
        XCTAssertEqual(try editor.makeSnapshot().plan.settings.knee,knee)
        let cubeURL=folder.appendingPathComponent("knee.cube")
        _=try await NativeExportService().generate(request,to:cubeURL)
        let cube=try CubeParser.parse(Data(contentsOf:cubeURL))
        let independent=try LegacyKnee(settings:knee,encodeLegacyToLegal:{$0*0.9})
        for i in [0,1,16,32] {
            let x=Double(i)/32,expected=try independent.evaluateLegacy(x/0.9,encodedLegal:x)
            XCTAssertEqual(cube.samples[i].r,expected,accuracy:2e-12)
        }
        let spiURL=folder.appendingPathComponent("knee.spi1d")
        _=try await NativeExportService().generate(request,to:spiURL)
        let spi=try SPI1DParser.parse(Data(contentsOf:spiURL))
        for i in [0,1,17,spi.lut.samples.count-1] {
            let x=Double(i)/Double(spi.lut.samples.count-1),expected=try independent.evaluateLegacy(x/0.9,encodedLegal:x)
            for c in 0..<3{XCTAssertEqual(spi.lut.samples[i][c],expected,accuracy:2e-12)}
        }
        try doc.applyParameterizedGamma(ParameterizedGammaDraft(exponent:"2",linearSlope:"1",offset:"0",linearCut:"0",encodedCut:""),slot:.output,expectedRevision:doc.revision)
        XCTAssertEqual(doc.manifest.settings.knee,knee)
        XCTAssertTrue(doc.undo());XCTAssertEqual(doc.manifest.settings.knee,knee)
        XCTAssertTrue(doc.redo());XCTAssertEqual(doc.manifest.settings.knee,knee)
        XCTAssertEqual(request.plan.settings.knee,knee)
        XCTAssertEqual(request.plan.settings.outputTransfer,.linearScene)
    }
    func testWorkersDeterministicAndStage13FailureAborts() async throws {
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,knee:try KneeSettings(startStops:-2,clipStops:4))
        let plan=try TransformPlan(settings:s)
        var previous:[RGB64]?
        for workers in [1,4] {
            let sink=InMemoryCubeSink()
            _=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:plan,size:33,domain:.unit,blockNodes:997,workerCount:workers),sink:sink)
            let samples=await sink.samples
            if let previous{XCTAssertEqual(samples,previous)}else{previous=samples}
        }
        let x=Double.greatestFiniteMagnitude,domain=try LUTDomain(min:RGB64(x*0.96,x*0.96,x*0.96),max:RGB64(x,x,x)),sink=InMemoryCubeSink()
        do{_=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:plan,size:17,domain:domain,workerCount:1),sink:sink);XCTFail("Expected stage 13 overflow")}
        catch{XCTAssertEqual(error as? PlanError,.numeric(stageID:13,sampleIndex:0))}
        let state=await sink.state;XCTAssertEqual(state,.aborted)
    }
}

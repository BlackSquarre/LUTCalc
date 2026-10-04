import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTSharedUI
import LUTJobs
import LUTFormats

@MainActor
final class BlackHighlightDocumentContractsTests:XCTestCase {
    func testDiskRoundtripCubeSPI1DAndLockedUnlockedGammaEdits() async throws {
        let level=try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.05,blackLock:true,highMap:0.85,highLock:true)
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,blackHighlight:level)
        var doc=try LUTProjectDocument(new:ProjectManifest(settings:s,cubeSize:33,domain:.unit))
        let request=try doc.makeGenerationRequest()
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:folder)}
        let project=folder.appendingPathComponent("black-highlight.lutcalc")
        try doc.makeFileWrapper().write(to:project,options:.atomic,originalContentsURL:nil)
        let reopened=try LUTProjectDocument(fileWrapper:FileWrapper(url:project))
        XCTAssertEqual(reopened.manifest.settings.blackHighlight,level)
        let editor=EditorSession();try editor.openProject(at:project)
        XCTAssertEqual(try editor.makeSnapshot().plan.settings.blackHighlight,level)
        let cubeURL=folder.appendingPathComponent("black-highlight.cube")
        _=try await NativeExportService().generate(request,to:cubeURL)
        let cube=try CubeParser.parse(Data(contentsOf:cubeURL))
        XCTAssertEqual(cube.samples[1].r,0.05+0.8/0.9/32,accuracy:2e-12)
        XCTAssertEqual(cube.samples[1].g,0.05,accuracy:2e-12);XCTAssertEqual(cube.samples[1].b,0.05,accuracy:2e-12)
        let spiURL=folder.appendingPathComponent("black-highlight.spi1d")
        _=try await NativeExportService().generate(request,to:spiURL)
        let spi=try SPI1DParser.parse(Data(contentsOf:spiURL))
        for i in [0,1,17,spi.lut.samples.count-1] {
            let expected=0.05+0.8*Double(i)/Double(spi.lut.samples.count-1)/0.9
            for c in 0..<3{XCTAssertEqual(spi.lut.samples[i][c],expected,accuracy:2e-12)}
        }
        let draft=ParameterizedGammaDraft(exponent:"2",linearSlope:"1",offset:"0",linearCut:"0",encodedCut:"")
        try doc.applyParameterizedGamma(draft,slot:.output,expectedRevision:doc.revision)
        XCTAssertEqual(doc.manifest.settings.blackHighlight,level)
        XCTAssertTrue(doc.undo());XCTAssertEqual(doc.manifest.settings.blackHighlight,level)
        XCTAssertTrue(doc.redo());XCTAssertEqual(doc.manifest.settings.blackHighlight,level)
        let unlocked=try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.05,highMap:0.85)
        var auto=try LUTProjectDocument(new:ProjectManifest(settings:s.withBlackHighlight(unlocked),cubeSize:33,domain:.unit))
        let oldRequest=try auto.makeGenerationRequest()
        try auto.applyParameterizedGamma(draft,slot:.output,expectedRevision:auto.revision)
        XCTAssertNil(auto.manifest.settings.blackHighlight?.blackLevel);XCTAssertNil(auto.manifest.settings.blackHighlight?.highMap)
        XCTAssertEqual(oldRequest.plan.settings.blackHighlight,unlocked)
        XCTAssertEqual(request.plan.settings.blackHighlight,level)
    }
    func testWorkersDeterministicAndStage14OverflowAborts() async throws {
        let level=try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.05,blackLock:true,highMap:0.85,highLock:true)
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.djiDLog2,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,blackGamma:try BlackGammaSettings(power:0.5),blackHighlight:level)
        let plan=try TransformPlan(settings:s)
        var previous:[RGB64]?
        for workers in [1,4] {
            let sink=InMemoryCubeSink()
            _=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:plan,size:33,domain:.unit,blockNodes:997,workerCount:workers),sink:sink)
            let samples=await sink.samples
            if let previous{XCTAssertEqual(previous,samples)}else{previous=samples}
        }
        let overflow=try BlackHighlightSettings(doHigh:true,highMap:Double.greatestFiniteMagnitude*0.5,highLock:true)
        let extreme=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,blackHighlight:overflow)
        let domain=try LUTDomain(min:RGB64(2,2,2),max:RGB64(3,3,3)),sink=InMemoryCubeSink()
        do{_=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:TransformPlan(settings:extreme),size:17,domain:domain,workerCount:1),sink:sink);XCTFail("Expected stage 14 overflow")}
        catch{XCTAssertEqual(error as? PlanError,.numeric(stageID:14,sampleIndex:0))}
        let state=await sink.state;XCTAssertEqual(state,.aborted)
    }
}

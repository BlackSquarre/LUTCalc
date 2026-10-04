import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTSharedUI
import LUTJobs
import LUTFormats

@MainActor
final class BlackGammaDocumentContractsTests: XCTestCase {
    func testDiskRoundtripSnapshotsGammaEditingAndIndependentCubeSPI1D() async throws {
        let gamma=try BlackGammaSettings(upperStops:0,featherStops:2,power:2)
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,
            outputSpace:.rec2020,inputRange:.data,outputRange:.data,exposureStops:0,blackGamma:gamma)
        var doc=try LUTProjectDocument(new:ProjectManifest(settings:s,cubeSize:33,domain:.unit))
        let snapshot=try doc.makeGenerationRequest()
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:folder)}
        let project=folder.appendingPathComponent("black-gamma.lutcalc")
        try doc.makeFileWrapper().write(to:project,options:.atomic,originalContentsURL:nil)
        let reopened=try LUTProjectDocument(fileWrapper:FileWrapper(url:project))
        XCTAssertEqual(reopened.manifest.settings.blackGamma,gamma)
        let editor=EditorSession();try editor.openProject(at:project)
        XCTAssertEqual(try editor.makeSnapshot().plan.settings.blackGamma,gamma)
        let cubeURL=folder.appendingPathComponent("black-gamma.cube")
        _=try await NativeExportService().generate(snapshot,to:cubeURL)
        let cube=try CubeParser.parse(Data(contentsOf:cubeURL))
        XCTAssertEqual(cube.samples[1].r,(1.0/32)*(1.0/32)/0.18,accuracy:2e-12)
        XCTAssertEqual(cube.samples[1].g,0);XCTAssertEqual(cube.samples[1].b,0)
        let spiURL=folder.appendingPathComponent("black-gamma.spi1d")
        _=try await NativeExportService().generate(snapshot,to:spiURL)
        let spi=try SPI1DParser.parse(Data(contentsOf:spiURL))
        for i in 1..<20 {
            let x=Double(i)/Double(spi.lut.samples.count-1)
            if x<=0.045{for c in 0..<3{XCTAssertEqual(spi.lut.samples[i][c],x*x/0.18,accuracy:2e-12)}}
        }
        try doc.applyParameterizedGamma(ParameterizedGammaDraft(exponent:"2",linearSlope:"1",offset:"0",linearCut:"0",encodedCut:""),slot:.input,expectedRevision:doc.revision)
        XCTAssertEqual(doc.manifest.settings.blackGamma,gamma)
        XCTAssertTrue(doc.undo());XCTAssertEqual(doc.manifest.settings.blackGamma,gamma)
        XCTAssertTrue(doc.redo());XCTAssertEqual(doc.manifest.settings.blackGamma,gamma)
        XCTAssertEqual(snapshot.plan.settings.blackGamma,gamma)
    }
    func testWorkerDeterminismAndWriteFailureAborts() async throws {
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.djiDLog2,inputSpace:.rec2020,
            outputSpace:.rec2020,inputRange:.data,outputRange:.video,exposureStops:0,
            blackGamma:try BlackGammaSettings(upperStops:0,featherStops:2,power:0.5))
        let plan=try TransformPlan(settings:s)
        var previous:[RGB64]?
        for worker in [1,4] {
            let sink=InMemoryCubeSink()
            _=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:plan,size:33,domain:.unit,
                blockNodes:997,workerCount:worker),sink:sink)
            let samples=await sink.samples
            if let previous{XCTAssertEqual(previous,samples)}else{previous=samples}
        }
        let sink=InMemoryCubeSink(failAtBlock:1)
        do{_=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:plan,size:17,domain:.unit,
            blockNodes:997,workerCount:1),sink:sink);XCTFail("Expected injected failure")}catch{}
        let state=await sink.state;XCTAssertEqual(state,.aborted)
    }
}

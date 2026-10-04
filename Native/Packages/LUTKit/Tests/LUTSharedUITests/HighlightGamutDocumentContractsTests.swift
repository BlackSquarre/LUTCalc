import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTSharedUI
import LUTJobs
import LUTFormats

@MainActor
final class HighlightGamutDocumentContractsTests:XCTestCase {
    func testDiskRoundtripCubeSnapshotEditsAnd1DRejection() async throws {
        let hg=try HighlightGamutSettings(highlightSpace:.srgb,lowStops:-1,highStops:3)
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.sonySGamut3Cine,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,knee:try KneeSettings(enabled:false),highlightGamut:hg)
        let domain=try LUTDomain(min:RGB64(-0.5,-0.5,-0.5),max:RGB64(2,2,2))
        var doc=try LUTProjectDocument(new:ProjectManifest(settings:s,cubeSize:33,domain:domain))
        let request=try doc.makeGenerationRequest()
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:folder)}
        let project=folder.appendingPathComponent("highlight.lutcalc")
        try doc.makeFileWrapper().write(to:project,options:.atomic,originalContentsURL:nil)
        let reopened=try LUTProjectDocument(fileWrapper:FileWrapper(url:project))
        XCTAssertEqual(reopened.manifest.settings.highlightGamut,hg)
        let editor=EditorSession();try editor.openProject(at:project)
        XCTAssertEqual(try editor.makeSnapshot().plan.settings.highlightGamut,hg)
        let output=folder.appendingPathComponent("highlight.cube")
        _=try await NativeExportService().generate(request,to:output)
        let cube=try CubeParser.parse(Data(contentsOf:output))
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let expectedBytes=try Data(contentsOf:root.appendingPathComponent("tests/fixtures/native-contracts/highlight-gamut-independent-linear33.f64"))
        XCTAssertEqual(cube.samples.count,33*33*33)
        for i in [0,1,16,32,33*16+32,33*33*33-1] {
            for c in 0..<3 {
                let bits=expectedBytes.withUnsafeBytes{$0.loadUnaligned(fromByteOffset:(i*3+c)*8,as:UInt64.self)}
                let expected=Double(bitPattern:UInt64(littleEndian:bits))
                XCTAssertLessThanOrEqual(abs(cube.samples[i][c]-expected)/max(1,abs(expected)),2e-12)
            }
        }
        let invalid=folder.appendingPathComponent("invalid.spi1d")
        do{_=try await NativeExportService().generate(request,to:invalid);XCTFail("Coupled Highlight Gamut cannot be exported as 1D")}
        catch{XCTAssertEqual((error as? SPI1DFailure)?.category,.lossyRepresentation)}
        XCTAssertFalse(FileManager.default.fileExists(atPath:invalid.path))
        try doc.applyParameterizedGamma(ParameterizedGammaDraft(exponent:"2",linearSlope:"1",offset:"0",linearCut:"0",encodedCut:""),slot:.output,expectedRevision:doc.revision)
        XCTAssertEqual(doc.manifest.settings.highlightGamut,hg)
        XCTAssertTrue(doc.undo());XCTAssertEqual(doc.manifest.settings.highlightGamut,hg)
        XCTAssertTrue(doc.redo());XCTAssertEqual(doc.manifest.settings.highlightGamut,hg)
        XCTAssertEqual(request.plan.settings.highlightGamut,hg)
        XCTAssertEqual(request.plan.settings.outputTransfer,.linearScene)
    }
    func testWorkerDeterminism1DRefusalAndStage10Abort() async throws {
        let hg=try HighlightGamutSettings(highlightSpace:.srgb,transition:.logarithmicStops,lowStops:-2,highStops:2)
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,highlightGamut:hg)
        let plan=try TransformPlan(settings:s)
        var previous:[RGB64]?
        for workers in [1,4] {
            let sink=InMemoryCubeSink()
            _=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:plan,size:33,domain:.unit,blockNodes:997,workerCount:workers),sink:sink)
            let samples=await sink.samples
            if let previous{XCTAssertEqual(samples,previous)}else{previous=samples}
        }
        XCTAssertThrowsError(try LUT1DGenerationRequest(plan:plan,size:1024,domain:.unit))
        let off=try TransformPlan(settings:s.withHighlightGamut(HighlightGamutSettings(enabled:false,highlightSpace:.srgb)))
        XCTAssertNoThrow(try LUT1DGenerationRequest(plan:off,size:1024,domain:.unit))
        let huge=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.sonySGamut3Cine,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,highlightGamut:hg)
        let x=Double.greatestFiniteMagnitude,domain=try LUTDomain(min:RGB64(x*0.92,0,0),max:RGB64(x*0.96,1,1)),sink=InMemoryCubeSink()
        do{_=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:TransformPlan(settings:huge),size:17,domain:domain,workerCount:1),sink:sink);XCTFail("Expected stage 10 failure")}
        catch{XCTAssertEqual(error as? PlanError,.numeric(stageID:10,sampleIndex:0))}
        let state=await sink.state;XCTAssertEqual(state,.aborted)
    }
}

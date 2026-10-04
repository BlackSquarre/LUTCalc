import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTCatalog
import LUTSharedUI
import LUTFormats
import LUTJobs

@MainActor
final class SDRSaturationDocumentContractsTests: XCTestCase {
    func testRealProjectReopenSnapshotCubeReadbackAnd1DRejection() async throws {
        let sat=try SDRSaturationSettings(gamma:2)
        let settings=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,
            inputSpace:.rec2020,outputSpace:.rec2020,inputRange:.data,outputRange:.data,
            exposureStops:0,sdrSaturation:sat)
        var document=try LUTProjectDocument(new:ProjectManifest(settings:settings,cubeSize:33,domain:.unit))
        let snapshot=try document.makeGenerationRequest()
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:folder)}
        let project=folder.appendingPathComponent("saturation.lutcalc")
        try document.makeFileWrapper().write(to:project,options:.atomic,originalContentsURL:nil)
        let reopened=try LUTProjectDocument(fileWrapper:FileWrapper(url:project))
        XCTAssertEqual(reopened.manifest.settings.sdrSaturation,sat)
        let editor=EditorSession();try editor.openProject(at:project)
        XCTAssertEqual(try editor.makeSnapshot().plan.settings.sdrSaturation,sat)
        let output=folder.appendingPathComponent("saturation.cube")
        _=try await NativeExportService().generate(snapshot,to:output)
        let cube=try CubeParser.parse(Data(contentsOf:output))
        let y=0.2627002120112671, q=sqrt(1.0/32/10.8), l=y*q
        XCTAssertEqual(cube.samples[1].r,(q+l*l-l)*10.8,accuracy:2e-12)
        XCTAssertEqual(cube.samples[1].g,(l*l-l)*10.8,accuracy:2e-12)
        XCTAssertLessThan(cube.samples[1].g,0)
        let spi=folder.appendingPathComponent("invalid.spi1d")
        do {_=try await NativeExportService().generate(snapshot,to:spi);XCTFail("Coupled stage cannot be 1D")}
        catch {XCTAssertEqual((error as? SPI1DFailure)?.category,.lossyRepresentation)}
        XCTAssertFalse(FileManager.default.fileExists(atPath:spi.path))
        try document.applyParameterizedGamma(ParameterizedGammaDraft(exponent:"2",linearSlope:"1",offset:"0",linearCut:"0",encodedCut:""),
            slot:.input,expectedRevision:document.revision)
        XCTAssertEqual(document.manifest.settings.sdrSaturation,sat)
        XCTAssertTrue(document.undo());XCTAssertEqual(document.manifest.settings.sdrSaturation,sat)
        XCTAssertTrue(document.redo());XCTAssertEqual(document.manifest.settings.sdrSaturation,sat)
        let updated=settings.withSDRSaturation(nil)
        XCTAssertNil(updated.sdrSaturation);XCTAssertEqual(snapshot.plan.settings.sdrSaturation,sat)
    }
    func testGenerationWorkerDeterminismAndEarly1DRefusal() async throws {
        let sat=try SDRSaturationSettings(gamma:1.2)
        let settings=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,
            inputSpace:.rec2020,outputSpace:.rec2020,inputRange:.data,outputRange:.data,
            exposureStops:0,sdrSaturation:sat)
        let plan=try TransformPlan(settings:settings)
        var previous:[RGB64]?
        for workers in [1,4] {
            let sink=InMemoryCubeSink()
            _=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:plan,size:33,domain:.unit,
                blockNodes:997,workerCount:workers),sink:sink)
            let samples=await sink.samples
            if let previous {XCTAssertEqual(samples,previous)} else {previous=samples}
        }
        XCTAssertThrowsError(try LUT1DGenerationRequest(plan:plan,size:1024,domain:.unit)) {
            XCTAssertEqual(($0 as? SPI1DFailure)?.category,.lossyRepresentation)
        }
        let disabled=try TransformPlan(settings:settings.withSDRSaturation(SDRSaturationSettings(enabled:false)))
        XCTAssertNoThrow(try LUT1DGenerationRequest(plan:disabled,size:1024,domain:.unit))
    }
}

import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTJobs
import LUTProject
import LUTCatalog
import LUTSharedUI

@MainActor
final class UserLUTPostStageDocumentContractsTests: XCTestCase {
    private func document() throws -> LUTProjectDocument {
        let settings = TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .acesAP0, outputSpace: .acesAP0, inputRange: .data, outputRange: .data, exposureStops: 0)
        var doc = try LUTProjectDocument(new: ProjectManifest(settings: settings, cubeSize:17, domain:.unit))
        let bytes = Data("LUT_1D_SIZE 3\n0 0 0\n0.25 0.25 0.25\n1 1 1\n".utf8)
        _ = try doc.storeImportedUserLUT(NativeUserLUTLoader.parse(bytes,named:"quadratic.cube"))
        return doc
    }
    func testSchema3StagePersistsThroughDiskUndoPresetAndEditorSnapshot() throws {
        var doc = try document()
        let old = doc.manifest
        let stage = UserLUTPostStageSettings(interpolation:.tricubicLegacyV1,outside:.reject)
        try doc.applyUserLUTPostStage(stage)
        let snapshot = try doc.makeGenerationRequest()
        XCTAssertEqual(snapshot.postLUTSettings,stage)
        XCTAssertEqual(doc.manifest.schemaVersion,ProjectManifest.currentSchema)
        XCTAssertTrue(doc.undo()); XCTAssertEqual(doc.manifest,old)
        XCTAssertTrue(doc.redo()); XCTAssertEqual(doc.manifest.userLUTPostStage,stage)
        let preset = try XCTUnwrap(AlgorithmCatalog.builtIn().preset(named:"dji.dlog2-to-dlog2-identity.v1"))
        try doc.applyPreset(preset)
        XCTAssertEqual(doc.manifest.userLUTPostStage,stage)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lutcalc-post-stage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let package = root.appendingPathComponent("stage.lutcalc")
        try doc.makeFileWrapper().write(to:package,options:.atomic,originalContentsURL:nil)
        let reopened = try LUTProjectDocument(fileWrapper:FileWrapper(url:package,options:.immediate))
        XCTAssertEqual(reopened.manifest,doc.manifest)
        XCTAssertEqual(reopened.assetContents,doc.assetContents)
        let session = EditorSession()
        try session.openProject(at:package)
        XCTAssertEqual(try session.makeSnapshot().postLUTSettings,stage)
        try doc.applyUserLUTPostStage(.init(interpolation:.trilinear,outside:.clampToDomain))
        XCTAssertEqual(snapshot.postLUTSettings,stage)
        XCTAssertNotEqual(snapshot.postLUTSettings,try doc.makeGenerationRequest().postLUTSettings)
    }
    func testOldSchemasKeepLegacyDefaultsAndNewFieldsFailClosed() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let doc = try document()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with:ProjectCodec.encode(doc.manifest,catalog:catalog)) as? [String:Any])
        for schema in [1,2] {
            var old = object
            old["schemaVersion"] = schema
            old.removeValue(forKey:"userLUTPostStage")
            if schema == 1 { old.removeValue(forKey:"assetRoles") }
            let migrated = try ProjectCodec.decode(JSONSerialization.data(withJSONObject:old),catalog:catalog)
            XCTAssertEqual(migrated.schemaVersion,ProjectManifest.currentSchema)
            XCTAssertNil(migrated.userLUTPostStage)
            old["userLUTPostStage"] = ["interpolation":"tricubicLegacyV1","outside":"reject"]
            XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:old),catalog:catalog))
        }
        object["schemaVersion"] = 3
        for invalid in [
            ["interpolation":"tricubicLegacyV1","outside":"reject","unknown":"field"],
            ["interpolation":"invented","outside":"reject"]
        ] {
            object["userLUTPostStage"] = invalid
            XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:object),catalog:catalog))
        }
        var empty = LUTProjectDocument()
        XCTAssertThrowsError(try empty.applyUserLUTPostStage(.init(interpolation:.tricubicLegacyV1,outside:.reject)))
        XCTAssertNil(empty.manifest.userLUTPostStage)
    }
    func testNativeExportPreservesCubicForCubeAndSPI1DAndRejectsPartialOutput() async throws {
        var doc = try document()
        try doc.applyUserLUTPostStage(.init(interpolation:.tricubicLegacyV1,outside:.reject))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lutcalc-cubic-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let request = try doc.makeGenerationRequest()
        let cubeURL = root.appendingPathComponent("cubic.cube")
        let cubeCount = try await NativeExportService().generate(request,to:cubeURL)
        XCTAssertEqual(cubeCount,4913)
        let cube = try CubeParser.parse(url:cubeURL)
        XCTAssertEqual(cube.samples[4].r,0.06296875,accuracy:2e-12)
        let spiURL = root.appendingPathComponent("cubic.spi1d")
        let spiCount = try await NativeExportService().generate(request,to:spiURL)
        XCTAssertEqual(spiCount,1024)
        let spi = try SPI1DParser.parse(url:spiURL)
        let x: Double = 256.0/1023
        let t = 2*x
        let expected: Double = 0.00375*t*t*t+0.2425*t*t+0.00375*t
        XCTAssertEqual(spi.lut.samples[256].r,expected,accuracy:2e-12)
        let failed = root.appendingPathComponent("must-not-exist.cube")
        let exposed = try LUTGenerationRequest(plan:TransformPlan(settings:doc.manifest.settings.withExposureStops(1)),
            size:17,domain:.unit,postLUT:request.postLUT,postLUTSettings:request.postLUTSettings)
        do { _ = try await NativeExportService().generate(exposed,to:failed); XCTFail("Expected reject") }
        catch { XCTAssertEqual(error as? VolumeError,.outsideDomain) }
        XCTAssertFalse(FileManager.default.fileExists(atPath:failed.path))
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath:root.path)),["cubic.cube","cubic.spi1d"])
    }

    func testCombinedAssetReopensAndExportsCoupledCubeWithoutLossyOneDOutput() async throws {
        let grid = try Grid3D(size:4,domain:.unit)
        let samples = try (0..<grid.nodeCount).map { i -> RGB64 in
            let p = try grid.coordinate(at:i)
            return try RGB64(p.r+p.g,p.g+p.b,p.r+p.b)
        }
        let shaper = try CubeShaper(size:3,domain:.unit,
            samples:[RGB64(0,0,0),RGB64(0.25,0.25,0.25),RGB64(1,1,1)])
        let lut = try CubeLUT(dimension:.three,size:4,domain:.unit,samples:samples,shaper:shaper)
        let bytes = Data(try CubeWriter.serialize(lut).utf8)
        let settings = TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,
            inputSpace:.acesAP0,outputSpace:.acesAP0,inputRange:.data,outputRange:.data,exposureStops:0)
        var doc = try LUTProjectDocument(new:ProjectManifest(settings:settings,cubeSize:17,domain:.unit))
        let path = try doc.storeImportedUserLUT(NativeUserLUTLoader.parse(bytes,named:"combined.cube"))
        XCTAssertThrowsError(try doc.makeGenerationRequest())
        try doc.applyUserLUTPostStage(.init(interpolation:.tricubicLegacyV1,outside:.reject))
        let reopened = try LUTProjectDocument(fileWrapper:doc.makeFileWrapper())
        XCTAssertEqual(reopened.assetContents[path],bytes)
        XCTAssertEqual(reopened.manifest.userLUTPostStage,doc.manifest.userLUTPostStage)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lutcalc-combined-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let cubeURL = root.appendingPathComponent("combined.cube")
        let request = try reopened.makeGenerationRequest()
        _ = try await NativeExportService().generate(request,to:cubeURL)
        let cube = try CubeParser.parse(url:cubeURL)
        XCTAssertEqual(cube.samples[4].r,0.06296875,accuracy:2e-12)
        XCTAssertEqual(cube.samples[4].g,0,accuracy:2e-12)
        XCTAssertEqual(cube.samples[4].b,0.06296875,accuracy:2e-12)
        let oneD = root.appendingPathComponent("forbidden.spi1d")
        do { _ = try await NativeExportService().generate(request,to:oneD); XCTFail("Expected coupled rejection") }
        catch { XCTAssertEqual((error as? SPI1DFailure)?.category,.lossyRepresentation) }
        XCTAssertFalse(FileManager.default.fileExists(atPath:oneD.path))
    }
}

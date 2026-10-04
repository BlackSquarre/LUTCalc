import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTJobs
import LUTProject
import LUTCatalog
import LUTSharedUI

@MainActor final class ProjectInputShaperContractsTests: XCTestCase {
    private func settings() -> TransformSettings {
        TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020, inputRange: .data, outputRange: .data, exposureStops: 0)
    }
    private func document(size: Int = 17) throws -> LUTProjectDocument {
        try LUTProjectDocument(new: ProjectManifest(settings: settings(), cubeSize: size, domain: .unit))
    }
    private func bytes(size: Int) -> Data {
        let rows = (0..<size).map { i -> String in
            let x = Double(i) / Double(size - 1)
            let value = (1023 * x * x).rounded(.toNearestOrAwayFromZero) / 1023
            return "\(value) \(value) \(value)"
        }.joined(separator: "\n")
        return Data("TITLE \"user nonlinear shaper\"\nLUT_1D_SIZE \(size)\nDOMAIN_MIN 0 0 0\nDOMAIN_MAX 1 1 1\n\(rows)\n".utf8)
    }
    private func root(_ name: String) throws -> URL {
        let base = ProcessInfo.processInfo.environment["LUTCALC_PROJECT_SHAPER_ARTIFACT_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let folder = base.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
    private func clean(_ folder: URL) {
        if ProcessInfo.processInfo.environment["LUTCALC_PROJECT_SHAPER_ARTIFACT_DIR"] == nil {
            try? FileManager.default.removeItem(at: folder.deletingLastPathComponent())
        }
    }
    private func add(_ doc: inout LUTProjectDocument, size: Int) throws -> String {
        try doc.storeImportedInputShaper(NativeUserLUTLoader.parse(bytes(size: size), named: "source.cube"))
    }
    private func reopen(_ doc: LUTProjectDocument, at url: URL) throws -> LUTProjectDocument {
        try doc.makeFileWrapper().write(to: url, options: .atomic, originalContentsURL: nil)
        return try LUTProjectDocument(fileWrapper: FileWrapper(url: url, options: .immediate))
    }

    func testOriginalAssetRoleHashAndDoubleRequestSurviveDiskReopen() throws {
        let folder = try root("asset"); defer { clean(folder) }
        var doc = try document()
        let original = bytes(size: 17)
        let source = folder.appendingPathComponent("source.cube"); try original.write(to: source)
        let path = try doc.storeImportedInputShaper(NativeUserLUTLoader.parse(Data(contentsOf: source), named: "source.cube"))
        XCTAssertEqual(doc.manifest.assetRoles[path], .inputShaper)
        XCTAssertTrue(doc.manifest.userLUTAssetPaths.isEmpty)
        XCTAssertEqual(doc.manifest.algorithmVersions["inputShaper"], ProjectInputShaperSettings.algorithm)
        XCTAssertEqual(doc.assetContents[path], original)
        let before = try doc.makeGenerationRequest()
        XCTAssertNil(before.postLUT); XCTAssertNil(before.inputTransferInverse)
        let reopened = try reopen(doc, at: folder.appendingPathComponent("shaped.lutcalc"))
        try FileManager.default.removeItem(at: source)
        XCTAssertEqual(reopened.manifest, doc.manifest)
        XCTAssertEqual(reopened.assetContents[path], original)
        XCTAssertEqual(try reopened.makeGenerationRequest().inputShaper, before.inputShaper)
        XCTAssertEqual(try ProjectStore.open(at: folder.appendingPathComponent("shaped.lutcalc"), catalog: AlgorithmCatalog.builtIn()), doc.manifest)
    }

    func testNonUnitDistinctChannelsRetainExplicitLinearSamplerWithoutQuantization() throws {
        var doc = try document()
        let original = Data("LUT_1D_SIZE 3\nDOMAIN_MIN -1 -2 -3\nDOMAIN_MAX 1 2 3\n-0.0 0.125 0.25\n0.3333333333333333 0.5 0.75\n1 0.875 1.25\n".utf8)
        let imported = try NativeUserLUTLoader.parse(original, named: "channels.cube")
        _ = try doc.storeImportedInputShaper(imported)
        let request = try doc.makeGenerationRequest()
        let shaper = try XCTUnwrap(request.inputShaper)
        XCTAssertEqual(shaper.domain, imported.lut.domain)
        for i in shaper.samples.indices { for c in 0..<3 {
            XCTAssertEqual(shaper.samples[i][c].bitPattern, imported.lut.samples[i][c].bitPattern)
        }}
        let sampled = try XCTUnwrap(request.inputShaperSampler).sample(RGB64(0, 0, 0), outside: .clampToDomain)
        XCTAssertEqual(sampled, imported.lut.samples[1])
        XCTAssertThrowsError(try ThreeDLWriter.header(size: 17, inputBits: 10, outputBits: 12, title: nil, shaper: shaper))
    }

    func testOldSchema24DiskMigrationDoesNotChangeSourceOrAddShaper() throws {
        let folder = try root("schema24"); defer { clean(folder) }
        let catalog = try AlgorithmCatalog.builtIn()
        var raw = try JSONSerialization.jsonObject(with: ProjectCodec.encode(document().manifest, catalog: catalog)) as! [String: Any]
        raw["schemaVersion"] = 24
        let original = try JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys])
        let url = folder.appendingPathComponent("old.lutcalc")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        try original.write(to: url.appendingPathComponent("manifest.json"))
        let migrated = try ProjectStore.open(at: url, catalog: catalog)
        XCTAssertEqual(migrated.schemaVersion, 25); XCTAssertNil(migrated.inputShaper)
        XCTAssertEqual(try Data(contentsOf: url.appendingPathComponent("manifest.json")), original)
    }

    func testStrictSchemaAlgorithmPathRoleAndDuplicateKeys() throws {
        var doc = try document(); let path = try add(&doc, size: 17)
        let catalog = try AlgorithmCatalog.builtIn(), data = try ProjectCodec.encode(doc.manifest, catalog: catalog)
        let raw = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        for field in ["algorithm", "assetPath"] {
            var bad = raw, object = raw["inputShaper"] as! [String: Any]
            object[field] = field == "algorithm" ? "unknown" : "Resources/missing.cube"; bad["inputShaper"] = object
            XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: bad), catalog: catalog))
        }
        var unknown = raw, object = raw["inputShaper"] as! [String: Any]
        object["interpolation"] = "cubic"; unknown["inputShaper"] = object
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: unknown), catalog: catalog))
        var role = raw; role["assetRoles"] = [path: "other"]
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: role), catalog: catalog))
        var versions = raw, v = raw["algorithmVersions"] as! [String: String]
        v.removeValue(forKey: "inputShaper"); versions["algorithmVersions"] = v
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: versions), catalog: catalog))
        for schema in 1...24 {
            var old = raw; old["schemaVersion"] = schema
            let bytes = try JSONSerialization.data(withJSONObject: old)
            XCTAssertThrowsError(try ProjectCodec.decode(bytes, catalog: catalog))
            XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self, from: bytes))
        }
        var oldRole = raw; oldRole["schemaVersion"] = 24; oldRole.removeValue(forKey: "inputShaper")
        var oldV = v; oldV.removeValue(forKey: "inputShaper"); oldRole["algorithmVersions"] = oldV
        let oldBytes = try JSONSerialization.data(withJSONObject: oldRole)
        XCTAssertThrowsError(try ProjectCodec.decode(oldBytes, catalog: catalog))
        XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self, from: oldBytes))
        let duplicate = try XCTUnwrap(String(data: data, encoding: .utf8))
            .replacingOccurrences(of: "\"assetPath\":\"\(path)\"", with: "\"assetPath\":\"\(path)\",\"assetPath\":\"\(path)\"")
        XCTAssertThrowsError(try ProjectCodec.decode(Data(duplicate.utf8), catalog: catalog))
    }

    func testInvalidImportAndInverseConflictAreTransactional() throws {
        var doc = try document(); let baseline = doc.manifest
        let rows = try (0..<8).map { i -> RGB64 in
            let r = Double(i % 2), g = Double((i / 2) % 2), b = Double(i / 4)
            return try RGB64(r, g, b)
        }
        let threeD = try CubeLUT(dimension: .three, size: 2, domain: .unit, samples: rows)
        let raw = Data(try CubeWriter.serialize(threeD).utf8)
        XCTAssertThrowsError(try doc.storeImportedInputShaper(NativeUserLUTLoader.parse(raw, named: "volume.cube")))
        XCTAssertEqual(doc.manifest, baseline); XCTAssertTrue(doc.assetContents.isEmpty)
        _ = try add(&doc, size: 17)
        let withShaper = doc.manifest
        XCTAssertThrowsError(try add(&doc, size: 17)); XCTAssertEqual(doc.manifest, withShaper)
        let user = try doc.storeImportedUserLUT(NativeUserLUTLoader.parse(bytes(size: 17), named: "post.cube"))
        let before = doc.manifest
        XCTAssertThrowsError(try doc.applyUserLUTInputInverse(UserLUTInputInverseSettings(assetPath: user, interpolation: .tricubicLegacyV1)))
        XCTAssertEqual(doc.manifest, before)
        try doc.applyInputShaper(nil)
        try doc.applyUserLUTInputInverse(UserLUTInputInverseSettings(assetPath: user, interpolation: .tricubicLegacyV1))
        let inverse = doc.manifest
        XCTAssertThrowsError(try doc.applyInputShaper(withShaper.inputShaper))
        XCTAssertEqual(doc.manifest, inverse)
    }

    func testHashTamperAndWrongDimensionRejectEvenWithUpdatedHash() throws {
        var doc = try document(); let path = try add(&doc, size: 17)
        let wrapper = try doc.makeFileWrapper()
        let resources = try XCTUnwrap(wrapper.fileWrappers?["Resources"])
        let filename = String(path.dropFirst("Resources/".count))
        resources.removeFileWrapper(try XCTUnwrap(resources.fileWrappers?[filename]))
        let invalid = Data("LUT_3D_SIZE 2\n0 0 0\n1 0 0\n0 1 0\n1 1 0\n0 0 1\n1 0 1\n0 1 1\n1 1 1\n".utf8)
        let asset = FileWrapper(regularFileWithContents: invalid); asset.preferredFilename = filename; resources.addFileWrapper(asset)
        XCTAssertThrowsError(try LUTProjectDocument(fileWrapper: wrapper))
        var raw = try JSONSerialization.jsonObject(with: ProjectCodec.encode(doc.manifest, catalog: AlgorithmCatalog.builtIn())) as! [String: Any]
        raw["assetHashes"] = [path: ProjectAssets.sha256(of: invalid)]
        wrapper.removeFileWrapper(try XCTUnwrap(wrapper.fileWrappers?["manifest.json"]))
        let manifest = FileWrapper(regularFileWithContents: try JSONSerialization.data(withJSONObject: raw))
        manifest.preferredFilename = "manifest.json"; wrapper.addFileWrapper(manifest)
        XCTAssertThrowsError(try LUTProjectDocument(fileWrapper: wrapper))
    }

    func testUndoRedoDerivedSettingsAndSnapshotPreserveShaper() throws {
        var doc = try document(); _ = try add(&doc, size: 17)
        let saved = doc.manifest.inputShaper
        let snapshot = try doc.makeGenerationRequest()
        try doc.applyInputShaper(nil); XCTAssertNil(try doc.makeGenerationRequest().inputShaper)
        XCTAssertTrue(doc.undo()); XCTAssertEqual(doc.manifest.inputShaper, saved)
        XCTAssertTrue(doc.redo()); XCTAssertNil(doc.manifest.inputShaper)
        XCTAssertNotNil(snapshot.inputShaper)
        try doc.applyInputShaper(saved)
        let preset = try XCTUnwrap(AlgorithmCatalog.builtIn().presets.first)
        try doc.applyPreset(preset); XCTAssertEqual(doc.manifest.inputShaper, saved)
        let batch = try ExposureBatchPreset(sequence: ExposureBatchSequence(minimumStops: -1, maximumStops: 0, subdivisions: 1), basename: "batch", format: .threeDL)
        try doc.applyExposureBatchPreset(batch); XCTAssertEqual(doc.manifest.inputShaper, saved)
        try doc.applyUserLUTPostStage(nil); XCTAssertEqual(doc.manifest.inputShaper, saved)
        try doc.applyUserLUTInputInverse(nil); XCTAssertEqual(doc.manifest.inputShaper, saved)
    }

    func testReopenedProjectGeneratesFullThreeDLFlavorAndGridMatrix() async throws {
        for flavor in [ThreeDLFlavor.flame, .lustre, .kodak] { for size in [17, 33, 65] {
            let folder = try root("\(flavor.rawValue)-\(size)"); defer { clean(folder) }
            var doc = try document(size: size); _ = try add(&doc, size: size)
            try doc.applyExposureBatchPreset(ExposureBatchPreset(
                sequence: ExposureBatchSequence(minimumStops: -1, maximumStops: 0, subdivisions: 1),
                basename: "batch", format: .threeDL, blockNodes: 127, workerCount: 4, threeDLFlavor: flavor))
            let before = try doc.makeStoredExposureBatchRequest(directory: folder)
            let reopened = try reopen(doc, at: folder.appendingPathComponent("shaped.lutcalc"))
            let request = try reopened.makeStoredExposureBatchRequest(directory: folder)
            XCTAssertEqual(before.fingerprint, request.fingerprint)
            XCTAssertEqual(request.items.map(\.request.inputShaper), before.items.map(\.request.inputShaper))
            let report = try await ExposureBatchCoordinator().generate(request, exporter: NativeExportService())
            XCTAssertEqual(report.state, .completed)
            XCTAssertEqual(report.items.map(\.writtenNodes), [size * size * size, size * size * size])
            for item in request.items {
                let lut = try ThreeDLParser.parse(Data(contentsOf: item.url), flavor: flavor)
                XCTAssertEqual(lut.shaper, item.request.inputShaper)
            }
        }}
    }

    func testOtherFormatsRejectBeforeCreatingOutput() async throws {
        let folder = try root("rejected"); defer { clean(folder) }
        var doc = try document(); _ = try add(&doc, size: 17)
        let request = try doc.makeGenerationRequest()
        for format in FileLUTFormat.allCases where format != .threeDL {
            let output = folder.appendingPathComponent("rejected.\(format.rawValue)")
            do { _ = try await NativeExportService().generate(request, to: output); XCTFail("Must reject omitted shaper") }
            catch { XCTAssertEqual(error as? NativeExportError, .threeDLShaperRequiresThreeDL) }
            XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        }
    }

    func testEditorSessionSnapshotAndSettingsEditPreserveReopenedShaper() throws {
        let folder = try root("editor-session"); defer { clean(folder) }
        var doc = try document(); _ = try add(&doc, size: 17)
        let url = folder.appendingPathComponent("shaped.lutcalc")
        _ = try reopen(doc, at: url)
        let session = EditorSession()
        try session.openProject(at: url)
        XCTAssertEqual(try session.makeSnapshot().inputShaper, try doc.makeGenerationRequest().inputShaper)
        session.setCubeSize(33)
        XCTAssertEqual(try session.makeSnapshot().inputShaper, try doc.makeGenerationRequest().inputShaper)
        try session.saveProject()
        let reopened = try LUTProjectDocument(fileWrapper: FileWrapper(url: url, options: .immediate))
        XCTAssertEqual(reopened.manifest.inputShaper, doc.manifest.inputShaper)
        XCTAssertEqual(reopened.manifest.cubeSize, 33)
    }
}

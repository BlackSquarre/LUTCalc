import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTCatalog
import LUTProject

final class ExposureBatchPresetProjectContractsTests: XCTestCase {
    private func settings() -> TransformSettings {
        TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020, inputRange: .data, outputRange: .data, exposureStops: 0)
    }
    func testSchema16AllFormatsIdentityAndOldSchemaMigrationWithoutWritingSource() throws {
        let catalog = try AlgorithmCatalog.builtIn(), sequence = try ExposureBatchSequence(minimumStops: -2, maximumStops: 2, subdivisions: 3)
        for format in LUTExportFormat.allCases {
            let preset = try ExposureBatchPreset(sequence: sequence, basename: "曝光预设", format: format, blockNodes: 17, workerCount: 4)
            let document = ProjectManifest(settings: settings(), cubeSize: 33, domain: .unit, exposureBatchPreset: preset)
            XCTAssertEqual(document.schemaVersion, ProjectManifest.currentSchema)
            XCTAssertEqual(document.algorithmVersions["exposureBatchPreset"], "native.exposure-batch-rational.v1")
            XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(document, catalog: catalog), catalog: catalog), document)
            for schema in 1...15 {
                var raw = try JSONSerialization.jsonObject(with: ProjectCodec.encode(document, catalog: catalog)) as! [String: Any]
                raw["schemaVersion"] = schema
                let invalid = try JSONSerialization.data(withJSONObject: raw)
                XCTAssertThrowsError(try ProjectCodec.decode(invalid, catalog: catalog))
                XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self, from: invalid))
                raw.removeValue(forKey: "exposureBatchPreset")
                var versions = raw["algorithmVersions"] as! [String: String]
                versions.removeValue(forKey: "exposureBatchPreset")
                versions.removeValue(forKey: "exposureBatchFormat"); raw["algorithmVersions"] = versions
                if schema == 1 { raw.removeValue(forKey: "assetRoles") }
                let bytes = try JSONSerialization.data(withJSONObject: raw)
                let migrated = try ProjectCodec.decode(bytes, catalog: catalog)
                XCTAssertEqual(migrated.schemaVersion, ProjectManifest.currentSchema); XCTAssertNil(migrated.exposureBatchPreset)
                if schema == 15 && format == .cube {
                    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    let package = root.appendingPathComponent("schema15.lutcalc")
                    try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
                    defer { try? FileManager.default.removeItem(at: root) }
                    let manifestURL = package.appendingPathComponent("manifest.json")
                    try bytes.write(to: manifestURL)
                    let original = try Data(contentsOf: manifestURL)
                    XCTAssertEqual(try ProjectStore.open(at: package, catalog: catalog), migrated)
                    XCTAssertEqual(try Data(contentsOf: manifestURL), original)
                    let session = try ProjectEditingSession(opening: package, catalog: catalog)
                    XCTAssertEqual(session.current, migrated)
                    XCTAssertEqual(try Data(contentsOf: manifestURL), original)
                    let stored = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as! [String: Any]
                    XCTAssertEqual(stored["schemaVersion"] as? Int, 15)
                    if let artifact = ProcessInfo.processInfo.environment["LUTCALC_BATCH_PRESET_ARTIFACT_DIR"] {
                        let target = URL(fileURLWithPath: artifact).appendingPathComponent("schema15-" + UUID().uuidString)
                        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                        try FileManager.default.copyItem(at: package, to: target.appendingPathComponent("schema15.lutcalc"))
                        try original.write(to: target.appendingPathComponent("manifest-before.json"))
                        try Data(contentsOf: manifestURL).write(to: target.appendingPathComponent("manifest-after.json"))
                    }
                }
            }
        }
    }
    func testStrictPresetFieldsSequenceAlgorithmAndSchedulingBounds() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let preset = try ExposureBatchPreset(sequence: ExposureBatchSequence(), basename: "preset", format: .cube)
        let manifest = ProjectManifest(settings: settings(), cubeSize: 33, domain: .unit, exposureBatchPreset: preset)
        let bytes = try ProjectCodec.encode(manifest, catalog: catalog)
        let mutations: [(String, Any)] = [("algorithm", "unknown"), ("format", "ncp"), ("basename", "../escape"),
            ("workerCount", 0), ("workerCount", 5), ("blockNodes", 0), ("directory", "/tmp"), ("allowOverwrite", true), ("extra", 1)]
        for (key, value) in mutations {
            var raw = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
            var object = raw["exposureBatchPreset"] as! [String: Any]
            object[key] = value; raw["exposureBatchPreset"] = object
            XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: raw), catalog: catalog))
        }
        for sequence in [["minimumStops": 1, "maximumStops": -1, "subdivisions": 3],
            ["minimumStops": -2, "maximumStops": 2, "subdivisions": 0],
            ["minimumStops": -1000, "maximumStops": 1000, "subdivisions": 4],
            ["minimumStops": -2, "maximumStops": 2, "subdivisions": 3, "extra": 1]] {
            var raw = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
            var object = raw["exposureBatchPreset"] as! [String: Any]
            object["sequence"] = sequence; raw["exposureBatchPreset"] = object
            XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: raw), catalog: catalog))
        }
        var raw = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
        var versions = raw["algorithmVersions"] as! [String: String]
        versions["exposureBatchPreset"] = "unknown"; raw["algorithmVersions"] = versions
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: raw), catalog: catalog)) {
            XCTAssertEqual($0 as? ProjectError, .algorithmMismatch)
        }
        for name in ["", ".", "..", "a/b", "a\\b", "a\0b", String(repeating: "名", count: 100)] {
            XCTAssertThrowsError(try ExposureBatchPreset(sequence: ExposureBatchSequence(), basename: name, format: .cube))
        }
        let invalid = ProjectManifest(settings: settings(), cubeSize: 33, domain: .unit,
            exposureBatchPreset: try ExposureBatchPreset(sequence: ExposureBatchSequence(minimumStops: 2000, maximumStops: 2000, subdivisions: 1), basename: "overflow", format: .cube))
        XCTAssertThrowsError(try ProjectCodec.encode(invalid, catalog: catalog))
    }
    func testDiskSaveUndoRedoAndExplicitPresetRemovalKeepIdentity() throws {
        let catalog = try AlgorithmCatalog.builtIn(), base = ProjectManifest(settings: settings(), cubeSize: 33, domain: .unit)
        let preset = try ExposureBatchPreset(sequence: ExposureBatchSequence(), basename: "保存", format: .spi1d, blockNodes: 17, workerCount: 4)
        let changed = base.withExposureBatchPreset(preset)
        var session = try ProjectEditingSession(new: base, catalog: catalog)
        try session.apply(changed); XCTAssertTrue(session.undo()); XCTAssertNil(session.current.exposureBatchPreset)
        XCTAssertTrue(session.redo()); XCTAssertEqual(session.current, changed)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("batch.lutcalc")
        try session.save(to: url)
        var reopened = try ProjectEditingSession(opening: url, catalog: catalog)
        XCTAssertEqual(reopened.current, changed)
        try reopened.apply(changed.withExposureBatchPreset(nil)); try reopened.save()
        let clean = try ProjectStore.open(at: url, catalog: catalog)
        XCTAssertNil(clean.exposureBatchPreset); XCTAssertNil(clean.algorithmVersions["exposureBatchPreset"])
    }
}

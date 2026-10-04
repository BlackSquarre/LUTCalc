import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTCatalog

final class ARRILogCSceneProjectContractsTests: XCTestCase {
    func testSchema17ExplicitEIIdentityStrictPayloadAndHistoricalRejection() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let a = try ARRILogCSceneSettings(algorithm: .sup2Published, exposureIndex: 800)
        let b = try ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: 1600)
        let s = TransformSettings(inputTransfer: .arriLogCSUP2Scene, outputTransfer: .arriLogCSUP3Scene,
            inputSpace: .rec2020, outputSpace: .rec2020, inputRange: .data, outputRange: .data,
            exposureStops: 0, inputLogC: a, outputLogC: b)
        let document = ProjectManifest(settings: s, cubeSize: 33, domain: .unit)
        XCTAssertEqual(document.schemaVersion, ProjectManifest.currentSchema)
        XCTAssertEqual(document.algorithmVersions["inputLogC"], a.algorithm.rawValue)
        XCTAssertEqual(document.algorithmVersions["outputLogC"], b.algorithm.rawValue)
        let bytes = try ProjectCodec.encode(document, catalog: catalog)
        XCTAssertEqual(try ProjectCodec.decode(bytes, catalog: catalog), document)
        func mutated(_ mutate: (inout [String: Any]) -> Void) throws -> Data {
            var raw = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
            mutate(&raw); return try JSONSerialization.data(withJSONObject: raw)
        }
        for schema in 1...16 {
            let old = try mutated { $0["schemaVersion"] = schema }
            XCTAssertThrowsError(try ProjectCodec.decode(old, catalog: catalog))
            XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self, from: old))
        }
        for (key, value) in [("extra", "x" as Any), ("algorithm", "unknown" as Any), ("exposureIndex", 2000 as Any)] {
            let invalid = try mutated { raw in
                var settings = raw["settings"] as! [String: Any], payload = settings["inputLogC"] as! [String: Any]
                payload[key] = value; settings["inputLogC"] = payload; raw["settings"] = settings
            }
            XCTAssertThrowsError(try ProjectCodec.decode(invalid, catalog: catalog))
        }
        for key in ["algorithm", "exposureIndex"] {
            let invalid = try mutated { raw in
                var settings = raw["settings"] as! [String: Any], payload = settings["inputLogC"] as! [String: Any]
                payload.removeValue(forKey: key); settings["inputLogC"] = payload; raw["settings"] = settings
            }
            XCTAssertThrowsError(try ProjectCodec.decode(invalid, catalog: catalog))
        }
        let mismatch = try mutated { raw in
            var versions = raw["algorithmVersions"] as! [String: String]; versions["inputLogC"] = b.algorithm.rawValue; raw["algorithmVersions"] = versions
        }
        XCTAssertThrowsError(try ProjectCodec.decode(mismatch, catalog: catalog)) {
            XCTAssertEqual($0 as? ProjectError, .algorithmMismatch)
        }
    }
    func testActualSchema16DiskReadPreservesBytesAndUndoRedoEI() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let base = TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020, inputRange: .data, outputRange: .data, exposureStops: 0)
        let original = ProjectManifest(settings: base, cubeSize: 33, domain: .unit)
        var raw = try JSONSerialization.jsonObject(with: ProjectCodec.encode(original, catalog: catalog)) as! [String: Any]
        raw["schemaVersion"] = 16
        let before = try JSONSerialization.data(withJSONObject: raw, options: .sortedKeys)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("manifest.json"); try before.write(to: path)
        var editing = try ProjectEditingSession(opening: folder, catalog: catalog)
        XCTAssertEqual(editing.current.schemaVersion, ProjectManifest.currentSchema); XCTAssertNil(editing.current.settings.inputLogC)
        XCTAssertEqual(try Data(contentsOf: path), before)
        let configured = base.withOutput(transfer: .arriLogCSUP3Scene, space: .rec2020).withOutputLogC(
            try ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: 1600))
        try editing.apply(ProjectManifest(id: original.id, settings: configured, cubeSize: 33, domain: .unit))
        XCTAssertTrue(editing.undo()); XCTAssertNil(editing.current.settings.outputLogC)
        XCTAssertTrue(editing.redo()); XCTAssertEqual(editing.current.settings.outputLogC?.exposureIndex, 1600)
        XCTAssertEqual(try Data(contentsOf: path), before)
        if let target = ProcessInfo.processInfo.environment["LUTCALC_LOGC_ROUTING_ARTIFACT_DIR"] {
            let retained = URL(fileURLWithPath: target).appendingPathComponent("logc-schema16-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: retained, withIntermediateDirectories: true)
            try before.write(to: retained.appendingPathComponent("manifest-before.json"))
            try Data(contentsOf: path).write(to: retained.appendingPathComponent("manifest-after.json"))
            try FileManager.default.copyItem(at: folder, to: retained.appendingPathComponent("schema16.lutcalc"))
        }
    }
}

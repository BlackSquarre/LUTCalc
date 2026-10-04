import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTCatalog

final class ARRIAWG3ProjectContractsTests: XCTestCase {
    func testSchema18AWG3PresetsAndAdjustmentReferencesRejectHistoricalSchemas() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let base = TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020, inputRange: .data, outputRange: .data, exposureStops: 0)
        let settings = [base.withInput(transfer: .linearScene, space: .arriWideGamut3),
            base.withOutput(transfer: .linearScene, space: .arriWideGamut3),
            base.withHighlightGamut(try HighlightGamutSettings(highlightSpace: .arriWideGamut3)),
            base.withGamutLimiter(try GamutLimiterSettings(secondarySpace: .arriWideGamut3))]
        for s in settings {
            XCTAssertTrue(s.referencesARRIWideGamut3)
            let document = ProjectManifest(settings: s, cubeSize: 33, domain: .unit)
            XCTAssertEqual(document.schemaVersion, ProjectManifest.currentSchema)
            let bytes = try ProjectCodec.encode(document, catalog: catalog)
            XCTAssertEqual(try ProjectCodec.decode(bytes, catalog: catalog), document)
            for schema in 1...17 {
                var raw = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]; raw["schemaVersion"] = schema
                let invalid = try JSONSerialization.data(withJSONObject: raw)
                XCTAssertThrowsError(try ProjectCodec.decode(invalid, catalog: catalog))
                XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self, from: invalid))
            }
        }
        for ei in ARRILogCCompact.supportedExposureIndices {
            let preset = try XCTUnwrap(catalog.preset(named: "arri.logc-sup3-ei\(ei)-awg3-to-linear-ap0-published.v1"))
            let manifest = ProjectManifest(settings: preset.settings, cubeSize: 33, domain: .unit)
            XCTAssertEqual(manifest.algorithmVersions["inputSpace"], "arri.awg3.v1")
            XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(manifest, catalog: catalog), catalog: catalog), manifest)
        }
    }
    func testActualSchema17LogCProjectReadPreservesOriginalBytesAndEI() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let payload = try ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: 1600)
        let s = TransformSettings(inputTransfer: .arriLogCSUP3Scene, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020, inputRange: .data, outputRange: .data, exposureStops: 0, inputLogC: payload)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let before = try Data(contentsOf: root.appendingPathComponent("tests/fixtures/native-contracts/arri-awg3-schema17-original.json"))
        let raw = try JSONSerialization.jsonObject(with: before) as! [String: Any]
        XCTAssertEqual(raw["schemaVersion"] as? Int, 17)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("manifest.json"); try before.write(to: url)
        let opened = try ProjectEditingSession(opening: folder, catalog: catalog)
        XCTAssertEqual(opened.current.schemaVersion, ProjectManifest.currentSchema); XCTAssertEqual(opened.current.settings, s)
        let after = try Data(contentsOf: url); XCTAssertEqual(after, before)
        if let target = ProcessInfo.processInfo.environment["LUTCALC_AWG3_ARTIFACT_DIR"] {
            let retained = URL(fileURLWithPath: target).appendingPathComponent("schema17-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: retained, withIntermediateDirectories: true)
            try before.write(to: retained.appendingPathComponent("manifest-before.json")); try after.write(to: retained.appendingPathComponent("manifest-after.json"))
            try FileManager.default.copyItem(at: folder, to: retained.appendingPathComponent("schema17.lutcalc"))
        }
    }
}

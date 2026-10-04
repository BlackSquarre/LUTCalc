import XCTest
import LUTCore
import LUTCatalog
import LUTProject

final class ProjectContractsTests: XCTestCase {
    func testExternalLegacyAppSettingsAreRejected() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let legacyPayloads = [
            #"{"version":"v4.10","lutBox":{"legalIn":true,"legalOut":false},"gammaBox":{"recGamma":"D-Log2"}}"#,
            #"{"version":"v4.09","lutBox":{},"gammaBox":{},"tweaksBox":{},"generateBox":{},"formats":{},"cameraBox":{}}"#,
            #"{"version":"v4.10","lutBox":{"legalIn":true},"gammaBox":{"recGamma":"sRGB"}}"#,
        ]
        for payload in legacyPayloads {
            XCTAssertThrowsError(try ProjectCodec.decode(Data(payload.utf8), catalog: catalog),
                                 "旧 App 单文件设置不得作为原生项目导入")
        }
    }

    func testAssetRolesAndLegacyV1MigrationPreserveUnrelatedResource() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let settings = TransformSettings(inputTransfer: .djiDLog2, outputTransfer: .linearScene,
                                         inputSpace: .djiDGamut2, outputSpace: .acesAP0,
                                         inputRange: .data, outputRange: .data, exposureStops: 0)
        let userPath = "Resources/user-00000000-0000-0000-0000-000000000001.cube"
        let otherPath = "Resources/reference.cube"
        let hashes = [userPath: String(repeating: "a", count: 64),
                      otherPath: String(repeating: "b", count: 64)]
        let current = ProjectManifest(settings: settings, cubeSize: 17, domain: .unit,
                                      assetHashes: hashes,
                                      assetRoles: [userPath: .userLUT, otherPath: .other])
        let encoded = try ProjectCodec.encode(current, catalog: catalog)
        XCTAssertEqual(try ProjectCodec.decode(encoded, catalog: catalog), current)
        var raw = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        raw["schemaVersion"] = 1
        raw.removeValue(forKey: "assetRoles")
        let v1 = try JSONSerialization.data(withJSONObject: raw)
        let migrated = try ProjectCodec.decode(v1, catalog: catalog)
        XCTAssertEqual(migrated.schemaVersion, ProjectManifest.currentSchema)
        XCTAssertEqual(migrated.assetHashes, hashes)
        XCTAssertEqual(migrated.assetRoles[userPath], .legacyUserLUT)
        XCTAssertEqual(migrated.assetRoles[otherPath], .other)
        XCTAssertEqual(try ProjectCodec.decode(try ProjectCodec.encode(migrated, catalog: catalog),
                                               catalog: catalog), migrated)

        raw["schemaVersion"] = ProjectManifest.currentSchema
        XCTAssertThrowsError(try ProjectCodec.decode(try JSONSerialization.data(withJSONObject: raw),
                                                    catalog: catalog))
    }

    func testV2AssetRoleValidationRejectsAmbiguousOrIncompleteRoles() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let settings = TransformSettings(inputTransfer: .djiDLog2, outputTransfer: .linearScene,
                                         inputSpace: .djiDGamut2, outputSpace: .acesAP0,
                                         inputRange: .data, outputRange: .data, exposureStops: 0)
        let first = "Resources/first.cube"
        let second = "Resources/second.cube"
        let hashes = [first: String(repeating: "a", count: 64),
                      second: String(repeating: "b", count: 64)]
        let valid = ProjectManifest(settings: settings, cubeSize: 17, domain: .unit,
                                    assetHashes: hashes,
                                    assetRoles: [first: .userLUT, second: .other])
        var raw = try JSONSerialization.jsonObject(with: ProjectCodec.encode(valid, catalog: catalog))
            as! [String: Any]
        for roles in [
            [first: "userLUT"],
            [first: "userLUT", second: "userLUT"],
            [first: "userLUT", second: "unknown"],
            [first: "userLUT", second: "other", "Resources/extra.cube": "other"],
        ] {
            raw["assetRoles"] = roles
            XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: raw),
                                                        catalog: catalog))
        }
    }

    func testSettingsDoubleAndUnknownVersion() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let settings = TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .acesAP0,
            inputRange: .video, outputRange: .data,
            exposureStops: 0.18000000000000002, rangeBitDepth: 12
        )
        let document = ProjectManifest(settings: settings, cubeSize: 33, domain: .unit)
        let data = try ProjectCodec.encode(document, catalog: catalog)
        let readback = try ProjectCodec.decode(data, catalog: catalog)
        XCTAssertEqual(readback.settings.exposureStops.bitPattern, settings.exposureStops.bitPattern)
        XCTAssertEqual(readback.settings.rangeBitDepth, 12)
        XCTAssertEqual(readback.id, document.id)

        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json["schemaVersion"] = 99
        let future = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try ProjectCodec.decode(future, catalog: catalog)) {
            XCTAssertEqual($0 as? ProjectError, .unsupportedSchema(99))
        }
    }

    func testParameterizedGammaProjectManifestRoundTrip() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let gamma = try ParameterizedGammaSettings(
            exponent: 2.4,
            linearSlope: 4.5,
            offset: 0.1,
            linearCut: 0.02,
            encodedCut: 0.09
        )
        let settings = TransformSettings(
            inputTransfer: .linearScene,
            outputTransfer: .parameterizedGamma,
            inputSpace: .srgb,
            outputSpace: .srgb,
            inputRange: .data,
            outputRange: .data,
            exposureStops: 0,
            outputGamma: gamma
        )
        let document = ProjectManifest(settings: settings, cubeSize: 17, domain: .unit)
        let data = try ProjectCodec.encode(document, catalog: catalog)
        let decoded = try ProjectCodec.decode(data, catalog: catalog)
        XCTAssertEqual(decoded, document)
        XCTAssertEqual(decoded.settings.outputGamma, gamma)

        var raw = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var savedSettings = raw["settings"] as! [String: Any]
        savedSettings.removeValue(forKey: "outputGamma")
        raw["settings"] = savedSettings
        XCTAssertThrowsError(try ProjectCodec.decode(
            JSONSerialization.data(withJSONObject: raw), catalog: catalog
        )) { error in
            XCTAssertEqual(error as? ProjectError, .invalidSettings)
        }

        let validData = try ProjectCodec.encode(document, catalog: catalog)
        var withUnknownGammaField = try JSONSerialization.jsonObject(with: validData) as! [String: Any]
        var gammaSettings = (withUnknownGammaField["settings"] as! [String: Any])["outputGamma"] as! [String: Any]
        gammaSettings["unknown"] = 1
        var settingsWithUnknownGammaField = withUnknownGammaField["settings"] as! [String: Any]
        settingsWithUnknownGammaField["outputGamma"] = gammaSettings
        withUnknownGammaField["settings"] = settingsWithUnknownGammaField
        XCTAssertThrowsError(try ProjectCodec.decode(
            JSONSerialization.data(withJSONObject: withUnknownGammaField), catalog: catalog
        )) { error in
            XCTAssertEqual(error as? ProjectError, .unknownField("settings.outputGamma.unknown"))
        }
    }

    func testEditingSessionPreservesSignedZeroThroughUndoAndRedo() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        func settings(_ exposure: Double) -> TransformSettings {
            TransformSettings(inputTransfer: .djiDLog2, outputTransfer: .linearScene,
                              inputSpace: .djiDGamut2, outputSpace: .acesAP0,
                              inputRange: .data, outputRange: .data, exposureStops: exposure)
        }
        let original = ProjectManifest(settings: settings(0.0), cubeSize: 17, domain: .unit)
        var editor = try ProjectEditingSession(new: original, catalog: catalog)
        try editor.apply(ProjectManifest(id: original.id, settings: settings(-0.0),
                                         cubeSize: 17, domain: .unit))
        XCTAssertEqual(editor.current.settings.exposureStops.bitPattern, (-0.0).bitPattern)
        XCTAssertTrue(editor.undo())
        XCTAssertEqual(editor.current.settings.exposureStops.bitPattern, 0.0.bitPattern)
        XCTAssertTrue(editor.redo())
        XCTAssertEqual(editor.current.settings.exposureStops.bitPattern, (-0.0).bitPattern)
    }

    func testBradfordSettingsRoundtripAndUnknownAdaptationRejected() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let settings = TransformSettings(
            inputTransfer: .appleLog2, outputTransfer: .linearScene,
            inputSpace: .appleWideGamut, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data,
            exposureStops: 1, adaptation: .bradford)
        let document = ProjectManifest(settings: settings, cubeSize: 33, domain: .unit)
        let bytes = try ProjectCodec.encode(document, catalog: catalog)
        XCTAssertEqual(try ProjectCodec.decode(bytes, catalog: catalog), document)

        var root = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
        var savedSettings = root["settings"] as! [String: Any]
        XCTAssertEqual(savedSettings["adaptation"] as? String, "bradford")
        savedSettings["adaptation"] = "unknown-adaptation"
        root["settings"] = savedSettings
        let unknown = try JSONSerialization.data(withJSONObject: root)
        XCTAssertThrowsError(try ProjectCodec.decode(unknown, catalog: catalog))
    }

    func testManifestRejectsDuplicateKeysAfterUnicodeDecoding() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let settings = TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 0)
        let manifest = ProjectManifest(settings: settings, cubeSize: 17, domain: .unit)
        let original = String(decoding: try ProjectCodec.encode(manifest, catalog: catalog), as: UTF8.self)
        let cases: [(String, String)] = [
            (original.replacingOccurrences(of: "\"schemaVersion\":\(ProjectManifest.currentSchema)",
                with: "\"schemaVersion\":\(ProjectManifest.currentSchema),\"schemaVersion\":\(ProjectManifest.currentSchema)"),
             "schemaVersion"),
            (original.replacingOccurrences(of: "\"cubeSize\":17", with: "\"cubeSize\":17,\"cube\\u0053ize\":33"),
             "cubeSize"),
            (original.replacingOccurrences(of: "\"exposureStops\":0", with: "\"exposureStops\":0,\"exposureStops\":1"),
             "settings.exposureStops"),
        ]
        for (json, path) in cases {
            XCTAssertThrowsError(try ProjectCodec.decode(Data(json.utf8), catalog: catalog), path) {
                XCTAssertEqual($0 as? ProjectError, .duplicateKey(path))
            }
        }
    }
}

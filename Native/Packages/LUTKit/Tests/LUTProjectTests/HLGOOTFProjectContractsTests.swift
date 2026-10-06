import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTCatalog

final class HLGOOTFProjectContractsTests: XCTestCase {
    func testSchema22RoundTripVersionAndStrictGate() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let ootf = HLGOOTFSettings(inputPeakNits: 800, outputPeakNits: 1000,
                                   inputBlackNits: 2, outputBlackNits: 0,
                                   scale: .normalizedBy1000, bbcInput: true)
        let settings = TransformSettings(inputTransfer: .linearScene,
                                         outputTransfer: .rec2100HLG,
                                         inputSpace: .rec2020, outputSpace: .rec2020,
                                         inputRange: .data, outputRange: .data,
                                         exposureStops: 0, hlgOOTF: ootf)
        let manifest = ProjectManifest(settings: settings, cubeSize: 33, domain: .unit)
        XCTAssertGreaterThanOrEqual(manifest.schemaVersion, 22)
        XCTAssertEqual(manifest.algorithmVersions["hlgOOTF"], ootf.algorithm.rawValue)
        let bytes = try ProjectCodec.encode(manifest, catalog: catalog)
        XCTAssertEqual(try ProjectCodec.decode(bytes, catalog: catalog), manifest)
        for schema in 1...21 {
            var raw = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
            raw["schemaVersion"] = schema
            XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: raw), catalog: catalog))
            XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self, from: JSONSerialization.data(withJSONObject: raw)))
        }
        var malformed = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
        var payload = (malformed["settings"] as! [String: Any])["hlgOOTF"] as! [String: Any]
        payload["unknown"] = true
        var rawSettings = malformed["settings"] as! [String: Any]
        rawSettings["hlgOOTF"] = payload
        malformed["settings"] = rawSettings
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: malformed), catalog: catalog))

        let plain = ProjectManifest(id: manifest.id,
                                    settings: settings.withHLGOOTF(nil),
                                    cubeSize: manifest.cubeSize, domain: manifest.domain)
        var old = try JSONSerialization.jsonObject(with: ProjectCodec.encode(plain, catalog: catalog)) as! [String: Any]
        old["schemaVersion"] = 21
        XCTAssertEqual(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: old), catalog: catalog), plain)
    }

    func testReferenceAlgorithmRoundTripsThroughSchema22AndKeepsStrictParameters() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let ootf = HLGOOTFSettings(inputPeakNits: 1000,
                                   outputPeakNits: 1000,
                                   inputBlackNits: 0,
                                   outputBlackNits: 0,
                                   scale: .nits,
                                   bbcInput: false,
                                   bbcOutput: false,
                                   algorithm: .bt2100HLGReferenceV1)
        let settings = TransformSettings(inputTransfer: .linearScene,
                                         outputTransfer: .rec2100HLG,
                                         inputSpace: .rec2020, outputSpace: .rec2020,
                                         inputRange: .data, outputRange: .data,
                                         exposureStops: 0, hlgOOTF: ootf)
        let manifest = ProjectManifest(settings: settings, cubeSize: 33, domain: .unit)
        XCTAssertEqual(manifest.algorithmVersions["hlgOOTF"], ootf.algorithm.rawValue)
        let bytes = try ProjectCodec.encode(manifest, catalog: catalog)
        let decoded = try ProjectCodec.decode(bytes, catalog: catalog)
        XCTAssertEqual(decoded, manifest)
        XCTAssertEqual(decoded.settings.hlgOOTF?.algorithm, .bt2100HLGReferenceV1)
        XCTAssertEqual(decoded.settings.hlgOOTF?.scale, .nits)

        var malformed = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
        var settingsPayload = malformed["settings"] as! [String: Any]
        var hlgPayload = settingsPayload["hlgOOTF"] as! [String: Any]
        hlgPayload["scale"] = HLGOOTF.Scale.normalizedBy1000.rawValue
        settingsPayload["hlgOOTF"] = hlgPayload
        malformed["settings"] = settingsPayload
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: malformed), catalog: catalog))
    }

    func testReferenceExtendedGammaRoundTripsAndOldSchemaRejectsIt() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let ootf = HLGOOTFSettings(
            inputPeakNits: 10000,
            outputPeakNits: 10000,
            inputBlackNits: 0,
            outputBlackNits: 0,
            scale: .nits,
            referenceGammaMode: .extended,
            algorithm: .bt2100HLGReferenceV1)
        let settings = TransformSettings(
            inputTransfer: .linearScene,
            outputTransfer: .rec2100HLG,
            inputSpace: .rec2020,
            outputSpace: .rec2020,
            inputRange: .data,
            outputRange: .data,
            exposureStops: 0,
            hlgOOTF: ootf)
        let manifest = ProjectManifest(settings: settings, cubeSize: 33, domain: .unit)
        XCTAssertEqual(manifest.schemaVersion, 27)
        let bytes = try ProjectCodec.encode(manifest, catalog: catalog)
        let raw = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
        let hlg = ((raw["settings"] as! [String: Any])["hlgOOTF"] as! [String: Any])
        XCTAssertEqual(hlg["referenceGammaMode"] as? String, "extended")
        let decoded = try ProjectCodec.decode(bytes, catalog: catalog)
        XCTAssertEqual(decoded.settings.hlgOOTF?.referenceGammaMode, .extended)

        var old = raw
        old["schemaVersion"] = 26
        XCTAssertThrowsError(try ProjectCodec.decode(
            JSONSerialization.data(withJSONObject: old), catalog: catalog))

        XCTAssertThrowsError(try HLGOOTFSettings(
            referenceGammaMode: .extended,
            algorithm: .lutcalcHLGOOTFV1).makeKernel())
    }
}

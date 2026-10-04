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
}

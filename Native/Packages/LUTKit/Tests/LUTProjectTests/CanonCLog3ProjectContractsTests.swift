import Foundation
import XCTest
import LUTCore
import LUTCatalog
import LUTProject

final class CanonCLog3ProjectContractsTests: XCTestCase {
    func testSchema21AcceptsCLog3AndSchema20RejectsIt() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let settings = TransformSettings(inputTransfer: .canonCLog3, outputTransfer: .linearScene,
                                         inputSpace: .canonCinemaGamut, outputSpace: .acesAP0,
                                         inputRange: .data, outputRange: .data, exposureStops: 0)
        let project = ProjectManifest(settings: settings, cubeSize: 33, domain: .unit)
        let bytes = try ProjectCodec.encode(project, catalog: catalog)
        XCTAssertEqual(try ProjectCodec.decode(bytes, catalog: catalog), project)
        var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        raw["schemaVersion"] = 20
        let historical = try JSONSerialization.data(withJSONObject: raw)
        XCTAssertThrowsError(try ProjectCodec.decode(historical, catalog: catalog))
        XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self, from: historical))
    }
}

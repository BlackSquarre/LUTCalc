import Foundation
import XCTest
import LUTCore
import LUTCatalog
import LUTProject

final class CanonCLog2ProjectContractsTests: XCTestCase {
    func testSchema21RoundtripAndHistoricalRejection() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let base = TransformSettings(inputTransfer: .canonCLog2, outputTransfer: .linearScene,
                                     inputSpace: .canonCinemaGamut, outputSpace: .acesAP0,
                                     inputRange: .data, outputRange: .data, exposureStops: 0)
        let settings = [
            base,
            base.withInput(transfer: .linearScene, space: .rec2020)
                .withOutput(transfer: .canonCLog2LUTCalcLegacy, space: .canonCinemaGamut),
            base.withInput(transfer: .linearScene, space: .rec2020)
                .withHighlightGamut(try HighlightGamutSettings(enabled: false, highlightSpace: .canonCinemaGamut)),
            base.withInput(transfer: .linearScene, space: .rec2020)
                .withGamutLimiter(try GamutLimiterSettings(enabled: false, secondarySpace: .canonCinemaGamut)),
        ]
        for setting in settings {
            let project = ProjectManifest(settings: setting, cubeSize: 33, domain: .unit)
            XCTAssertEqual(project.schemaVersion, ProjectManifest.currentSchema)
            let bytes = try ProjectCodec.encode(project, catalog: catalog)
            XCTAssertEqual(try ProjectCodec.decode(bytes, catalog: catalog), project)
            for schema in 1...20 {
                var raw = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
                raw["schemaVersion"] = schema
                let old = try JSONSerialization.data(withJSONObject: raw)
                XCTAssertThrowsError(try ProjectCodec.decode(old, catalog: catalog))
                XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self, from: old))
            }
        }
    }
}

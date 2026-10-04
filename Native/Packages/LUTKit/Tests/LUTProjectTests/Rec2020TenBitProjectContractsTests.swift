import XCTest
@testable import LUTProject
@testable import LUTCatalog
@testable import LUTCore

final class Rec2020TenBitProjectContractsTests: XCTestCase {
    func testCurrentSchemaRoundTripsTenBitTransfer() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let settings = TransformSettings(
            inputTransfer: .rec2020TenBit, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )
        let manifest = ProjectManifest(settings: settings, cubeSize: 33, domain: .unit)
        let data = try ProjectCodec.encode(manifest, catalog: catalog)
        let decoded = try ProjectCodec.decode(data, catalog: catalog)
        XCTAssertEqual(decoded.settings.inputTransfer, .rec2020TenBit)
        XCTAssertEqual(decoded.schemaVersion, ProjectManifest.currentSchema)

    }
}

import XCTest
@testable import LUTCatalog
@testable import LUTCore

final class Rec2020TenBitCatalogContractsTests: XCTestCase {
    func testCatalogRegistersPublishedTenBitTransferAndPreset() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let transfer = try XCTUnwrap(catalog.transfer(named: "rec2020.bt2020-10bit.v1"))
        XCTAssertEqual(transfer.id, .rec2020TenBit)
        XCTAssertEqual(transfer.aliases, ["Rec.2020 10-bit"])
        XCTAssertTrue(transfer.source.contains("BT.2020-2"))
        XCTAssertEqual(transfer.linearReference, .sceneReflectance)
        let preset = try XCTUnwrap(catalog.preset(named: "rec2020.10bit-exposure-one.v1"))
        XCTAssertEqual(preset.settings.inputTransfer, .rec2020TenBit)
        XCTAssertEqual(preset.settings.outputTransfer, .rec2020TenBit)
    }
}

import XCTest
import LUTCatalog
import LUTCore

final class ProPhotoBBCRegistryContractsTests: XCTestCase {
    func testCatalogRegistersProPhotoAndBBCBatch() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "ProPhoto / ROMM")?.id, .proPhoto)
        XCTAssertEqual(catalog.colorSpace(named: "ProPhoto RGB")?.id, .proPhoto)
        for (name, id) in [("BBC 0.4", TransferID.bbc04), ("BBC 0.5", .bbc05), ("BBC 0.6", .bbc06)] {
            XCTAssertEqual(catalog.transfer(named: name)?.id, id)
        }
        XCTAssertEqual(catalog.transfer(named: "BBC WHP283 (400%)")?.id, .bbcWHP283400)
        XCTAssertEqual(catalog.transfer(named: "BBC WHP283 (800%)")?.id, .bbcWHP283800)
        XCTAssertNotNil(catalog.preset(named: "bbc.whp283-400-exposure-one.v1"))
        XCTAssertNotNil(catalog.preset(named: "bbc.whp283-800-exposure-one.v1"))
    }
}

import XCTest
@testable import LUTCore
@testable import LUTCatalog

final class BT601ColorSpaceContractsTests: XCTestCase {
    func testPublishedBT601PrimariesAndCatalogIdentities() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.colorSpace(named: "BT.601 525 (SMPTE-C)")?.id, .bt601SMPTEC)
        XCTAssertEqual(catalog.colorSpace(named: "BT.601 625 (EBU)")?.id, .bt601EBU)
        XCTAssertEqual(ColorPrimaries.bt601SMPTEC.red, try Chromaticity(x: 0.630, y: 0.340))
        XCTAssertEqual(ColorPrimaries.bt601SMPTEC.green, try Chromaticity(x: 0.310, y: 0.595))
        XCTAssertEqual(ColorPrimaries.bt601SMPTEC.blue, try Chromaticity(x: 0.155, y: 0.070))
        XCTAssertEqual(ColorPrimaries.bt601EBU.red, try Chromaticity(x: 0.640, y: 0.330))
        XCTAssertEqual(ColorPrimaries.bt601EBU.green, try Chromaticity(x: 0.290, y: 0.600))
        XCTAssertEqual(ColorPrimaries.bt601EBU.blue, try Chromaticity(x: 0.150, y: 0.060))
    }

    func testPublishedBT601DoubleMatrices() throws {
        let smpte = try ColorPrimaries.bt601SMPTEC.rgbToXYZ()
        let ebu = try ColorPrimaries.bt601EBU.rgbToXYZ()
        XCTAssertEqual(smpte[0, 0], 0.3935209, accuracy: 2e-6)
        XCTAssertEqual(smpte[1, 1], 0.7010598569257228, accuracy: 2e-15)
        XCTAssertEqual(ebu[0, 0], 0.43055381332990217, accuracy: 2e-15)
        XCTAssertEqual(ebu[1, 1], 0.706654765925283, accuracy: 2e-15)
        XCTAssertNotEqual(smpte.rowMajor, ebu.rowMajor)
    }
}

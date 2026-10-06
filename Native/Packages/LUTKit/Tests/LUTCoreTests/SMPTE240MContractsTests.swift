import XCTest
@testable import LUTCore
@testable import LUTCatalog

final class SMPTE240MContractsTests: XCTestCase {
    func testPublishedPiecewiseOETFAndInverse() throws {
        let cutoff = 1.1115 * pow(0.0228, 0.45) - 0.1115
        XCTAssertEqual(try SMPTE240MTransfer.encodeSceneToData(0.0228), cutoff, accuracy: 1e-15)
        XCTAssertEqual(try SMPTE240MTransfer.encodeSceneToData(0.18),
                       1.1115 * pow(0.18, 0.45) - 0.1115, accuracy: 1e-15)
        XCTAssertEqual(try SMPTE240MTransfer.decodeDataToScene(cutoff), 0.0228, accuracy: 1e-15)
        for value in [0.0, 0.01, 0.0228, 0.18, 1.0] {
            let encoded = try SMPTE240MTransfer.encodeSceneToData(value)
            XCTAssertEqual(try SMPTE240MTransfer.decodeDataToScene(encoded), value, accuracy: 3e-15)
        }
    }

    func testCatalogAndIndependentPrimaries() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "SMPTE 240M")?.id, .smpte240M)
        XCTAssertEqual(catalog.colorSpace(named: "SMPTE 240M")?.id, .smpte240M)
        XCTAssertEqual(ColorPrimaries.smpte240M.red, try Chromaticity(x: 0.67, y: 0.33))
        XCTAssertNotEqual(ColorPrimaries.smpte240M, ColorPrimaries.bt601SMPTEC)
        let matrix = try ColorPrimaries.smpte240M.rgbToXYZ()
        XCTAssertEqual(matrix[1, 1], 0.6056399117734084, accuracy: 1e-15)
    }
}

import XCTest
@testable import LUTCore

final class CIELStarContractsTests: XCTestCase {
    func testPublishedBranchesAndExactCuts() throws {
        XCTAssertEqual(CIELStarTransfer.linearCut, 216.0 / 24389.0, accuracy: 0)
        XCTAssertEqual(CIELStarTransfer.encodedCut, 216.0 / 2700.0, accuracy: 0)
        let low = CIELStarTransfer.linearCut.nextDown
        let high = CIELStarTransfer.linearCut
        XCTAssertEqual(try CIELStarTransfer.encodeLegacyToLegal(low),
                       (24389.0 / 2700.0) * low, accuracy: 1e-15)
        XCTAssertEqual(try CIELStarTransfer.encodeLegacyToLegal(high),
                       1.16 * pow(high, 1.0 / 3.0) - 0.16, accuracy: 1e-15)
    }

    func testDataWrapperAndInverseRoundTripBatch() throws {
        for value in [0.0, CIELStarTransfer.linearCut.nextDown, CIELStarTransfer.linearCut,
                      0.18, 0.5, 1.0, 1.25] {
            let data = try CIELStarTransfer.encodeLegacyToData(value)
            XCTAssertEqual(try CIELStarTransfer.decodeDataToLegacy(data), value, accuracy: 2e-14)
        }
        XCTAssertThrowsError(try CIELStarTransfer.encodeLegacyToData(.nan))
        XCTAssertThrowsError(try CIELStarTransfer.decodeDataToLegacy(.infinity))
    }
}

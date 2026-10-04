import XCTest
@testable import LUTCore

final class CIELABContractsTests: XCTestCase {
    func testPublishedWhitePointsAndExactBranch() throws {
        XCTAssertEqual(CIELABWhitePoint.d65.xyz.x, 0.950489, accuracy: 0)
        XCTAssertEqual(CIELABWhitePoint.d65.xyz.y, 1.0, accuracy: 0)
        XCTAssertEqual(CIELABWhitePoint.d65.xyz.z, 1.088840, accuracy: 0)

        let cut = CIELABColorSpace.linearCut
        let below = try CIELABColorSpace.fromXYZ(
            XYZ64(cut.nextDown, cut.nextDown, cut.nextDown),
            white: .d65
        )
        let at = try CIELABColorSpace.fromXYZ(
            XYZ64(cut, cut, cut),
            white: .d65
        )
        XCTAssertEqual(below.lStar, (24389.0 / 2700.0) * cut.nextDown, accuracy: 2e-14)
        XCTAssertEqual(at.lStar, 1.16 * pow(cut, 1.0 / 3.0) - 0.16, accuracy: 2e-14)
    }

    func testXYZLabRoundTripPreservesExtendedDomain() throws {
        for xyz in [
            try XYZ64(0, 0, 0),
            try XYZ64(0.18, 0.2, 0.25),
            try XYZ64(-0.1, 1.2, 1.4),
            try XYZ64(2.0, 0.5, -0.25)
        ] {
            let lab = try CIELABColorSpace.fromXYZ(xyz, white: .d50)
            let restored = try lab.toXYZ(white: .d50)
            XCTAssertEqual(restored.x, xyz.x, accuracy: 3e-14)
            XCTAssertEqual(restored.y, xyz.y, accuracy: 3e-14)
            XCTAssertEqual(restored.z, xyz.z, accuracy: 3e-14)
        }
    }

    func testWhitePointNeutralAndInvalidValues() throws {
        let neutral = try CIELABColorSpace.fromXYZ(CIELABWhitePoint.d50.xyz, white: .d50)
        XCTAssertEqual(neutral.lStar, 1.0, accuracy: 2e-14)
        XCTAssertEqual(neutral.aStar, 0.0, accuracy: 2e-14)
        XCTAssertEqual(neutral.bStar, 0.0, accuracy: 2e-14)
        XCTAssertThrowsError(try XYZ64(.nan, 0, 0))
        XCTAssertThrowsError(try CIELABColor(lStar: .nan, aStar: 0, bStar: 0))
    }
}

import XCTest
@testable import LUTCore

final class CIELABContractsTests: XCTestCase {
    func testCIE1976DeltaEUsesEuclideanLabDistance() throws {
        let first = try CIELABColor(lStar: 0.42, aStar: 12.0, bStar: -8.0)
        let second = try CIELABColor(lStar: 0.57, aStar: 3.0, bStar: 4.0)

        let expected = (15.0 * 15.0 + 9.0 * 9.0 + 12.0 * 12.0).squareRoot()
        let actual = first.deltaE76(to: second)
        XCTAssertEqual(actual, expected, accuracy: 1e-14)
        XCTAssertEqual(first.deltaE76(to: first), 0.0, accuracy: 0.0)
    }

    func testCIE94PublishedReferenceAndApplicationWeighting() throws {
        let first = try lab(50.0, 2.6772, -79.7751)
        let second = try lab(50.0, 0.0, -82.7485)
        XCTAssertEqual(first.deltaE94(to: second), 1.3950388678587375, accuracy: 1e-14)
        XCTAssertEqual(first.deltaE94(to: second, application: .textiles),
                       1.4230462054212831, accuracy: 1e-14)
        XCTAssertNotEqual(first.deltaE94(to: second),
                          first.deltaE94(to: second, application: .textiles))
    }

    func testCIE94ZeroChromaAndSymmetricHueTerm() throws {
        let neutral = try lab(50.0, 0.0, 0.0)
        let other = try lab(55.0, 0.0, 0.0)
        XCTAssertEqual(neutral.deltaE94(to: other), 5.0, accuracy: 1e-14)
        XCTAssertEqual(neutral.deltaE94(to: neutral), 0.0, accuracy: 0.0)
        let first = try lab(50.0, 20.0, -30.0)
        let second = try lab(50.0, -10.0, 15.0)
        XCTAssertTrue(first.deltaE94(to: second).isFinite)
    }

    func testCIEDE2000PublishedReferencePairs() throws {
        let pairs: [(CIELABColor, CIELABColor, Double)] = [
            (try lab(50.0, 2.6772, -79.7751), try lab(50.0, 0.0, -82.7485), 2.0424596801565578),
            (try lab(50.0, 3.1571, -77.2803), try lab(50.0, 0.0, -82.7485), 2.8615101747474967),
            (try lab(50.0, 2.8361, -74.0200), try lab(50.0, 0.0, -82.7485), 3.4411905986907235),
            (try lab(50.0, -1.3802, -84.2814), try lab(50.0, 0.0, -82.7485), 0.9999988647524657)
        ]

        for (first, second, expected) in pairs {
            XCTAssertEqual(first.deltaE2000(to: second), expected, accuracy: 3e-14)
        }
    }

    func testCIEDE2000HandlesZeroChromaAndHueWrap() throws {
        let neutral = try lab(50.0, 0.0, 0.0)
        let color = try lab(50.0, 0.0001, -0.0001)
        XCTAssertEqual(neutral.deltaE2000(to: neutral), 0.0, accuracy: 0.0)
        XCTAssertTrue(neutral.deltaE2000(to: color).isFinite)

        let first = try lab(50.0, 0.1, -0.1)
        let second = try lab(50.0, 0.1, 0.1)
        XCTAssertTrue(first.deltaE2000(to: second).isFinite)
        XCTAssertEqual(first.deltaE2000(to: second), second.deltaE2000(to: first), accuracy: 1e-14)
    }

    private func lab(_ l: Double, _ a: Double, _ b: Double) throws -> CIELABColor {
        try CIELABColor(lStar: l / 100.0, aStar: a, bStar: b)
    }

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

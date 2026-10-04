import XCTest
import LUTCore
@testable import LUTPreview

final class ICCLabPCSContractsTests: XCTestCase {
    func testEightBitEncodingMatchesICCPCSReference() throws {
        let black = try ICCLabPCS.decode8([0, 128, 128])
        XCTAssertEqual(black.lStar, 0, accuracy: 0)
        XCTAssertEqual(black.aStar, 0, accuracy: 0)
        XCTAssertEqual(black.bStar, 0, accuracy: 0)

        let white = try ICCLabPCS.decode8([255, 128, 128])
        XCTAssertEqual(white.lStar, 1, accuracy: 0)
        XCTAssertEqual(white.aStar, 0, accuracy: 0)
        XCTAssertEqual(white.bStar, 0, accuracy: 0)

        let red = try ICCLabPCS.decode8([128, 255, 0])
        XCTAssertEqual(red.lStar, 128.0 / 255.0, accuracy: 0)
        XCTAssertEqual(red.aStar, 127, accuracy: 0)
        XCTAssertEqual(red.bStar, -128, accuracy: 0)
        XCTAssertEqual(try ICCLabPCS.encode8(red), [128, 255, 0])
    }

    func testSixteenBitEncodingUsesScaledABAndRoundTrips() throws {
        let encoded: [UInt16] = [32768, 65535, 0]
        let lab = try ICCLabPCS.decode16(encoded)
        XCTAssertEqual(lab.lStar, 100.0 * 32768.0 / 65535.0 / 100.0, accuracy: 0)
        XCTAssertEqual(lab.aStar, 127, accuracy: 1e-14)
        XCTAssertEqual(lab.bStar, -128, accuracy: 1e-14)
        XCTAssertEqual(try ICCLabPCS.encode16(lab), encoded)
    }

    func testD50PCSXYZBridgeMatchesCIELABReference() throws {
        let xyz = CIELABWhitePoint.d50.xyz
        let encoded = try ICCLabPCS.encode16(try CIELABColorSpace.fromXYZ(xyz, white: .d50))
        XCTAssertEqual(encoded, [65535, 32896, 32896])
        let restored = try ICCLabPCS.decode16ToXYZ(encoded)
        XCTAssertEqual(restored.x, xyz.x, accuracy: 1.0 / 65535.0)
        XCTAssertEqual(restored.y, xyz.y, accuracy: 1.0 / 65535.0)
        XCTAssertEqual(restored.z, xyz.z, accuracy: 1.0 / 65535.0)
    }

    func testInvalidPCSValuesAreRejectedWithoutClamping() throws {
        XCTAssertThrowsError(try ICCLabPCS.decode8([0, 0]))
        XCTAssertThrowsError(try ICCLabPCS.decode16([0, 0]))
        XCTAssertThrowsError(try ICCLabPCS.encode8(try CIELABColor(lStar: 1.01, aStar: 0, bStar: 0)))
        XCTAssertThrowsError(try ICCLabPCS.encode8(try CIELABColor(lStar: 0.5, aStar: 128, bStar: 0)))
        XCTAssertThrowsError(try ICCLabPCS.encode16(try CIELABColor(lStar: 0.5, aStar: -129, bStar: 0)))
    }
}

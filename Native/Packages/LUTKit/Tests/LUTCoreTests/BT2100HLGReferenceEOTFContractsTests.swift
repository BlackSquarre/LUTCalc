import XCTest
@testable import LUTCore

final class BT2100HLGReferenceEOTFContractsTests: XCTestCase {
    func testReferenceBlackLevelLiftUsesBT2100Note5i() throws {
        let ootf = try BT2100HLGReferenceOOTF(peakLuminanceNits: 1000)
        let beta = try ootf.blackLevelLift(blackLuminanceNits: 10)

        XCTAssertEqual(beta, 0.03731590344724128, accuracy: 2e-16)
        XCTAssertEqual(try ootf.blackLevelLift(blackLuminanceNits: 0), 0, accuracy: 0)
    }

    func testReferenceEOTFMatchesPublishedBlackAndPeakAnchors() throws {
        let ootf = try BT2100HLGReferenceOOTF(peakLuminanceNits: 1000)

        XCTAssertEqual(try ootf.encodedHLGToDisplay(0, blackLuminanceNits: 10),
                       0.1, accuracy: 2e-15)
        XCTAssertEqual(try ootf.encodedHLGToDisplay(0.5, blackLuminanceNits: 10),
                       55.519551438547895, accuracy: 2e-13)
        XCTAssertEqual(try ootf.encodedHLGToDisplay(1, blackLuminanceNits: 10),
                       1000.0000323217689, accuracy: 2e-12)
    }

    func testReferenceEOTFRGBUsesLuminanceCoupling() throws {
        let ootf = try BT2100HLGReferenceOOTF(peakLuminanceNits: 1000)
        let encoded = try RGB64(0.5, 0.75, 0.25)
        let display = try ootf.encodedHLGRGBToDisplay(encoded, blackLuminanceNits: 10)

        XCTAssertEqual(display.r, 66.00893002939895, accuracy: 2e-13)
        XCTAssertEqual(display.g, 204.05946496141178, accuracy: 2e-13)
        XCTAssertEqual(display.b, 18.915822424394885, accuracy: 2e-13)
    }

    func testReferenceEOTFInverseRoundTripsScalarAndRGB() throws {
        let ootf = try BT2100HLGReferenceOOTF(peakLuminanceNits: 1000)
        for encoded in [0.1, 0.5, 0.75, 1.0] {
            let display = try ootf.encodedHLGToDisplay(encoded, blackLuminanceNits: 10)
            let recovered = try ootf.displayToEncodedHLG(display, blackLuminanceNits: 10)
            XCTAssertEqual(recovered, encoded, accuracy: 3e-14)
        }

        let encoded = try RGB64(0.5, 0.75, 0.25)
        let display = try ootf.encodedHLGRGBToDisplay(encoded, blackLuminanceNits: 10)
        let recovered = try ootf.displayRGBToEncodedHLG(display, blackLuminanceNits: 10)
        XCTAssertEqual(recovered.r, encoded.r, accuracy: 3e-14)
        XCTAssertEqual(recovered.g, encoded.g, accuracy: 3e-14)
        XCTAssertEqual(recovered.b, encoded.b, accuracy: 3e-14)
    }

    func testReferenceEOTFInverseRejectsBlackFoldAndBelowBlack() throws {
        let ootf = try BT2100HLGReferenceOOTF(peakLuminanceNits: 1000)
        let black = try ootf.displayBlackLevel(blackLuminanceNits: 10)
        XCTAssertEqual(black, 0.1, accuracy: 2e-15)
        let negativeHeadroom = try ootf.encodedHLGToDisplay(-0.01, blackLuminanceNits: 10)
        XCTAssertEqual(negativeHeadroom, 0.04886459431084621, accuracy: 2e-15)
        XCTAssertGreaterThan(negativeHeadroom, 0)
        XCTAssertLessThan(negativeHeadroom, black)
        XCTAssertEqual(try ootf.displayToEncodedHLG(negativeHeadroom, blackLuminanceNits: 10),
                       -0.01, accuracy: 3e-14)
        XCTAssertThrowsError(try ootf.displayToEncodedHLG(0, blackLuminanceNits: 10))
        XCTAssertThrowsError(try ootf.displayToEncodedHLG(-1e-6, blackLuminanceNits: 10))

        let zeroBlack = try ootf.displayBlackLevel(blackLuminanceNits: 0)
        XCTAssertEqual(zeroBlack, 0, accuracy: 0)
        XCTAssertThrowsError(try ootf.displayToEncodedHLG(0, blackLuminanceNits: 0))

        let blackRGB = try RGB64(black, black, black)
        XCTAssertEqual(try ootf.displayRGBToEncodedHLG(blackRGB, blackLuminanceNits: 10).r, 0, accuracy: 2e-14)
        XCTAssertThrowsError(try ootf.displayRGBToEncodedHLG(RGB64(0, black, black), blackLuminanceNits: 10))
        XCTAssertThrowsError(try ootf.displayRGBToEncodedHLG(
            RGB64(black + 1, -1e-6, black + 1),
            blackLuminanceNits: 10
        ))
    }

    func testReferenceEOTFRejectsInvalidBlackLevelsAndNonFiniteInputs() throws {
        let ootf = try BT2100HLGReferenceOOTF(peakLuminanceNits: 1000)
        for black in [-1.0, 1000.0, 2000.0, .nan, .infinity] {
            XCTAssertThrowsError(try ootf.blackLevelLift(blackLuminanceNits: black))
        }
        XCTAssertThrowsError(try ootf.encodedHLGToDisplay(.nan, blackLuminanceNits: 10))
        XCTAssertThrowsError(try ootf.displayToEncodedHLG(.infinity, blackLuminanceNits: 10))
        XCTAssertThrowsError(try ootf.encodedHLGRGBToDisplay(
            RGB64(.nan, 0.5, 0.25), blackLuminanceNits: 10
        ))
    }
}

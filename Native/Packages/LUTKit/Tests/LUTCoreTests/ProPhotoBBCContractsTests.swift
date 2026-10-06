import XCTest
import LUTCore

final class ProPhotoBBCContractsTests: XCTestCase {
    func testProPhotoUsesPublishedPiecewiseTransfer() throws {
        XCTAssertEqual(try ProPhotoTransfer.encodeLinearToData(1.0 / 1024.0), 1.0 / 64.0, accuracy: 1e-15)
        XCTAssertEqual(try ProPhotoTransfer.encodeLinearToData(0.18), pow(0.18, 1.0 / 1.8), accuracy: 1e-15)
        XCTAssertEqual(try ProPhotoTransfer.decodeDataToLinear(1.0 / 64.0), 1.0 / 1024.0, accuracy: 1e-15)
        XCTAssertEqual(try ProPhotoTransfer.decodeDataToLinear(0.5), pow(0.5, 1.8), accuracy: 1e-15)
        XCTAssertEqual(try ProPhotoTransfer.encodeLegacyToData(0.18),
                       pow(0.18, 1.0 / 1.8) * 0.85630498533724 + 0.06256109481916,
                       accuracy: 1e-15)
    }

    func testProPhotoRoundTripsSignedAndRejectsNonFinite() throws {
        for value in [-0.25, -1.0 / 1024.0, 0, 1.0 / 1024.0, 0.18, 1.0, 2.0] {
            let encoded = try ProPhotoTransfer.encodeLinearToData(value)
            XCTAssertEqual(try ProPhotoTransfer.decodeDataToLinear(encoded), value, accuracy: 3e-15)
        }
        XCTAssertThrowsError(try ProPhotoTransfer.encodeLinearToData(.nan))
        XCTAssertThrowsError(try ProPhotoTransfer.decodeDataToLinear(.infinity))
    }

    func testBBCBatchUsesPublishedParametersAndInverse() throws {
        let expected: [(BBCGammaTransfer, Double, Double)] = [
            (.bbc04, 0.4, 0.037703),
            (.bbc05, 0.5, 0.020202),
            (.bbc06, 0.6, 0.008857)
        ]
        for (transfer, exponent, cut) in expected {
            XCTAssertEqual(transfer.exponent, exponent, accuracy: 0)
            let encoded = try transfer.encodeLegacyToData(cut * 0.9)
            XCTAssertEqual(try transfer.decodeDataToLegacy(encoded), cut * 0.9, accuracy: 3e-15)
            let highEncoded = try transfer.encodeLegacyToData(cut * 1.1)
            XCTAssertEqual(try transfer.decodeDataToLegacy(highEncoded), cut * 1.1, accuracy: 3e-15)
            XCTAssertEqual(transfer.encodedCut,
                           pow((cut + transfer.offset) / (1.0 + transfer.offset), exponent), accuracy: 0)
            XCTAssertEqual(try transfer.decodeDataToLegacy(try transfer.encodeLegacyToData(-0.25)), -0.25,
                           accuracy: 3e-15)
        }
    }

    func testBBCRejectsNonFinite() throws {
        XCTAssertThrowsError(try BBCGammaTransfer.bbc04.encodeLegacyToData(.nan))
        XCTAssertThrowsError(try BBCGammaTransfer.bbc05.decodeDataToLegacy(.infinity))
    }

    func testPlansRoundTripProPhotoAndBBCBatch() throws {
        let cases: [(TransferID, ColorSpaceID)] = [
            (.proPhoto, .proPhoto),
            (.bbc04, .srgb), (.bbc05, .srgb), (.bbc06, .srgb)
        ]
        for (transfer, space) in cases {
            let settings = TransformSettings(inputTransfer: transfer, outputTransfer: transfer,
                                              inputSpace: space, outputSpace: space,
                                              inputRange: .data, outputRange: .data, exposureStops: 0)
            let plan = try TransformPlan(settings: settings)
            if transfer == .proPhoto {
                XCTAssertEqual(try plan.evaluate(RGB64(0.18, 0.18, 0.18)).r, 0.18, accuracy: 5e-14)
            }
            let input = try RGB64(-0.1, 0.18, 0.8)
            let output = try plan.evaluate(input)
            XCTAssertEqual(output.r, input.r, accuracy: 5e-14)
            XCTAssertEqual(output.g, input.g, accuracy: 5e-14)
            XCTAssertEqual(output.b, input.b, accuracy: 5e-14)
        }
    }

    func testBBCPlanIdentityIncludesDirectionalColorSpaces() throws {
        let base = TransformSettings(inputTransfer: .bbc04, outputTransfer: .linearScene,
                                     inputSpace: .rec2020, outputSpace: .rec2020,
                                     inputRange: .data, outputRange: .data, exposureStops: 0)
        let baseline = try TransformPlan(settings: base).planVersion
        XCTAssertNotEqual(baseline, try TransformPlan(settings: base.withInput(transfer: .bbc04, space: .srgb)).planVersion)
        XCTAssertNotEqual(baseline, try TransformPlan(settings: base.withOutput(transfer: .linearScene, space: .srgb)).planVersion)
        XCTAssertTrue(baseline.contains(":inSpace:" + ColorSpaceID.rec2020.rawValue))
        XCTAssertTrue(baseline.contains(":outSpace:" + ColorSpaceID.rec2020.rawValue))
    }

}

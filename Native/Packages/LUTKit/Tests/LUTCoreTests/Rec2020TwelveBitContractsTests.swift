import XCTest
@testable import LUTCore
import LUTCatalog

final class Rec2020TwelveBitContractsTests: XCTestCase {
    func testHistoricalPiecewiseConstantsAndRoundTrip() throws {
        let transfer = Rec2020TwelveBitTransfer.self
        // The legacy registration stores separate encode/decode cut values.  At
        // the exact cuts the historical branches are therefore intentionally
        // discontinuous; assert each branch against its recorded formula.
        XCTAssertEqual(try transfer.encodeLinearToLegal(0.0181),
                       1.0993 * pow(0.0181, 0.45) - 0.0993, accuracy: 2e-15)
        XCTAssertEqual(try transfer.encodeLinearToLegal(0.18),
                       1.0993 * pow(0.18, 0.45) - 0.0993, accuracy: 2e-15)
        XCTAssertEqual(try transfer.decodeLegalToLinear(0.08145),
                       pow((0.08145 + 0.0993) / 1.0993, 1 / 0.45), accuracy: 2e-15)
        for value in [-0.1, 0, 0.0180, 0.0182, 0.18, 1, 4] {
            let data = try transfer.encodeLegacyToData(value)
            XCTAssertEqual(try transfer.decodeDataToLegacy(data), value, accuracy: 5e-14)
        }
        XCTAssertEqual(try transfer.encodeLinearToLegal(0.0181.nextDown),
                       4.5 * 0.0181.nextDown, accuracy: 2e-15)
        XCTAssertEqual(try transfer.decodeLegalToLinear(0.08145.nextDown),
                       0.08145.nextDown / 4.5, accuracy: 2e-15)
    }

    func testPlanAndCatalogKeepTenAndTwelveBitIdentitiesDistinct() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "Rec.2020 12-bit")?.id, .rec2020TwelveBit)
        XCTAssertNotEqual(TransferID.rec2020TenBit, .rec2020TwelveBit)
        let tenSettings = TransformSettings(
            inputTransfer: .rec2020TenBit, outputTransfer: .rec2020TenBit,
            inputSpace: .rec2020, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 0)
        XCTAssertTrue(try TransformPlan(settings: tenSettings).planVersion.hasPrefix(
            "minimal-rec2020-10bit-v1:"))

        let twelveSettings = TransformSettings(
            inputTransfer: .rec2020TwelveBit, outputTransfer: .rec2020TwelveBit,
            inputSpace: .rec2020, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 0)
        XCTAssertNotEqual(try TransformPlan(settings: twelveSettings).planVersion,
                          "minimal-rec2020-10bit-v1")
    }

    func testPlanIdentityIncludesDirectionAndBothColorSpaces() throws {
        func plan(input: TransferID, output: TransferID,
                  inputSpace: ColorSpaceID, outputSpace: ColorSpaceID) throws -> TransformPlan {
            try TransformPlan(settings: TransformSettings(
                inputTransfer: input, outputTransfer: output,
                inputSpace: inputSpace, outputSpace: outputSpace,
                inputRange: .data, outputRange: .data, exposureStops: 0))
        }

        let decode = try plan(input: .rec2020TwelveBit, output: .linearScene,
                              inputSpace: .rec2020, outputSpace: .srgb)
        let encode = try plan(input: .linearScene, output: .rec2020TwelveBit,
                              inputSpace: .srgb, outputSpace: .rec2020)
        let alternate = try plan(input: .rec2020TwelveBit, output: .linearScene,
                                 inputSpace: .displayP3, outputSpace: .srgb)

        XCTAssertNotEqual(decode.planVersion, encode.planVersion)
        XCTAssertNotEqual(decode.planVersion, alternate.planVersion)
    }

    func testNonFiniteInputsAreRejected() {
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try Rec2020TwelveBitTransfer.encodeLinearToLegal(value))
            XCTAssertThrowsError(try Rec2020TwelveBitTransfer.decodeLegalToLinear(value))
            XCTAssertThrowsError(try Rec2020TwelveBitTransfer.decodeDataToLegacy(value))
        }
    }
}

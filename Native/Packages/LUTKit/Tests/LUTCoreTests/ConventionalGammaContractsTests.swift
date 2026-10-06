import XCTest
@testable import LUTCore

final class ConventionalGammaContractsTests: XCTestCase {
    private let transfers: [(TransferID, Double)] = [
        (.gamma15, 1.5), (.gamma16, 1.6), (.gamma17, 1.7), (.gamma18, 1.8),
        (.gamma19, 1.9), (.gamma20, 2.0), (.gamma21, 2.1), (.gamma22, 2.2),
        (.gamma23, 2.3), (.gamma24, 2.4), (.gamma25, 2.5), (.gamma26, 2.6)
    ]

    func testAllLegacyGammaRegistrationsExposeTheirPublishedExponent() throws {
        for (id, exponent) in transfers {
            XCTAssertEqual(try ConventionalGammaTransfer.exponent(for: id), exponent, accuracy: 0)
        }
    }

    func testLegacyGammaUsesIndependentDataOffsetAndPowerBranch() throws {
        let dataOffset = 0.06256109481916
        let dataScale = 0.85630498533724
        let legacy = 0.18
        let expectedByExponent: [Double: Double] = [
            1.5: 0.33554904396988244,
            1.8: 0.39284771073508884,
            2.0: 0.42586053195664569,
            2.2: 0.45531089682619447,
            2.4: 0.48166851463022131,
            2.6: 0.50534805285706841
        ]
        for (id, exponent) in transfers where expectedByExponent[exponent] != nil {
            let data = try ConventionalGammaTransfer.encodeLegacyToData(legacy, transfer: id)
            XCTAssertEqual(data, expectedByExponent[exponent]!, accuracy: 1e-15)
            XCTAssertEqual(try ConventionalGammaTransfer.decodeDataToLegacy(data, transfer: id), legacy,
                           accuracy: 3e-15)
        }
        let lowLegacy = 5e-8
        let lowData = dataOffset + dataScale * lowLegacy
        XCTAssertEqual(try ConventionalGammaTransfer.decodeDataToLegacy(lowData, transfer: .gamma22), lowLegacy,
                       accuracy: 1e-15)
        XCTAssertEqual(try ConventionalGammaTransfer.encodeLegacyToData(-0.25, transfer: .gamma22),
                       dataOffset - dataScale * 0.25, accuracy: 1e-15)
    }

    func testGammaPlansRoundTripAllTwelveCurvesInLegacySameSpace() throws {
        for (id, _) in transfers {
            let settings = TransformSettings(
                inputTransfer: id, outputTransfer: id,
                inputSpace: .srgb, outputSpace: .srgb,
                inputRange: .data, outputRange: .data, exposureStops: 0
            )
            let plan = try TransformPlan(settings: settings)
            XCTAssertEqual(plan.planVersion,
                           "legacy-conventional-gamma-v2:\(id.rawValue):\(id.rawValue):inSpace:srgb.d65.v1:outSpace:srgb.d65.v1+" + OutputCodeUnitPolicy.completeV2.rawValue)
            let input = try RGB64(0.05, 0.45531089682619447, 0.92)
            let output = try plan.evaluate(input)
            XCTAssertEqual(output.r, input.r, accuracy: 3e-14, "(id) red")
            XCTAssertEqual(output.g, input.g, accuracy: 3e-14, "(id) green")
            XCTAssertEqual(output.b, input.b, accuracy: 3e-14, "(id) blue")
        }
    }

    func testGamma22AndGamma24HaveDistinctDirectionalPlanIdentities() throws {
        func plan(_ input: TransferID, _ output: TransferID) throws -> TransformPlan {
            try TransformPlan(settings: TransformSettings(
                inputTransfer: input, outputTransfer: output,
                inputSpace: .srgb, outputSpace: .srgb,
                inputRange: .data, outputRange: .data, exposureStops: 0))
        }
        let decode22 = try plan(.gamma22, .linearScene)
        let decode24 = try plan(.gamma24, .linearScene)
        let identity22 = try plan(.gamma22, .gamma22)
        let identity24 = try plan(.gamma24, .gamma24)
        let encode22 = try plan(.linearScene, .gamma22)
        let encode24 = try plan(.linearScene, .gamma24)
        XCTAssertNotEqual(decode22.planVersion, decode24.planVersion)
        XCTAssertNotEqual(identity22.planVersion, identity24.planVersion)
        XCTAssertNotEqual(encode22.planVersion, encode24.planVersion)
        XCTAssertNotEqual(decode22.planVersion, encode22.planVersion)

        let input = try RGB64(0.4, 0.4, 0.4)
        XCTAssertNotEqual(try decode22.evaluate(input).r, try decode24.evaluate(input).r)
        XCTAssertNotEqual(try encode22.evaluate(input).r, try encode24.evaluate(input).r)
    }

    func testConventionalGammaPlanIdentityIncludesBothColorSpaces() throws {
        func plan(inputSpace: ColorSpaceID, outputSpace: ColorSpaceID) throws -> String {
            try TransformPlan(settings: TransformSettings(
                inputTransfer: .gamma22, outputTransfer: .gamma22,
                inputSpace: inputSpace, outputSpace: outputSpace,
                inputRange: .data, outputRange: .data, exposureStops: 0
            )).planVersion
        }
        let baseline = try plan(inputSpace: .srgb, outputSpace: .srgb)
        XCTAssertNotEqual(baseline, try plan(inputSpace: .acesAP0, outputSpace: .srgb))
        XCTAssertNotEqual(baseline, try plan(inputSpace: .srgb, outputSpace: .acesAP0))
    }

    func testNonFiniteAndNonGammaInputsAreRejected() throws {
        XCTAssertThrowsError(try ConventionalGammaTransfer.encodeLegacyToData(.nan, transfer: .gamma22))
        XCTAssertThrowsError(try ConventionalGammaTransfer.decodeDataToLegacy(.infinity, transfer: .gamma22))
        XCTAssertThrowsError(try ConventionalGammaTransfer.exponent(for: .linearScene))
    }
}

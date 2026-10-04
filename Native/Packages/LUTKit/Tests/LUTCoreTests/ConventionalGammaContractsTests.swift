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
            XCTAssertEqual(plan.planVersion, "legacy-conventional-gamma-v1+" + OutputCodeUnitPolicy.completeV2.rawValue)
            let input = try RGB64(0.05, 0.45531089682619447, 0.92)
            let output = try plan.evaluate(input)
            XCTAssertEqual(output.r, input.r, accuracy: 3e-14, "(id) red")
            XCTAssertEqual(output.g, input.g, accuracy: 3e-14, "(id) green")
            XCTAssertEqual(output.b, input.b, accuracy: 3e-14, "(id) blue")
        }
    }

    func testNonFiniteAndNonGammaInputsAreRejected() throws {
        XCTAssertThrowsError(try ConventionalGammaTransfer.encodeLegacyToData(.nan, transfer: .gamma22))
        XCTAssertThrowsError(try ConventionalGammaTransfer.decodeDataToLegacy(.infinity, transfer: .gamma22))
        XCTAssertThrowsError(try ConventionalGammaTransfer.exponent(for: .linearScene))
    }
}

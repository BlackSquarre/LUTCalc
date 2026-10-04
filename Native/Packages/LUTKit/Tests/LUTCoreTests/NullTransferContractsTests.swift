import XCTest
@testable import LUTCore
import LUTCatalog

final class NullTransferContractsTests: XCTestCase {
    func testLegacyDataWrapperMatchesHistoricalNull() throws {
        let values = [-0.25, 0, 0.2, 1, 2.5]
        for value in values {
            let data = try NullTransfer.encodeLegacyToData(value)
            XCTAssertEqual(data, value * 0.85630498533724 + 0.06256109481916, accuracy: 0)
            XCTAssertEqual(try NullTransfer.decodeDataToLegacy(data), value, accuracy: 2e-16)
        }
    }

    func testNonFiniteAndPlanRoundTrip() throws {
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try NullTransfer.encodeLegacyToData(value))
            XCTAssertThrowsError(try NullTransfer.decodeDataToLegacy(value))
        }
        let settings = TransformSettings(
            inputTransfer: .nullLUTCalcLegacy, outputTransfer: .nullLUTCalcLegacy,
            inputSpace: .srgb, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 0)
        let value = try TransformPlan(settings: settings).evaluate(RGB64(0.2 * 0.9, 0.2 * 0.9, 0.2 * 0.9))
        XCTAssertEqual(value.r, 0.2 * 0.9, accuracy: 2e-15)
    }

    func testPlanIdentityDoesNotAliasNullOrSceneLinearWithDLog2() throws {
        func settings(_ transfer: TransferID) -> TransformSettings {
            TransformSettings(
                inputTransfer: transfer, outputTransfer: transfer,
                inputSpace: .srgb, outputSpace: .srgb,
                inputRange: .data, outputRange: .data, exposureStops: 0)
        }
        let dlog2 = try TransformPlan(settings: settings(.djiDLog2)).planVersion
        let null = try TransformPlan(settings: settings(.nullLUTCalcLegacy)).planVersion
        let linear = try TransformPlan(settings: settings(.linearScene)).planVersion
        let nullToLinear = try TransformPlan(settings: TransformSettings(
            inputTransfer: .nullLUTCalcLegacy, outputTransfer: .linearScene,
            inputSpace: .srgb, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 0)).planVersion
        XCTAssertEqual(dlog2, "minimal-dlog2-v1")
        XCTAssertEqual(null, "analytic-null-legacy-v1+" + OutputCodeUnitPolicy.completeV2.rawValue)
        XCTAssertEqual(linear, "minimal-linear-scene-v1")
        XCTAssertNotEqual(dlog2, null)
        XCTAssertNotEqual(dlog2, linear)
        XCTAssertNotEqual(null, linear)
        XCTAssertTrue(nullToLinear.contains(TransferID.nullLUTCalcLegacy.rawValue))
        XCTAssertNotEqual(nullToLinear, dlog2)
        XCTAssertNotEqual(nullToLinear, linear)
    }

    func testCatalogIdentity() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "Null (LUTCalc legacy)")?.id, .nullLUTCalcLegacy)
        XCTAssertTrue(TransferID.nullLUTCalcLegacy.hasNormalizedDataEncoding)
    }
}

import XCTest
@testable import LUTCore

final class Rec2020TenBitContractsTests: XCTestCase {
    private let tolerance = 2e-15

    func testBT2020TenBitPiecewiseConstantsAndRoundTrip() throws {
        XCTAssertEqual(try Rec2020TenBitTransfer.encodeSceneToData(0.017), 0.0765, accuracy: tolerance)
        XCTAssertEqual(try Rec2020TenBitTransfer.decodeDataToScene(0.0765), 0.017, accuracy: tolerance)
        XCTAssertEqual(try Rec2020TenBitTransfer.encodeSceneToData(0.018),
                       1.099 * pow(0.018, 0.45) - 0.099, accuracy: tolerance)
        XCTAssertEqual(try Rec2020TenBitTransfer.encodeSceneToData(0.18),
                       1.099 * pow(0.18, 0.45) - 0.099, accuracy: tolerance)
        for value in [-0.25, 0, 0.001, 0.018, 0.18, 1, 4] {
            let encoded = try Rec2020TenBitTransfer.encodeSceneToData(value)
            XCTAssertEqual(try Rec2020TenBitTransfer.decodeDataToScene(encoded), value, accuracy: tolerance)
        }
    }

    func testTenBitCurveIsMonotonicAndRejectsNonFinite() throws {
        let samples: [Double] = Array(stride(from: -0.1, through: 2.0, by: 0.001))
        var previous = -Double.infinity
        for value in samples {
            let encoded = try Rec2020TenBitTransfer.encodeSceneToData(value)
            XCTAssertGreaterThanOrEqual(encoded, previous)
            previous = encoded
        }
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try Rec2020TenBitTransfer.encodeSceneToData(value))
            XCTAssertThrowsError(try Rec2020TenBitTransfer.decodeDataToScene(value))
        }
    }

    func testTransformPlanUsesIndependentTenBitIdentityAndNormalizedDataUnits() throws {
        let settings = TransformSettings(
            inputTransfer: .rec2020TenBit, outputTransfer: .rec2020TenBit,
            inputSpace: .rec2020, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )
        let plan = try TransformPlan(settings: settings)
        XCTAssertEqual(plan.planVersion,
                       "minimal-rec2020-10bit-v1:rec2020.bt2020-10bit.v1:rec2020.bt2020-10bit.v1:inSpace:rec2020.d65.v1:outSpace:rec2020.d65.v1")
        let encoded = try Rec2020TenBitTransfer.encodeSceneToData(0.18)
        let result = try plan.evaluate(RGB64(encoded, encoded, encoded))
        XCTAssertEqual(result.r, encoded, accuracy: tolerance)
        XCTAssertEqual(settings.outputTransfer.outputLegalScale(policy: .completeV2), 876.0 / 1023.0, accuracy: 1e-15)
        XCTAssertEqual(settings.outputTransfer.outputLegalOffset(policy: .completeV2), 64.0 / 1023.0, accuracy: 1e-15)
    }
}

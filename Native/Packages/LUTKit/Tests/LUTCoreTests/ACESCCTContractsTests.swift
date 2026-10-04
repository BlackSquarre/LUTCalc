import XCTest
@testable import LUTCore

final class ACESCCTContractsTests: XCTestCase {
    private let tolerance = 2e-12

    func testPublishedPiecewiseScalarValues() throws {
        let encoded: [(Double, Double)] = [
            (0, 0.0729055341958355),
            (0.0078125, 0.155251141552511),
            (0.18, 0.4135884024924423),
            (1, 0.5547945205479452),
        ]
        for (linear, expected) in encoded {
            XCTAssertEqual(try ACESCCTTransfer.encodeLinearAP1ToCCT(linear), expected, accuracy: tolerance)
        }
        let decoded: [(Double, Double)] = [
            (0, -0.006916877586898862),
            (0.0729055341958355, 0),
            (0.155251141552511, 0.0078125),
            (0.4135884024924423, 0.18),
            (1, 222.8609442038076),
        ]
        for (cct, expected) in decoded {
            XCTAssertEqual(try ACESCCTTransfer.decodeCCTToLinearAP1(cct), expected, accuracy: tolerance)
        }
    }

    func testNonFiniteAndInvalidOutputsAreRejected() {
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try ACESCCTTransfer.encodeLinearAP1ToCCT(value))
            XCTAssertThrowsError(try ACESCCTTransfer.decodeCCTToLinearAP1(value))
        }
    }

    func testSameSpaceExposurePlanUsesACEScct() throws {
        let settings = TransformSettings(
            inputTransfer: .acesCCT, outputTransfer: .linearScene,
            inputSpace: .acesAP1, outputSpace: .acesAP1,
            inputRange: .data, outputRange: .data, exposureStops: 1
        )
        let plan = try TransformPlan(settings: settings)
        XCTAssertEqual(plan.planVersion, "minimal-acescct-v1")
        let encoded = try ACESCCTTransfer.encodeLinearAP1ToCCT(0.18)
        let result = try plan.evaluate(RGB64(encoded, encoded, encoded))
        XCTAssertEqual(result.r, 0.36, accuracy: tolerance)
        XCTAssertEqual(result.g, 0.36, accuracy: tolerance)
        XCTAssertEqual(result.b, 0.36, accuracy: tolerance)
    }
}

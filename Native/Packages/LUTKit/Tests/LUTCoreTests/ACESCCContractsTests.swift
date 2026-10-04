import XCTest
@testable import LUTCore

final class ACESCCContractsTests: XCTestCase {
    private let tolerance = 2e-12

    func testPublishedPiecewiseScalarValues() throws {
        let low = pow(2.0, -15.0)
        let encoded: [(Double, Double)] = [
            (-1.0, -0.3584474886),
            (0.0, -0.3584474886),
            (low * 0.5, (log2(pow(2.0, -16.0) + low * 0.25) + 9.72) / 17.52),
            (low, (log2(low) + 9.72) / 17.52),
            (0.18, (log2(0.18) + 9.72) / 17.52),
            (1.0, (log2(1.0) + 9.72) / 17.52),
        ]
        for (linear, expected) in encoded {
            XCTAssertEqual(try ACESCCTransfer.encodeLinearAP1ToCC(linear), expected, accuracy: tolerance)
        }
        let decoded: [(Double, Double)] = [
            (-1.0, 0),
            (-0.3584474886, 0),
            (ACESCCTransfer.publishedLowCode - 1e-9,
             2.0 * (exp2((ACESCCTransfer.publishedLowCode - 1e-9) * 17.52 - 9.72) - pow(2.0, -16.0))),
            (ACESCCTransfer.publishedLowCode, pow(2.0, -15.0)),
            ((log2(0.18) + 9.72) / 17.52, 0.18),
        ]
        for (encoded, expected) in decoded {
            XCTAssertEqual(try ACESCCTransfer.decodeCCToLinearAP1(encoded), expected, accuracy: tolerance)
        }
    }

    func testRoundTripAcrossPublishedDomain() throws {
        for linear in [0.0, 1e-8, pow(2.0, -15.0), 0.18, 1.0, 100.0, 65503.0] {
            let encoded = try ACESCCTransfer.encodeLinearAP1ToCC(linear)
            let decoded = try ACESCCTransfer.decodeCCToLinearAP1(encoded)
            XCTAssertEqual(decoded, linear, accuracy: max(2e-12, abs(linear) * 2e-12))
        }
    }

    func testSameSpaceExposurePlanUsesACEScc() throws {
        let settings = TransformSettings(
            inputTransfer: .acesCC, outputTransfer: .linearScene,
            inputSpace: .acesAP1, outputSpace: .acesAP1,
            inputRange: .data, outputRange: .data, exposureStops: 1)
        let plan = try TransformPlan(settings: settings)
        XCTAssertEqual(plan.planVersion, "minimal-acescc-v1")
        let encoded = try ACESCCTransfer.encodeLinearAP1ToCC(0.18)
        let result = try plan.evaluate(RGB64(encoded, encoded, encoded))
        XCTAssertEqual(result.r, 0.36, accuracy: tolerance)
    }

    func testNonFiniteValuesAreRejected() {
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try ACESCCTransfer.encodeLinearAP1ToCC(value))
            XCTAssertThrowsError(try ACESCCTransfer.decodeCCToLinearAP1(value))
        }
    }
}

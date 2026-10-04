import XCTest
@testable import LUTCore

final class MiLogContractsTests: XCTestCase {
    private let tolerance = 2e-12

    func testPublishedThreeSegmentValues() throws {
        let encoded: [(Double, Double)] = [
            (-0.1, 0),
            (-0.09023729, 0),
            (0, 0.14742742933404765),
            (0.01974185, 0.21899128351135033),
            (0.18, 0.45345966860449516),
            (1, 0.6747578058671936),
        ]
        for (scene, expected) in encoded {
            XCTAssertEqual(try MiLogTransfer.encodeSceneToData(scene), expected, accuracy: tolerance)
        }
        let decoded: [(Double, Double)] = [
            (-0.1, -0.09023729),
            (0, -0.09023729),
            (0.14742742933404765, 0),
            (0.2189912907018895, 0.01974185180557248),
            (0.45345966860449516, 0.18),
            (1, 11.520029260905842),
        ]
        for (data, expected) in decoded {
            XCTAssertEqual(try MiLogTransfer.decodeDataToScene(data), expected, accuracy: tolerance)
        }
    }

    func testNonFiniteInputsAreRejected() {
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try MiLogTransfer.encodeSceneToData(value))
            XCTAssertThrowsError(try MiLogTransfer.decodeDataToScene(value))
        }
    }

    func testRec2020LinearExposurePlanUsesMiLogDecode() throws {
        let settings = TransformSettings(
            inputTransfer: .xiaomiMiLog, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 1
        )
        let plan = try TransformPlan(settings: settings)
        XCTAssertEqual(plan.planVersion, "minimal-milog-v1")
        let encoded = try MiLogTransfer.encodeSceneToData(0.18)
        let result = try plan.evaluate(RGB64(encoded, encoded, encoded))
        XCTAssertEqual(result.r, 0.36, accuracy: tolerance)
        XCTAssertEqual(result.g, 0.36, accuracy: tolerance)
        XCTAssertEqual(result.b, 0.36, accuracy: tolerance)
    }
}

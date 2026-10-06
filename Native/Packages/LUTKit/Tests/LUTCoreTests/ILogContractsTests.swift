import XCTest
@testable import LUTCore

final class ILogContractsTests: XCTestCase {
    private let tolerance = 2e-12

    func testPublishedPiecewiseScalarValues() throws {
        let encoded: [(Double, Double)] = [
            (0, 0.09055934),
            (0.01104854, 0.15440192831901123),
            (0.18, 0.4220033397148445),
            (1, 0.6252022223346979),
            (22, 0.9999994560172779),
        ]
        for (scene, expected) in encoded {
            XCTAssertEqual(try ILogTransfer.encodeSceneToData(scene), expected, accuracy: tolerance)
        }
        let decoded: [(Double, Double)] = [
            (0, -0.01567211663418186),
            (0.154401, 0.01104837934596015),
            (0.154402, 0.011048551979189218),
            (0.422003, 0.17999946931125516),
            (1, 22.0000984415578),
        ]
        for (data, expected) in decoded {
            XCTAssertEqual(try ILogTransfer.decodeDataToScene(data), expected, accuracy: tolerance)
        }
    }

    func testNonFiniteInputsAreRejected() {
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try ILogTransfer.encodeSceneToData(value))
            XCTAssertThrowsError(try ILogTransfer.decodeDataToScene(value))
        }
    }

    func testSameGamutExposurePlanUsesDoubleILog() throws {
        let settings = TransformSettings(
            inputTransfer: .insta360ILog, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 1
        )
        let plan = try TransformPlan(settings: settings)
        XCTAssertEqual(plan.planVersion,
                       "minimal-ilog-v1:insta360.ilog.v1:linear.scene.v1:inSpace:rec2020.d65.v1:outSpace:rec2020.d65.v1")
        let encoded = try ILogTransfer.encodeSceneToData(0.18)
        let result = try plan.evaluate(RGB64(encoded, encoded, encoded))
        XCTAssertEqual(result.r, 0.36, accuracy: tolerance)
        XCTAssertEqual(result.g, 0.36, accuracy: tolerance)
        XCTAssertEqual(result.b, 0.36, accuracy: tolerance)
    }

    func testDirectionAndGamutArePartOfILogPlanIdentity() throws {
        let forward = try TransformPlan(settings: TransformSettings(
            inputTransfer: .insta360ILog, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 0))
        let reverse = try TransformPlan(settings: TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .insta360ILog,
            inputSpace: .srgb, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 0))
        XCTAssertNotEqual(forward.planVersion, reverse.planVersion)
        XCTAssertTrue(forward.planVersion.contains(":inSpace:rec2020.d65.v1:outSpace:srgb.d65.v1"))
        XCTAssertTrue(reverse.planVersion.contains(":inSpace:srgb.d65.v1:outSpace:rec2020.d65.v1"))
    }
}

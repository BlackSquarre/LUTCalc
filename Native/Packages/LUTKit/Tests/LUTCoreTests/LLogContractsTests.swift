import XCTest
@testable import LUTCore

final class LLogContractsTests: XCTestCase {
    private let tolerance = 2e-12

    func testPublishedBT2020PiecewiseValues() throws {
        let encoded: [(Double, Double)] = [
            (0, 0.09),
            (0.006, 0.138),
            (0.006000001, 0.1371004813304076),
            (0.18, 0.43531390404392656),
            (1, 0.6317974396301205),
            (23.3, 0.9999953144781841),
        ]
        for (scene, expected) in encoded {
            XCTAssertEqual(try LeicaLLogTransfer.encodeSceneToData(scene), expected, accuracy: tolerance)
        }
        let decoded: [(Double, Double)] = [
            (0, -0.01125),
            (0.138, 0.006000000000000002),
            (0.1380001, 0.006114339211806405),
            (0.4, 0.1308922914134868),
            (1, 23.300931406664585),
        ]
        for (data, expected) in decoded {
            XCTAssertEqual(try LeicaLLogTransfer.decodeDataToScene(data), expected, accuracy: tolerance)
        }
    }

    func testNonFiniteInputsAreRejected() {
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try LeicaLLogTransfer.encodeSceneToData(value))
            XCTAssertThrowsError(try LeicaLLogTransfer.decodeDataToScene(value))
        }
    }

    func testRec2020LinearExposurePlanUsesLeicaLLog() throws {
        let settings = TransformSettings(
            inputTransfer: .leicaLLog, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 1
        )
        let plan = try TransformPlan(settings: settings)
        XCTAssertTrue(plan.planVersion.hasPrefix("minimal-llog-v1:"))
        let encoded = try LeicaLLogTransfer.encodeSceneToData(0.18)
        let result = try plan.evaluate(RGB64(encoded, encoded, encoded))
        XCTAssertEqual(result.r, 0.36, accuracy: tolerance)
        XCTAssertEqual(result.g, 0.36, accuracy: tolerance)
        XCTAssertEqual(result.b, 0.36, accuracy: tolerance)
    }

    func testPlanIdentityIncludesDirectionAndBothColorSpaces() throws {
        func version(inputTransfer: TransferID = .leicaLLog,
                     outputTransfer: TransferID = .linearScene,
                     inputSpace: ColorSpaceID = .rec2020,
                     outputSpace: ColorSpaceID = .rec2020) throws -> String {
            try TransformPlan(settings: TransformSettings(
                inputTransfer: inputTransfer, outputTransfer: outputTransfer,
                inputSpace: inputSpace, outputSpace: outputSpace,
                inputRange: .data, outputRange: .data, exposureStops: 0
            )).planVersion
        }

        let baseline = try version()
        XCTAssertNotEqual(try version(inputTransfer: .linearScene, outputTransfer: .leicaLLog), baseline)
        XCTAssertNotEqual(try version(inputSpace: .srgb), baseline)
        XCTAssertNotEqual(try version(outputSpace: .displayP3), baseline)
    }
}

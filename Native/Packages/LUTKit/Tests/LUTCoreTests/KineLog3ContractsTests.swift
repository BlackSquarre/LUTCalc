import XCTest
@testable import LUTCore

final class KineLog3ContractsTests: XCTestCase {
    private let tolerance = 2e-12

    func testPublishedPiecewiseValues() throws {
        let encoded: [(Double, Double)] = [
            (-0.01, -0.10251484456863433),
            (-0.008239, -0.000005979822652601996),
            (0.0, 0.092864),
            (0.18, 0.39192837738102315),
            (1.0, 0.5842960972868599),
        ]
        for (scene, expected) in encoded {
            XCTAssertEqual(try KineLog3Transfer.encodeSceneToData(scene), expected, accuracy: tolerance)
        }
        let decoded: [(Double, Double)] = [
            (-0.1, -0.0099568),
            (0.0, -0.008238652985721474),
            (0.39192837738102315, 0.18),
            (0.5842960972868599, 1.0),
            (0.5, 0.4776354992695545),
        ]
        for (data, expected) in decoded {
            XCTAssertEqual(try KineLog3Transfer.decodeDataToScene(data), expected, accuracy: tolerance)
        }
    }

    func testNonFiniteInputsAreRejected() {
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try KineLog3Transfer.encodeSceneToData(value))
            XCTAssertThrowsError(try KineLog3Transfer.decodeDataToScene(value))
        }
    }

    func testKinefinityWideGamutExposurePlanUsesKineLog3() throws {
        let settings = TransformSettings(
            inputTransfer: .kineLog3, outputTransfer: .linearScene,
            inputSpace: .kinefinityWideGamut, outputSpace: .kinefinityWideGamut,
            inputRange: .data, outputRange: .data, exposureStops: 1
        )
        let plan = try TransformPlan(settings: settings)
        XCTAssertTrue(plan.planVersion.hasPrefix("minimal-kinelog3-v1:"))
        let encoded = try KineLog3Transfer.encodeSceneToData(0.18)
        let result = try plan.evaluate(RGB64(encoded, encoded, encoded))
        XCTAssertEqual(result.r, 0.36, accuracy: tolerance)
    }

    func testPlanIdentityIncludesDirectionAndBothColorSpaces() throws {
        func version(inputTransfer: TransferID = .kineLog3,
                     outputTransfer: TransferID = .linearScene,
                     inputSpace: ColorSpaceID = .kinefinityWideGamut,
                     outputSpace: ColorSpaceID = .kinefinityWideGamut) throws -> String {
            try TransformPlan(settings: TransformSettings(
                inputTransfer: inputTransfer, outputTransfer: outputTransfer,
                inputSpace: inputSpace, outputSpace: outputSpace,
                inputRange: .data, outputRange: .data, exposureStops: 0
            )).planVersion
        }

        let baseline = try version()
        XCTAssertNotEqual(try version(inputTransfer: .linearScene, outputTransfer: .kineLog3), baseline)
        XCTAssertNotEqual(try version(inputSpace: .rec2020), baseline)
        XCTAssertNotEqual(try version(outputSpace: .displayP3), baseline)
    }
}

import XCTest
@testable import LUTCore

final class FLog2ContractsTests: XCTestCase {
    private let tolerance = 2e-12

    func testPublishedScalarBranchesAndBoundaries() throws {
        let encoded: [(Double, Double)] = [
            (0, 0.092864),
            (0.000888, 0.100677921368),
            (0.000889, 0.10068668537081137),
            (0.18, 0.39100724189123005),
            (1, 0.5682193704444426),
        ]
        for (scene, expected) in encoded {
            XCTAssertEqual(try FLog2Transfer.encodeSceneToData(scene), expected, accuracy: tolerance)
        }
        let decoded: [(Double, Double)] = [
            (0, -0.010553373666864368),
            (0.1, 0.0008109587621332716),
            (0.100686685370811, 0.0008889999999999569),
            (0.5, 0.5215565404860289),
            (1, 58.25087401956106),
        ]
        for (data, expected) in decoded {
            XCTAssertEqual(try FLog2Transfer.decodeDataToScene(data), expected, accuracy: tolerance)
        }
        let sceneCut = 0.000889
        XCTAssertEqual(try FLog2Transfer.encodeSceneToData(sceneCut.nextDown),
                       0.100686720829, accuracy: tolerance)
        XCTAssertEqual(try FLog2Transfer.encodeSceneToData(sceneCut.nextUp),
                       0.10068668537081137, accuracy: tolerance)
        let dataCut = 0.100686685370811
        XCTAssertEqual(try FLog2Transfer.decodeDataToScene(dataCut.nextDown),
                       0.0008889959704135287, accuracy: tolerance)
        XCTAssertEqual(try FLog2Transfer.decodeDataToScene(dataCut.nextUp),
                       0.0008890000000000748, accuracy: tolerance)
    }

    func testNonFiniteInputsAreRejected() {
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try FLog2Transfer.encodeSceneToData(value))
            XCTAssertThrowsError(try FLog2Transfer.decodeDataToScene(value))
        }
    }

    func testMinimalSameGamutPlanUsesDoubleTransfer() throws {
        let settings = TransformSettings(
            inputTransfer: .fujifilmFLog2, outputTransfer: .linearScene,
            inputSpace: .fujifilmFGamut, outputSpace: .fujifilmFGamut,
            inputRange: .data, outputRange: .data, exposureStops: 1
        )
        let plan = try TransformPlan(settings: settings)
        XCTAssertEqual(plan.planVersion, "minimal-flog2-v1")
        let output = try plan.evaluate(RGB64(0.092864, 0.39100724189123005, 0.5))
        XCTAssertEqual(output.r, 0, accuracy: tolerance)
        XCTAssertEqual(output.g, 0.36, accuracy: tolerance)
        XCTAssertEqual(output.b, 1.0431130809720578, accuracy: tolerance)
    }

    func testFLog2CSameTransferUsesDistinctPublishedGamutMatrix() throws {
        let settings = TransformSettings(
            inputTransfer: .fujifilmFLog2, outputTransfer: .linearScene,
            inputSpace: .fujifilmFGamutC, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )
        let plan = try TransformPlan(settings: settings)
        XCTAssertEqual(plan.planVersion, "minimal-flog2c-v1")
        let output = try plan.evaluate(RGB64(0.39100724189123005, 0.39100724189123005, 0.39100724189123005))
        XCTAssertTrue(output.r.isFinite && output.g.isFinite && output.b.isFinite)
        XCTAssertNotEqual(output.r, output.g)
        XCTAssertNotEqual(output.g, output.b)
    }

    func testFLog2CPrimariesDerivePublishedDoubleRGBToXYZMatrix() throws {
        let matrix = try ColorPrimaries.fujifilmFGamutC.rgbToXYZ()
        let expected: [Double] = [
            0.7892749677891813, 0.02004022987995402, 0.14114072938253645,
            0.28500700824073743, 0.7419456971144954, -0.026952705355232877,
            0.0, 0.0, 1.0890577507598784,
        ]
        for (actual, reference) in zip(matrix.rowMajor, expected) {
            XCTAssertEqual(actual, reference, accuracy: 2e-15)
        }
    }

    func testLegacyPublishedBranchesAndBoundaries() throws {
        let encoded: [(Double, Double)] = [
            (0, 0.09286400228842304),
            (0.000987778.nextDown, 0.10068672489727597),
            (0.000987778.nextUp, 0.10068668706729689),
            (0.2, 0.39100724189123004),
            (1.1111111111111112, 0.5682193704444426),
        ]
        for (legacyLinear, expected) in encoded {
            XCTAssertEqual(try FLog2Transfer.encodeLegacyToData(legacyLinear), expected, accuracy: tolerance)
        }
        let decoded: [(Double, Double)] = [
            (0, -0.011725971),
            (0.092864, -2.889600000249849e-10),
            (0.100686685, 0.0009877777292052923),
            (0.5, 0.5795072672066989),
            (1, 64.72319335506789),
        ]
        for (data, expected) in decoded {
            XCTAssertEqual(try FLog2Transfer.decodeLegacyDataToLegacy(data), expected, accuracy: tolerance)
        }
    }

    func testLegacyNonFiniteInputsAreRejected() {
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try FLog2Transfer.encodeLegacyToData(value))
            XCTAssertThrowsError(try FLog2Transfer.decodeLegacyDataToLegacy(value))
        }
    }

    func testMinimalLegacySameGamutPlanUsesIndependentTransfer() throws {
        let settings = TransformSettings(
            inputTransfer: .fujifilmFLog2LUTCalcLegacy, outputTransfer: .linearScene,
            inputSpace: .fujifilmFGamut, outputSpace: .fujifilmFGamut,
            inputRange: .data, outputRange: .data, exposureStops: 1
        )
        let plan = try TransformPlan(settings: settings)
        XCTAssertEqual(plan.planVersion, "minimal-flog2-legacy-v1")
        let output = try plan.evaluate(RGB64(0.09286400228842304, 0.39100724189123004, 0.5))
        XCTAssertEqual(output.r, 0, accuracy: tolerance)
        XCTAssertEqual(output.g, 0.36, accuracy: tolerance)
        XCTAssertEqual(output.b, 1.0431130809720578, accuracy: tolerance)
    }
}

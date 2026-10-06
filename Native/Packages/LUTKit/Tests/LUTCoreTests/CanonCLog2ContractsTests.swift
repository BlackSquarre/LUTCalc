import XCTest
@testable import LUTCore
import LUTCatalog

final class CanonCLog2ContractsTests: XCTestCase {
    private let tolerance = 2e-12

    func testPublishedCTLBranchesAndInverse() throws {
        let encoded: [(Double, Double)] = [
            (-0.1, -0.1553701299749708),
            (0, 0.092864125),
            (0.18, 0.39825469203794917),
            (1, 0.5732292786822208),
        ]
        for (scene, expected) in encoded {
            XCTAssertEqual(try CanonCLog2Transfer.encodeSceneToData(scene), expected, accuracy: tolerance)
            XCTAssertEqual(try CanonCLog2Transfer.decodeDataToScene(expected), scene, accuracy: tolerance)
        }
        let decoded: [(Double, Double)] = [
            (-0.1, -0.05472447444516182),
            (0, -0.014726903701747047),
            (0.092864125, 0),
            (0.5, 0.4920822150856757),
            (1, 59.23450201202016),
        ]
        for (data, expected) in decoded {
            XCTAssertEqual(try CanonCLog2Transfer.decodeDataToScene(data), expected, accuracy: tolerance)
        }
    }

    func testLegacyBranchesRemainIndependent() throws {
        let encoded: [(Double, Double)] = [
            (-0.1, -2.064716968437319),
            (-0.006747091156, 4.057074537433536e-10),
            (0, 0.092864125),
            (0.18, 0.3878410279822183),
            (1, 0.5623042648035375),
        ]
        for (legacy, expected) in encoded {
            XCTAssertEqual(try CanonCLog2Transfer.encodeLegacyToData(legacy), expected, accuracy: tolerance)
            XCTAssertEqual(try CanonCLog2Transfer.decodeLegacyDataToLegacy(expected), legacy, accuracy: tolerance)
        }
        XCTAssertNotEqual(try CanonCLog2Transfer.encodeSceneToData(0.18),
                          try CanonCLog2Transfer.encodeLegacyToData(0.18))
    }

    func testCinemaGamutCAT02MatrixMatchesIndependentDecimalReference() throws {
        let matrix = try ColorPrimaries.conversion(from: ColorSpaceID.canonCinemaGamut.primaries,
                                                    to: ColorSpaceID.acesAP0.primaries,
                                                    adaptation: .cieCAT02)
        let expected: [Double] = [
            0.76306445477573395, 0.14902116113706039, 0.08791438408720566,
            0.003657456705123844, 1.106960380376215, -0.11061783708133881,
            -0.009407794045718891, -0.21838330498998712, 1.227791099035706,
        ]
        for (actual, reference) in zip(matrix.rowMajor, expected) {
            XCTAssertEqual(actual, reference, accuracy: 2e-14)
        }
    }

    func testCatalogPresetAndFourCanonCLog2CameraDefaults() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertNotNil(catalog.transfer(named: TransferID.canonCLog2.rawValue))
        XCTAssertNotNil(catalog.colorSpace(named: ColorSpaceID.canonCinemaGamut.rawValue))
        let base = TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
                                     inputSpace: .rec2020, outputSpace: .rec2020,
                                     inputRange: .data, outputRange: .data, exposureStops: 0)
        for id in ["camera.canon.c300mkiii.v1", "camera.canon.c300mkii.v1", "camera.canon.c500mkiii.v1"] {
            for policy in [CameraInputPolicy.publishedAvailableDefaults, .legacyAvailableDefaults] {
                let camera = try CameraExposureSettings.selecting(profileID: id, inputPolicy: policy)
                let settings = try CameraPresetResolver.applying(camera, to: base)
                XCTAssertEqual(settings.inputSpace, .canonCinemaGamut)
                XCTAssertEqual(settings.inputTransfer,
                               policy == .publishedAvailableDefaults ? .canonCLog2 : .canonCLog2LUTCalcLegacy)
            }
        }
        XCTAssertThrowsError(try CameraPresetResolver.applying(
            try CameraExposureSettings.selecting(profileID: "camera.canon.c300.v1",
                                                  inputPolicy: .publishedAvailableDefaults), to: base))
    }

    func testNonFiniteInputsAreRejected() {
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try CanonCLog2Transfer.encodeSceneToData(value))
            XCTAssertThrowsError(try CanonCLog2Transfer.decodeDataToScene(value))
            XCTAssertThrowsError(try CanonCLog2Transfer.encodeLegacyToData(value))
            XCTAssertThrowsError(try CanonCLog2Transfer.decodeLegacyDataToLegacy(value))
        }
    }

    func testPlanIdentityIncludesDirectionAndBothColorSpaces() throws {
        let decode = try TransformPlan(settings: TransformSettings(
            inputTransfer: .canonCLog2, outputTransfer: .linearScene,
            inputSpace: .canonCinemaGamut, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 0))
        let alternate = try TransformPlan(settings: TransformSettings(
            inputTransfer: .canonCLog2, outputTransfer: .linearScene,
            inputSpace: .canonCinemaGamut, outputSpace: .displayP3,
            inputRange: .data, outputRange: .data, exposureStops: 0))
        XCTAssertNotEqual(decode.planVersion, alternate.planVersion)
        XCTAssertTrue(decode.planVersion.contains(":inSpace:"))
    }
}

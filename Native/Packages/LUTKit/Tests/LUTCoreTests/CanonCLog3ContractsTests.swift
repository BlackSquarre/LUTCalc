import XCTest
@testable import LUTCore
import LUTCatalog

final class CanonCLog3ContractsTests: XCTestCase {
    private let tolerance = 2e-12

    func testPublishedCTLBranchesAndInverse() throws {
        let encoded: [(Double, Double)] = [
            (-0.1, -0.028494507620494353),
            (-0.014, 0.09442172749082348),
            (0, 0.12512219),
            (0.014, 0.15582265250917654),
            (0.18, 0.3433893703739355),
            (1, 0.5802777942163708)
        ]
        for (scene, expected) in encoded {
            XCTAssertEqual(try CanonCLog3Transfer.encodeSceneToData(scene), expected, accuracy: tolerance)
            XCTAssertEqual(try CanonCLog3Transfer.decodeDataToScene(expected), scene, accuracy: tolerance)
        }
    }

    func testPublishedCTLDecodeBranches() throws {
        let decoded: [(Double, Double)] = [
            (-0.1, -0.19054237798428442),
            (0.097465473, -0.012599999908882895),
            (0.12512219, 0),
            (0.15277891, 0.012600001275639466),
            (0.18, 0.02612262562752861),
            (0.5, 0.5807774047880196),
            (1, 14.668301411196483)
        ]
        for (data, expected) in decoded {
            XCTAssertEqual(try CanonCLog3Transfer.decodeDataToScene(data), expected, accuracy: tolerance)
        }
    }

    func testCinemaGamutMatrixRemainsThePublishedCAT02Identity() throws {
        let matrix = try ColorPrimaries.conversion(from: ColorSpaceID.canonCinemaGamut.primaries,
                                                    to: ColorSpaceID.acesAP0.primaries,
                                                    adaptation: .cieCAT02)
        let expected: [Double] = [
            0.76306445477573395, 0.14902116113706039, 0.08791438408720566,
            0.003657456705123844, 1.106960380376215, -0.11061783708133881,
            -0.009407794045718891, -0.21838330498998712, 1.227791099035706
        ]
        for (actual, reference) in zip(matrix.rowMajor, expected) {
            XCTAssertEqual(actual, reference, accuracy: 2e-14)
        }
    }

    func testNonFiniteInputsAreRejected() {
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try CanonCLog3Transfer.encodeSceneToData(value))
            XCTAssertThrowsError(try CanonCLog3Transfer.decodeDataToScene(value))
        }
    }

    func testCatalogRegistrationAndPublishedPlanIdentity() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "Canon C-Log3")?.id, .canonCLog3)
        let settings = try XCTUnwrap(catalog.preset(named: "canon.c-log3-to-linear-ap0-published.v1")?.settings)
        XCTAssertEqual(settings.inputTransfer, .canonCLog3)
        XCTAssertEqual(settings.inputSpace, .canonCinemaGamut)
        XCTAssertEqual(try TransformPlan(settings: settings).planVersion,
                       "canon-clog3-plan-v1:" + TransferID.canonCLog3.rawValue + ":" + TransferID.linearScene.rawValue + ":gamut:" + ColorSpaceID.canonCinemaGamut.rawValue)
    }

    func testCanonCinemaGamutAloneDoesNotSelectCLog3Plan() throws {
        let settings = TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
                                         inputSpace: .canonCinemaGamut, outputSpace: .canonCinemaGamut,
                                         inputRange: .data, outputRange: .data, exposureStops: 0)
        let plan = try TransformPlan(settings: settings)
        XCTAssertFalse(settings.referencesCanonCLog3)
        XCTAssertTrue(plan.planVersion.hasPrefix("canon-clog2-plan-v1:"))
    }

}

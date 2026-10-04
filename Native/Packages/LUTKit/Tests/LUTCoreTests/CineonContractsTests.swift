import XCTest
@testable import LUTCore
import LUTCatalog

final class CineonContractsTests: XCTestCase {
    func testPublishedBlackOffsetFormulaAndInverse() throws {
        let references: [(Double, Double)] = [
            (0, 0.09286412512218964),
            (0.001, 0.10402783497152696),
            (0.18, 0.4573196130854184),
            (1, 0.6695992179863147),
            (4, 0.8451208074035219),
        ]
        for (scene, data) in references {
            XCTAssertEqual(try CineonTransfer.encodeSceneToData(scene), data, accuracy: 2e-15)
            XCTAssertEqual(try CineonTransfer.decodeDataToScene(data), scene, accuracy: 3e-14)
        }
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try CineonTransfer.encodeSceneToData(value))
            XCTAssertThrowsError(try CineonTransfer.decodeDataToScene(value))
        }
    }

    func testLegacyToeAndLogFormulaRemainDistinctAndInvertible() throws {
        let references: [(Double, Double)] = [
            (0, 0.09286412512218975),
            (0.001, 0.10295448283944264),
            (0.2, 0.4573196130854184),
            (1.1111111111111112, 0.6695992179863147),
        ]
        for (legacy, data) in references {
            XCTAssertEqual(try CineonTransfer.encodeLegacyToData(legacy), data, accuracy: 2e-15)
            XCTAssertEqual(try CineonTransfer.decodeDataToLegacy(data), legacy, accuracy: 3e-14)
        }
        XCTAssertEqual(try CineonTransfer.decodeDataToLegacy(0), -0.006278688266063196, accuracy: 2e-15)
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try CineonTransfer.encodeLegacyToData(value))
            XCTAssertThrowsError(try CineonTransfer.decodeDataToLegacy(value))
        }
    }

    func testCatalogPresetAndGenericCameraPoliciesRouteExplicitly() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let published = try XCTUnwrap(catalog.transfer(named: "cineon.v1"))
        XCTAssertEqual(published.id, .cineon)
        XCTAssertTrue(published.source.contains("colour-science/colour"))
        let legacy = try XCTUnwrap(catalog.transfer(named: "cineon.lutcalc-legacy.v1"))
        XCTAssertEqual(legacy.id, .cineonLUTCalcLegacy)
        XCTAssertNotEqual(published.linearReference, legacy.linearReference)
        XCTAssertEqual(try XCTUnwrap(catalog.preset(named: "cineon.exposure-one.v1")).settings.inputTransfer, .cineon)
        XCTAssertEqual(try XCTUnwrap(catalog.preset(named: "cineon.legacy-exposure-one.v1")).settings.inputTransfer, .cineonLUTCalcLegacy)
        let base = TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )
        let generic = try XCTUnwrap(CameraCatalog.profile(id: "camera.generic.v1"))
        for policy in [CameraInputPolicy.publishedAvailableDefaults, .legacyAvailableDefaults] {
            let state = try CameraExposureSettings.selecting(profileID: generic.id, inputPolicy: policy)
            let settings = try CameraPresetResolver.applying(state, to: base)
            XCTAssertEqual(settings.inputTransfer, policy == .publishedAvailableDefaults ? .cineon : .cineonLUTCalcLegacy)
            XCTAssertEqual(settings.inputSpace, .srgb)
            _ = try TransformPlan(settings: settings)
        }
    }
}

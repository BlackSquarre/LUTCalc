import XCTest
@testable import LUTCore
import LUTCatalog

final class NikonNLogContractsTests: XCTestCase {
    private let tolerance = 2e-14

    func testLegacyPiecewiseFormulaWithHistoricalLinearAdaptation() throws {
        // The Nikon PDF defines y as reflected-light exposure. LUTCalc's
        // legacy linear domain applies the historical 0.9 adaptation first.
        let expected: [(Double, Double)] = [
            (0, 0.12440830062571302),
            (0.001, 0.12919787344406677),
            (0.18, 0.3517376336714785),
            (0.328 / 0.9, 0.4416312310951134),
            (1, 0.5896343329924987),
            (4, 0.7929033008986408),
        ]
        for (scene, reference) in expected {
            XCTAssertEqual(try NikonNLogTransfer.encodeLegacyToData(scene), reference, accuracy: tolerance)
        }
        let decoded: [(Double, Double)] = [
            (0, -0.008333333333333333),
            (0.12440830062571302, 0),
            (0.3517376336714785, 0.18),
            (0.5, 0.5426416340735412),
            (1, 16.423181600555722),
        ]
        for (data, reference) in decoded {
            XCTAssertEqual(try NikonNLogTransfer.decodeDataToLegacy(data), reference, accuracy: tolerance)
        }
    }

    func testPublishedReflectanceFormulaIsSeparateFromLegacy() throws {
        XCTAssertEqual(try NikonNLogTransfer.encodeSceneToData(0.18), 0.3636677701171387, accuracy: 2e-15)
        XCTAssertEqual(try NikonNLogTransfer.decodeDataToScene(452.0 / 1023), exp((452.0 - 619) / 150), accuracy: 2e-15)
        XCTAssertEqual(try NikonNLogTransfer.encodeSceneToData(0.328), (150 * log(0.328) + 619) / 1023, accuracy: 2e-15)
    }

    func testToeAndShoulderBoundariesRemainContinuous() throws {
        let sceneCut = 0.328 / 0.9
        let dataCut = 451.7887494 / 1023.0
        XCTAssertEqual(try NikonNLogTransfer.encodeLegacyToData(sceneCut), dataCut, accuracy: 2e-10)
        XCTAssertEqual(try NikonNLogTransfer.decodeDataToLegacy(dataCut), sceneCut, accuracy: 4e-10)
        XCTAssertEqual(try NikonNLogTransfer.encodeLegacyToData(sceneCut.nextDown), dataCut, accuracy: 2e-10)
        XCTAssertEqual(try NikonNLogTransfer.encodeLegacyToData(sceneCut.nextUp), dataCut, accuracy: 2e-10)
        XCTAssertEqual(try NikonNLogTransfer.decodeDataToLegacy(dataCut.nextDown), sceneCut, accuracy: 4e-10)
        XCTAssertEqual(try NikonNLogTransfer.decodeDataToLegacy(dataCut.nextUp), sceneCut, accuracy: 4e-10)
    }

    func testRoundTripMonotonicityAndNonFiniteRejection() throws {
        var previous = -Double.infinity
        for index in 0...4000 {
            let scene = -0.01 + Double(index) * 4.01 / 4000.0
            let data = try NikonNLogTransfer.encodeLegacyToData(scene)
            XCTAssertGreaterThanOrEqual(data, previous)
            XCTAssertEqual(try NikonNLogTransfer.decodeDataToLegacy(data), scene, accuracy: 3e-14)
            previous = data
        }
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try NikonNLogTransfer.encodeLegacyToData(value))
            XCTAssertThrowsError(try NikonNLogTransfer.decodeDataToLegacy(value))
        }
    }

    func testCatalogPresetAndNikonCameraRouteUseNLog() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let transfer = try XCTUnwrap(catalog.transfer(named: "nikon.nlog.v1"))
        XCTAssertEqual(transfer.id, .nikonNLog)
        XCTAssertTrue(transfer.source.contains("N-Log_Specification_(En)01.pdf"))
        let preset = try XCTUnwrap(catalog.preset(named: "nikon.nlog-exposure-one.v1"))
        XCTAssertEqual(preset.settings.inputTransfer, .nikonNLog)
        XCTAssertEqual(preset.settings.outputTransfer, .nikonNLog)
        XCTAssertEqual(preset.settings.inputSpace, .rec2020)
        let base = TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )
        for profileID in ["camera.nikon.z6.v1", "camera.nikon.z7.v1"] {
            let camera = try CameraExposureSettings.selecting(
                profileID: profileID, inputPolicy: .publishedAvailableDefaults
            )
            let settings = try CameraPresetResolver.applying(camera, to: base)
            XCTAssertEqual(settings.inputTransfer, .nikonNLog)
            XCTAssertEqual(settings.inputSpace, .rec2020)
            XCTAssertEqual(settings.inputRange, .data)
            _ = try TransformPlan(settings: settings)
        }
    }
}

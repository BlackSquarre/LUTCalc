import XCTest
@testable import LUTCore
import LUTCatalog

final class CanonCLogContractsTests: XCTestCase {
    private struct Point: Decodable { let input: Double; let output: String }
    private struct Reference: Decodable { let precision: Int; let encode: [Point]; let decode: [Point] }
    func testLegacyPiecewiseFormulaAndDomain() throws {
        XCTAssertEqual(try CanonCLogTransfer.encodeLegacyToData(0.2), 0.34338965172606756, accuracy: 2e-15)
        XCTAssertEqual(try CanonCLogTransfer.decodeDataToLegacy(0.34338965172606756), 0.2, accuracy: 2e-14)
        XCTAssertThrowsError(try CanonCLogTransfer.encodeLegacyToData(.nan))
        XCTAssertTrue(try CanonCLogTransfer.encodeLegacyToData(-0.1).isFinite)
    }

    func testCatalogPlanAndLegacyCameraRoute() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "Canon C-Log (LUTCalc legacy)")?.id, .canonCLogLUTCalcLegacy)
        let base = TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .canonCinemaGamut, outputSpace: .canonCinemaGamut,
            inputRange: .data, outputRange: .data, exposureStops: 0)
        let state = try CameraExposureSettings.selecting(profileID: "camera.canon.c500.v1",
                                                         inputPolicy: .legacyAvailableDefaults)
        let settings = try CameraPresetResolver.applying(state, to: base)
        XCTAssertEqual(settings.inputTransfer, .canonCLogLUTCalcLegacy)
        XCTAssertEqual(settings.inputSpace, .canonCinemaGamut)
        XCTAssertTrue(try TransformPlan(settings: settings).planVersion.contains("canon.c-log.lutcalc-legacy.v1"))
    }

    func testLegacyMethodsMatchActualFrozenJavaScriptExecution() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { root.deleteLastPathComponent() }
        let ref = try JSONDecoder().decode(Reference.self, from: Data(contentsOf:
            root.appendingPathComponent("tests/fixtures/native-contracts/canon-clog-legacy-reference.json")))
        XCTAssertEqual(ref.precision, 64)
        for point in ref.encode {
            XCTAssertEqual(try CanonCLogTransfer.encodeLegacyToData(point.input), try XCTUnwrap(Double(point.output)), accuracy: 2e-12)
        }
        for point in ref.decode {
            XCTAssertEqual(try CanonCLogTransfer.decodeDataToLegacy(point.input), try XCTUnwrap(Double(point.output)), accuracy: 2e-12)
        }
    }
}

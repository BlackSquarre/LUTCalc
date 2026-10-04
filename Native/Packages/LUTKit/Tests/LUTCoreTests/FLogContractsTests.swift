import XCTest
@testable import LUTCore
import LUTCatalog

final class FLogContractsTests: XCTestCase {
    private struct Point: Decodable { let input: Double; let output: String }
    private struct Reference: Decodable { let precision: Int; let sourceSHA256: String; let encode: [Point]; let decode: [Point] }

    private func reference() throws -> Reference {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { root.deleteLastPathComponent() }
        return try JSONDecoder().decode(Reference.self, from: Data(contentsOf:
            root.appendingPathComponent("tests/fixtures/native-contracts/flog-legacy-reference.json")))
    }

    func testLegacyFormulaMatchesFrozenJavaScriptExecution() throws {
        let ref = try reference()
        XCTAssertEqual(ref.precision, 64)
        XCTAssertEqual(ref.sourceSHA256, "250017d8efe758f3555148ba9fcb923698add0ac7d9380fa290716eb98e0821e")
        for point in ref.encode {
            XCTAssertEqual(try FLogTransfer.encodeLegacyToData(point.input), try XCTUnwrap(Double(point.output)), accuracy: 2e-15)
        }
        for point in ref.decode {
            XCTAssertEqual(try FLogTransfer.decodeDataToLegacy(point.input), try XCTUnwrap(Double(point.output)), accuracy: 2e-14)
        }
    }

    func testNonFiniteValuesAreRejected() {
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try FLogTransfer.encodeLegacyToData(value))
            XCTAssertThrowsError(try FLogTransfer.decodeDataToLegacy(value))
        }
    }

    func testPlanAndCameraRouteApplyLegacyScaleOnce() throws {
        let base = TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .fujifilmFGamut, outputSpace: .fujifilmFGamut,
            inputRange: .data, outputRange: .data, exposureStops: 0)
        let state = try CameraExposureSettings.selecting(profileID: "camera.fujifilm.mirrorless-f-log.v1",
                                                         inputPolicy: .legacyAvailableDefaults)
        let settings = try CameraPresetResolver.applying(state, to: base)
        XCTAssertEqual(settings.inputTransfer, .fujifilmFLogLUTCalcLegacy)
        XCTAssertEqual(settings.inputSpace, .fujifilmFGamut)
        XCTAssertTrue(try TransformPlan(settings: settings).planVersion.hasPrefix(
            "analytic-flog-legacy-v1:fujifilm.flog.lutcalc-legacy.v1:linear.scene.v1"))
        let code = try FLogTransfer.encodeLegacyToData(0.2)
        let output = try TransformPlan(settings: settings).evaluate(RGB64(code, code, code))
        XCTAssertEqual(output.r, 0.18, accuracy: 2e-14)
    }

    func testCatalogAndOutputCodeUnitIdentity() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "F-Log (LUTCalc legacy)")?.id, .fujifilmFLogLUTCalcLegacy)
        XCTAssertNotNil(catalog.preset(named: "fujifilm.flog-legacy-exposure-one.v1"))
        XCTAssertTrue(TransferID.fujifilmFLogLUTCalcLegacy.hasNormalizedDataEncoding)
        XCTAssertEqual(TransferID.fujifilmFLogLUTCalcLegacy.outputLegalScale(policy: .completeV2), 876.0 / 1023.0, accuracy: 1e-15)
    }
}

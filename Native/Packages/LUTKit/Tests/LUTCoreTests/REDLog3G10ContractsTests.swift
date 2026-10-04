import XCTest
@testable import LUTCore
import LUTCatalog

final class REDLog3G10ContractsTests: XCTestCase {
    private struct Point: Decodable { let input: Double; let output: String }
    private struct Reference: Decodable {
        let precision: Int
        let sourceSHA256: String
        let encode: [Point]
        let decode: [Point]
    }

    private func reference() throws -> Reference {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { root.deleteLastPathComponent() }
        return try JSONDecoder().decode(Reference.self, from: Data(contentsOf:
            root.appendingPathComponent("tests/fixtures/native-contracts/red-log3g10-legacy-reference.json")))
    }

    func testLegacyFormulaMatchesFrozenJavaScriptExecution() throws {
        let ref = try reference()
        XCTAssertEqual(ref.precision, 64)
        XCTAssertFalse(ref.sourceSHA256.isEmpty)
        for point in ref.encode {
            XCTAssertEqual(try REDLog3G10Transfer.encodeLegacyToData(point.input),
                           try XCTUnwrap(Double(point.output)), accuracy: 3e-15)
        }
        for point in ref.decode {
            XCTAssertEqual(try REDLog3G10Transfer.decodeDataToLegacy(point.input),
                           try XCTUnwrap(Double(point.output)), accuracy: 3e-14)
        }
    }

    func testBoundaryAndNonFiniteInputs() throws {
        let boundary = -0.01 / 0.9
        let below = try REDLog3G10Transfer.encodeLegacyToData(boundary - 1e-12)
        let above = try REDLog3G10Transfer.encodeLegacyToData(boundary + 1e-12)
        XCTAssertTrue(below.isFinite && above.isFinite)
        XCTAssertEqual(try REDLog3G10Transfer.decodeDataToLegacy(
            try REDLog3G10Transfer.encodeLegacyToData(0)), 0, accuracy: 3e-15)
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try REDLog3G10Transfer.encodeLegacyToData(value))
            XCTAssertThrowsError(try REDLog3G10Transfer.decodeDataToLegacy(value))
        }
    }

    func testPlanAppliesLegacyGreyBoundaryExactlyOnce() throws {
        let encoded = try REDLog3G10Transfer.encodeLegacyToData(0.2)
        let decodeSettings = TransformSettings(
            inputTransfer: .redLog3G10LUTCalcLegacy, outputTransfer: .linearScene,
            inputSpace: .redWideGamutRGB, outputSpace: .redWideGamutRGB,
            inputRange: .data, outputRange: .data, exposureStops: 0)
        let decoded = try TransformPlan(settings: decodeSettings).evaluate(RGB64(encoded, encoded, encoded))
        XCTAssertEqual(decoded.r, 0.18, accuracy: 3e-14)

        let encodeSettings = TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .redLog3G10LUTCalcLegacy,
            inputSpace: .redWideGamutRGB, outputSpace: .redWideGamutRGB,
            inputRange: .data, outputRange: .data, exposureStops: 0)
        XCTAssertEqual(try TransformPlan(settings: encodeSettings).evaluate(RGB64(0.18, 0.18, 0.18)).r,
                       encoded, accuracy: 3e-15)
        XCTAssertEqual(try TransformPlan(settings: encodeSettings).planVersion,
                       "analytic-red-log3g10-legacy-v1:linear.scene.v1:red.log3g10.lutcalc-legacy.v1")
    }

    func testCatalogAndDataIdentity() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "RED Log3G10 (LUTCalc legacy)")?.id,
                       .redLog3G10LUTCalcLegacy)
        XCTAssertEqual(catalog.preset(named: "red.log3g10-legacy-exposure-one.v1")?.settings.inputTransfer,
                       .redLog3G10LUTCalcLegacy)
        XCTAssertTrue(TransferID.redLog3G10LUTCalcLegacy.hasNormalizedDataEncoding)
        XCTAssertEqual(TransferID.redLog3G10LUTCalcLegacy.outputLegalScale(policy: .completeV2),
                       876.0 / 1023.0, accuracy: 1e-15)
        XCTAssertEqual(TransferID.redLog3G10LUTCalcLegacy.outputLegalOffset(policy: .completeV2),
                       64.0 / 1023.0, accuracy: 1e-15)
    }
}

import XCTest
@testable import LUTCore
import LUTCatalog

final class BMDPocketFilmContractsTests: XCTestCase {
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
            root.appendingPathComponent("tests/fixtures/native-contracts/bmd-pocket-film-legacy-reference.json")))
    }

    func testLegacyFormulaMatchesFrozenJavaScriptExecution() throws {
        let ref = try reference()
        XCTAssertEqual(ref.precision, 64)
        XCTAssertEqual(ref.sourceSHA256, "250017d8efe758f3555148ba9fcb923698add0ac7d9380fa290716eb98e0821e")
        for point in ref.encode {
            XCTAssertEqual(try BMDPocketFilmTransfer.encodeLegacyToData(point.input), try XCTUnwrap(Double(point.output)), accuracy: 2e-15)
        }
        for point in ref.decode {
            XCTAssertEqual(try BMDPocketFilmTransfer.decodeDataToLegacy(point.input), try XCTUnwrap(Double(point.output)), accuracy: 2e-14)
        }
    }

    func testNonFiniteInputsAreRejected() {
        for value in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertThrowsError(try BMDPocketFilmTransfer.encodeLegacyToData(value))
            XCTAssertThrowsError(try BMDPocketFilmTransfer.decodeDataToLegacy(value))
        }
    }

    func testLegacySceneBoundaryIsAppliedExactlyOnceByPlan() throws {
        let encoded = try BMDPocketFilmTransfer.encodeLegacyToData(0.2)
        let decodeSettings = TransformSettings(
            inputTransfer: .blackmagicPocketFilmLUTCalcLegacy, outputTransfer: .linearScene,
            inputSpace: .srgb, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 0)
        let decoded = try TransformPlan(settings: decodeSettings).evaluate(RGB64(encoded, encoded, encoded))
        XCTAssertEqual(decoded.r, 0.18, accuracy: 2e-14)

        let encodeSettings = TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .blackmagicPocketFilmLUTCalcLegacy,
            inputSpace: .srgb, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 0)
        let encodedAgain = try TransformPlan(settings: encodeSettings).evaluate(RGB64(0.18, 0.18, 0.18))
        XCTAssertEqual(encodedAgain.r, encoded, accuracy: 2e-15)
        XCTAssertEqual(try TransformPlan(settings: encodeSettings).planVersion,
                       "analytic-bmd-pocket-film-legacy-v1:linear.scene.v1:blackmagic.pocket-film.lutcalc-legacy.v1:inSpace:srgb.d65.v1:outSpace:srgb.d65.v1")
    }

    func testCatalogIdentityAndNormalizedDataClassification() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "BMD Pocket Film (LUTCalc legacy)")?.id,
                       .blackmagicPocketFilmLUTCalcLegacy)
        XCTAssertEqual(catalog.preset(named: "blackmagic.pocket-film-legacy-exposure-one.v1")?.settings.inputSpace,
                       .srgb)
        XCTAssertTrue(TransferID.blackmagicPocketFilmLUTCalcLegacy.hasNormalizedDataEncoding)
        XCTAssertEqual(TransferID.blackmagicPocketFilmLUTCalcLegacy.outputLegalScale(policy: .completeV2), 876.0 / 1023.0, accuracy: 1e-15)
        XCTAssertEqual(TransferID.blackmagicPocketFilmLUTCalcLegacy.outputLegalOffset(policy: .completeV2), 64.0 / 1023.0, accuracy: 1e-15)
    }

    func testLegacyPlanIdentityIncludesBothColorSpaces() throws {
        let baseline = try TransformPlan(settings: TransformSettings(
            inputTransfer: .blackmagicPocketFilmLUTCalcLegacy, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 0))
        let alternate = try TransformPlan(settings: TransformSettings(
            inputTransfer: .blackmagicPocketFilmLUTCalcLegacy, outputTransfer: .linearScene,
            inputSpace: .displayP3, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 0))
        XCTAssertNotEqual(baseline.planVersion, alternate.planVersion)
    }
}

import XCTest
@testable import LUTCore
import LUTCatalog

final class BMDLegacyFilmContractsTests: XCTestCase {
    private struct Point: Decodable { let input: Double; let output: String }
    private struct Variant: Decodable { let params: [String]; let encodeCut: String; let decodeCut: String; let encode: [Point]; let decode: [Point] }
    private struct Reference: Decodable { let precision: Int; let sourceSHA256: String; let variants: [String: Variant] }

    private func reference() throws -> Reference {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { root.deleteLastPathComponent() }
        return try JSONDecoder().decode(Reference.self, from: Data(contentsOf: root.appendingPathComponent("tests/fixtures/native-contracts/bmd-film-legacy-reference.json")))
    }

    func testLegacyFormulasMatchFrozenJavaScriptExecution() throws {
        let ref = try reference()
        XCTAssertEqual(ref.precision, 64)
        XCTAssertFalse(ref.sourceSHA256.isEmpty)
        let cases: [(String, BMDLegacyFilmTransfer.Variant)] = [("film", .film), ("film4k", .film4k), ("film46k", .film46k)]
        for (name, variant) in cases {
            let item = try XCTUnwrap(ref.variants[name])
            for point in item.encode { XCTAssertEqual(try BMDLegacyFilmTransfer.encodeLegacyToData(point.input, variant: variant), try XCTUnwrap(Double(point.output)), accuracy: 3e-15) }
            for point in item.decode { XCTAssertEqual(try BMDLegacyFilmTransfer.decodeDataToLegacy(point.input, variant: variant), try XCTUnwrap(Double(point.output)), accuracy: 3e-14) }
        }
    }

    func testNonFiniteAndPlanBoundary() throws {
        for variant in [BMDLegacyFilmTransfer.Variant.film, .film4k, .film46k] {
            for value in [Double.nan, Double.infinity, -Double.infinity] {
                XCTAssertThrowsError(try BMDLegacyFilmTransfer.encodeLegacyToData(value, variant: variant))
                XCTAssertThrowsError(try BMDLegacyFilmTransfer.decodeDataToLegacy(value, variant: variant))
            }
        }
        let encoded = try BMDLegacyFilmTransfer.encodeLegacyToData(0.2 / 0.9, variant: .film)
        let settings = TransformSettings(inputTransfer: .blackmagicFilmLUTCalcLegacy, outputTransfer: .linearScene,
            inputSpace: .srgb, outputSpace: .srgb, inputRange: .data, outputRange: .data, exposureStops: 0)
        XCTAssertEqual(try TransformPlan(settings: settings).evaluate(RGB64(encoded, encoded, encoded)).r, 0.2, accuracy: 3e-14)
        XCTAssertTrue(try TransformPlan(settings: settings).planVersion.hasPrefix("analytic-bmd-film-family-legacy-v1:"))
    }

    func testCatalogIdentitiesAndLegalClassification() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "BMD Film (LUTCalc legacy)")?.id, .blackmagicFilmLUTCalcLegacy)
        XCTAssertEqual(catalog.transfer(named: "BMD Film4k (LUTCalc legacy)")?.id, .blackmagicFilm4kLUTCalcLegacy)
        XCTAssertEqual(catalog.transfer(named: "BMD Film4.6k (LUTCalc legacy)")?.id, .blackmagicFilm46kLUTCalcLegacy)
        XCTAssertEqual(catalog.preset(named: "blackmagic.film4k-legacy-exposure-one.v1")?.settings.inputTransfer, .blackmagicFilm4kLUTCalcLegacy)
        XCTAssertTrue(TransferID.blackmagicFilm46kLUTCalcLegacy.hasNormalizedDataEncoding)
    }
}

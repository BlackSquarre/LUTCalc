import XCTest
@testable import LUTCore
import LUTCatalog

final class DaVinciIntermediateContractsTests: XCTestCase {
    private struct Point: Decodable { let input: Double; let output: String }
    private struct Reference: Decodable { let precision: Int; let sourceSHA256: String; let encode: [Point]; let decode: [Point] }
    private func reference() throws -> Reference { var root=URL(fileURLWithPath:#filePath); for _ in 0..<6 {root.deleteLastPathComponent()}; return try JSONDecoder().decode(Reference.self,from:Data(contentsOf:root.appendingPathComponent("tests/fixtures/native-contracts/davinci-intermediate-legacy-reference.json"))) }
    func testFormulaMatchesJavaScript() throws { let r=try reference(); XCTAssertEqual(r.precision,64); for p in r.encode { let expected=try XCTUnwrap(Double(p.output)); XCTAssertEqual(try DaVinciIntermediateTransfer.encodeLegacyToData(p.input),expected,accuracy:max(3e-15,abs(expected)*1e-15)) }; for p in r.decode { let expected=try XCTUnwrap(Double(p.output)); XCTAssertEqual(try DaVinciIntermediateTransfer.decodeDataToLegacy(p.input),expected,accuracy:max(3e-14,abs(expected)*1e-15)) } }
    func testNonFiniteBoundaryAndPlan() throws { for x in [Double.nan,Double.infinity,-Double.infinity] {XCTAssertThrowsError(try DaVinciIntermediateTransfer.encodeLegacyToData(x)); XCTAssertThrowsError(try DaVinciIntermediateTransfer.decodeDataToLegacy(x))}; let e=try DaVinciIntermediateTransfer.encodeLegacyToData(0.2/0.9); let s=TransformSettings(inputTransfer:.daVinciIntermediateLUTCalcLegacy,outputTransfer:.linearScene,inputSpace:.srgb,outputSpace:.srgb,inputRange:.data,outputRange:.data,exposureStops:0); XCTAssertEqual(try TransformPlan(settings:s).evaluate(RGB64(e,e,e)).r,0.2,accuracy:3e-14); let p=TransformSettings(inputTransfer:.daVinciIntermediateLUTCalcLegacy,outputTransfer:.daVinciIntermediateLUTCalcLegacy,inputSpace:.srgb,outputSpace:.srgb,inputRange:.data,outputRange:.data,exposureStops:1); let roundTrip=try TransformPlan(settings:p).evaluate(RGB64(0,0,0)); XCTAssertEqual(roundTrip.r, -0.06256109481916, accuracy: 1e-15) }
    func testCatalogIdentity() throws { let c=try AlgorithmCatalog.builtIn(); XCTAssertEqual(c.transfer(named:"DaVinci Intermediate (LUTCalc legacy)")?.id,.daVinciIntermediateLUTCalcLegacy); XCTAssertTrue(TransferID.daVinciIntermediateLUTCalcLegacy.hasNormalizedDataEncoding) }
}

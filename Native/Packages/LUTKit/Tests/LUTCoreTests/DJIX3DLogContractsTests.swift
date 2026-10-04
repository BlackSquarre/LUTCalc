import XCTest
@testable import LUTCore
import LUTCatalog

final class DJIX3DLogContractsTests: XCTestCase {
    private struct Point: Decodable { let input: Double; let output: String }
    private struct Reference: Decodable { let precision: Int; let sourceSHA256: String; let encode: [Point]; let decode: [Point] }
    private func reference() throws -> Reference { var root=URL(fileURLWithPath:#filePath); for _ in 0..<6 {root.deleteLastPathComponent()}; return try JSONDecoder().decode(Reference.self,from:Data(contentsOf:root.appendingPathComponent("tests/fixtures/native-contracts/dji-x3-dlog-reference.json"))) }
    func testFormulaMatchesJavaScript() throws { let r=try reference(); XCTAssertEqual(r.precision,64); for p in r.encode { XCTAssertEqual(try DJIX3DLogTransfer.encodeLegacyToData(p.input),try XCTUnwrap(Double(p.output)),accuracy:3e-14) }; for p in r.decode { XCTAssertEqual(try DJIX3DLogTransfer.decodeDataToLegacy(p.input),try XCTUnwrap(Double(p.output)),accuracy:3e-13) } }
    func testBoundariesAndPlan() throws { for x in [Double.nan,Double.infinity,-Double.infinity] { XCTAssertThrowsError(try DJIX3DLogTransfer.encodeLegacyToData(x)); XCTAssertThrowsError(try DJIX3DLogTransfer.decodeDataToLegacy(x)) }; let e=try DJIX3DLogTransfer.encodeLegacyToData(0.2/0.9); let s=TransformSettings(inputTransfer:.djiX3DLogLUTCalcLegacy,outputTransfer:.linearScene,inputSpace:.srgb,outputSpace:.srgb,inputRange:.data,outputRange:.data,exposureStops:0); XCTAssertEqual(try TransformPlan(settings:s).evaluate(RGB64(e,e,e)).r,0.2,accuracy:3e-13) }
    func testCatalogIdentity() throws { let c=try AlgorithmCatalog.builtIn(); XCTAssertEqual(c.transfer(named:"DJI X3 DLog (LUTCalc legacy)")?.id,.djiX3DLogLUTCalcLegacy); XCTAssertTrue(TransferID.djiX3DLogLUTCalcLegacy.hasNormalizedDataEncoding) }
}

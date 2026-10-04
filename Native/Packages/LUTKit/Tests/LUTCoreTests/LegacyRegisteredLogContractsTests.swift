import XCTest
@testable import LUTCore
import LUTCatalog

final class LegacyRegisteredLogContractsTests: XCTestCase {
    private struct Point: Decodable { let input: Double; let output: String }
    private struct Variant: Decodable { let params: [String]; let encode: [Point]; let decode: [Point] }
    private struct Reference: Decodable { let precision: Int; let sourceSHA256: String; let variants: [String: Variant] }
    private func reference() throws -> Reference { var root=URL(fileURLWithPath:#filePath); for _ in 0..<6 {root.deleteLastPathComponent()}; return try JSONDecoder().decode(Reference.self,from:Data(contentsOf:root.appendingPathComponent("tests/fixtures/native-contracts/legacy-registered-log-reference.json"))) }
    func testLegacyFormulasMatchJavaScript() throws {
        let ref=try reference(); XCTAssertEqual(ref.precision,64); XCTAssertFalse(ref.sourceSHA256.isEmpty)
        let cases:[(String,LegacyRegisteredLogTransfer.Variant)]=[("bolex",.bolex),("panalog",.panalog),("djiX5",.djiX5),("protune",.protune)]
        for (name,variant) in cases { let item=try XCTUnwrap(ref.variants[name]); for p in item.encode { if let expected=Double(p.output), expected.isFinite { XCTAssertEqual(try LegacyRegisteredLogTransfer.encodeLegacyToData(p.input,variant:variant),expected,accuracy:3e-15) } else { XCTAssertThrowsError(try LegacyRegisteredLogTransfer.encodeLegacyToData(p.input,variant:variant)) } }; for p in item.decode {XCTAssertEqual(try LegacyRegisteredLogTransfer.decodeDataToLegacy(p.input,variant:variant),try XCTUnwrap(Double(p.output)),accuracy:3e-14)} }
    }
    func testNonFiniteAndPlanBoundary() throws {
        for variant in [LegacyRegisteredLogTransfer.Variant.bolex,.panalog,.djiX5,.protune] { for x in [Double.nan,Double.infinity,-Double.infinity] {XCTAssertThrowsError(try LegacyRegisteredLogTransfer.encodeLegacyToData(x,variant:variant)); XCTAssertThrowsError(try LegacyRegisteredLogTransfer.decodeDataToLegacy(x,variant:variant))} }
        let encoded=try LegacyRegisteredLogTransfer.encodeLegacyToData(0.2/0.9,variant:.panalog)
        let settings=TransformSettings(inputTransfer:.panalogLUTCalcLegacy,outputTransfer:.linearScene,inputSpace:.srgb,outputSpace:.srgb,inputRange:.data,outputRange:.data,exposureStops:0)
        XCTAssertEqual(try TransformPlan(settings:settings).evaluate(RGB64(encoded,encoded,encoded)).r,0.2,accuracy:3e-14)
    }
    func testCatalogIdentities() throws { let c=try AlgorithmCatalog.builtIn(); XCTAssertEqual(c.transfer(named:"Bolex Log (LUTCalc legacy)")?.id,.bolexLogLUTCalcLegacy); XCTAssertEqual(c.transfer(named:"Panalog (LUTCalc legacy)")?.id,.panalogLUTCalcLegacy); XCTAssertEqual(c.transfer(named:"DJI X5/X7/X9 DLog (LUTCalc legacy)")?.id,.djiX5LogLUTCalcLegacy); XCTAssertEqual(c.transfer(named:"GoPro Protune (LUTCalc legacy)")?.id,.goProProtuneLUTCalcLegacy); XCTAssertTrue(TransferID.panalogLUTCalcLegacy.hasNormalizedDataEncoding); XCTAssertTrue(TransferID.goProProtuneLUTCalcLegacy.hasNormalizedDataEncoding) }
}

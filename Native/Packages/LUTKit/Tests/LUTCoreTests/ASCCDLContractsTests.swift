import Foundation
import XCTest
import LUTCore

final class ASCCDLContractsTests: XCTestCase {
    private func settings() throws -> ASCCDLSettings {
        try ASCCDLSettings(slope: RGB64(1.25,0.75,1.5), offset: RGB64(-0.125,0.0625,-0.25),
                           power: RGB64(2,1,2), saturation: 0.625)
    }
    private func plan(_ cdl: ASCCDLSettings?, exposure: Double = 0) throws -> TransformPlan {
        try TransformPlan(settings: TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,
            inputSpace:.sonySGamut3Cine,outputSpace:.sonySGamut3Cine,inputRange:.data,outputRange:.data,
            exposureStops:exposure,ascCDL:cdl))
    }
    // Independent rational reconstruction of the Y row from primary xy and D65.
    private let y = [0.21507582011558750019,0.88506850174372831753,-0.10014432185931581772]
    private func reference(_ p: RGB64, saturation: Bool = true, exposure: Double = 0) throws -> RGB64 {
        let gain = pow(2.0,exposure)
        let q = (0..<3).map { c -> Double in
            let slope = [1.25,0.75,1.5][c], offset = [-0.125,0.0625,-0.25][c]
            let v = p[c]*gain/0.9*slope+offset
            return v < 0 || c == 1 ? v : v*v
        }
        let l = zip(q,y).map(*).reduce(0,+)
        return try RGB64((saturation ? l+0.625*(q[0]-l) : q[0])*0.9,
                         (saturation ? l+0.625*(q[1]-l) : q[1])*0.9,
                         (saturation ? l+0.625*(q[2]-l) : q[2])*0.9)
    }
    func testLegacyForwardFixtureAndNegativeBranches() throws {
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let bytes = try Data(contentsOf:root.appendingPathComponent("tests/fixtures/native-contracts/asccdl-legacy-reference.json"))
        let fixture = try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        let cases = fixture["cases"] as! [[String:Any]]
        var maximum = 0.0
        for item in cases {
            let a = item["parameters"] as! [Double]
            let cdl = try ASCCDLSettings(slope:RGB64(a[0],a[1],a[2]),offset:RGB64(a[3],a[4],a[5]),
                power:RGB64(a[6],a[7],a[8]),saturation:a[9])
            let kernel = try LegacyASCCDL(settings:cdl)
            for probe in item["probes"] as! [[String:Any]] {
                let input=probe["input"] as! [Double], expected=probe["output"] as! [Double]
                let actual=try kernel.evaluateLegacy(RGB64(input[0],input[1],input[2]))
                let independent=try kernel.evaluateLegacy(RGB64(input[0],input[1],input[2]),applySaturation:false)
                let independentExpected=probe["independentOutput"] as! [Double]
                for c in 0..<3 {XCTAssertEqual(independent[c],independentExpected[c],accuracy:2e-12)}
                for c in 0..<3 {
                    let e=abs(actual[c]-expected[c])/max(1,abs(expected[c]))
                    maximum=max(maximum,e); XCTAssertLessThanOrEqual(e,2e-12)
                }
            }
        }
        print("ASC-CDL frozen legacy maximum scaled error \(maximum)")
        let kernel=try LegacyASCCDL(settings:settings())
        XCTAssertEqual(try kernel.evaluateLegacy(RGB64(0,0,0),applySaturation:false).r,-0.125)
        XCTAssertEqual(try kernel.evaluateLegacy(RGB64(0.1,0,0),applySaturation:false).r,0)
        XCTAssertEqual(try kernel.evaluateLegacy(RGB64(2,0,0),applySaturation:false).r,5.640625)
    }
    func testStageOrderScaleTraceAndIndependent1DSemantics() throws {
        let p=try RGB64(0.18,0.45,0.9), cdl=try settings()
        let transform=try plan(cdl,exposure:1)
        let trace=try transform.trace(p)
        XCTAssertEqual(trace.stages.map(\.id),[1,2,3,4,8,10,13,19])
        let stage=try XCTUnwrap(trace.stages.first{$0.id==8})
        XCTAssertEqual(stage.inputSpace,.sonySGamut3Cine)
        XCTAssertEqual(stage.outputSpace,.sonySGamut3Cine)
        XCTAssertEqual(stage.inputUnit,.sceneReflectance)
        let expected=try reference(p,exposure:1)
        for c in 0..<3 { XCTAssertEqual(trace.output[c],expected[c],accuracy:2e-12) }
        let independent=try transform.evaluateIndependentChannels(p)
        let independentExpected=try reference(p,saturation:false,exposure:1)
        for c in 0..<3 { XCTAssertEqual(independent[c],independentExpected[c],accuracy:2e-12) }
        XCTAssertNotEqual(independent,trace.output)
        let no=try plan(nil), off=try ASCCDLSettings(enabled:false)
        XCTAssertEqual(try plan(off).evaluate(p),try no.evaluate(p))
        XCTAssertEqual(try plan(off).trace(p).stages.map(\.id),[1,2,3,4,10,13,19])
        XCTAssertTrue(transform.planVersion.contains("asccdl"))
    }
    func testCrossGamutMatches70DigitDecimalReference() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let bytes=try Data(contentsOf:root.appendingPathComponent("tests/fixtures/native-contracts/asccdl-independent-reference.json"))
        let fixture=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        let cdl=try ASCCDLSettings(slope:RGB64(1.25,0.75,1.5),offset:RGB64(-0.125,0.0625,-0.25),
            power:RGB64(0.5,1.25,2.5),saturation:0.625)
        let plan=try TransformPlan(settings:TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,
            inputSpace:.rec2020,outputSpace:.rec2020,inputRange:.data,outputRange:.data,exposureStops:1,ascCDL:cdl))
        var maximum=0.0, maximumWrongOrderDifference=0.0
        for probe in fixture["probes"] as! [[String:Any]] {
            let p=probe["input"] as! [Double]
            let expected=(probe["output"] as! [String]).map{Double($0)!}
            let trace=try plan.trace(RGB64(p[0],p[1],p[2]))
            XCTAssertEqual(trace.stages.first{$0.id==3}?.outputSpace,.sonySGamut3Cine)
            let base=try RGB64(p[0]*2,p[1]*2,p[2]*2)
            let wrongOrder=try LegacyASCCDL(settings:cdl).evaluateScene(base)
            for c in 0..<3 {
                let error=abs(trace.output[c]-expected[c])/max(1,abs(expected[c]))
                maximum=max(maximum,error);XCTAssertLessThanOrEqual(error,2e-12)
                maximumWrongOrderDifference=max(maximumWrongOrderDifference,abs(trace.output[c]-wrongOrder[c]))
            }
        }
        XCTAssertGreaterThan(maximumWrongOrderDifference,1e-3)
        XCTAssertThrowsError(try TransformPlan(settings:plan.settings.withOutput(transfer:.linearScene,space:.acesAP0))
            .evaluateIndependentChannels(RGB64(0.1,0.2,0.3)))
        print("ASC-CDL cross-gamut 70-digit Decimal maximum scaled error \(maximum)")
    }

    func testFiniteValidationOverflowAndLegacyParameterDomains() throws {
        XCTAssertThrowsError(try ASCCDLSettings(saturation:.infinity))
        // Legacy numeric fields have no hard slider bounds: retain finite
        // negative slopes/saturation and zero/negative powers explicitly.
        let unusual=try ASCCDLSettings(slope:RGB64(-1,0,1),power:RGB64(0,-1,1),saturation:-1)
        XCTAssertThrowsError(try LegacyASCCDL(settings:unusual).evaluateLegacy(RGB64(0,0,0)))
        let overflow=try ASCCDLSettings(slope:RGB64(Double.greatestFiniteMagnitude,1,1))
        XCTAssertThrowsError(try plan(overflow).evaluate(RGB64(2,1,1),sampleIndex:73)) {
            guard case PlanError.numeric(stageID:8,sampleIndex:73) = $0 else { return XCTFail("\($0)") }
        }
        let nanJSON=Data("{\"enabled\":true,\"algorithm\":\"lutcalc.asccdl-working-linear.v1\",\"slope\":{\"r\":1,\"g\":1,\"b\":1},\"offset\":{\"r\":0,\"g\":0,\"b\":0},\"power\":{\"r\":1,\"g\":1,\"b\":1},\"saturation\":\"NaN\"}".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(ASCCDLSettings.self,from:nanJSON))
    }
    func testFull33And65GridsAgainstIndependentQuadraticFormula() throws {
        let transform=try plan(settings(),exposure:1)
        let domain=try LUTDomain(min:RGB64(-0.18,-0.18,-0.18),max:RGB64(1.8,1.8,1.8))
        var maximum=0.0
        for size in [33,65] {
            let grid=try Grid3D(size:size,domain:domain)
            for i in 0..<grid.nodeCount {
                let p=try grid.coordinate(at:i), expected=try reference(p,exposure:1)
                let actual=try transform.evaluate(p,sampleIndex:i)
                for c in 0..<3 {
                    let error=abs(actual[c]-expected[c])/max(1,abs(expected[c]))
                    maximum=max(maximum,error); XCTAssertLessThanOrEqual(error,2e-12)
                }
            }
        }
        print("ASC-CDL independent 33³/65³ maximum scaled error \(maximum)")
    }
}

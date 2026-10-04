import Foundation
import XCTest
import LUTCore

final class SDRSaturationContractsTests: XCTestCase {
    private let y = [0.2627002120112671, 0.6779980715188709, 0.05930171646986196]
    private func report(_ label: String, errors: [Double]) {
        let sorted=errors.sorted(), count=Double(errors.count)
        let rms=sqrt(errors.reduce(0){$0+$1*$1}/count)
        let p99=sorted[Int(ceil(count*0.99))-1]
        print("SDR Saturation \(label) scaled errors: count=\(errors.count), max=\(sorted.last!), RMS=\(rms), P99=\(p99)")
    }
    private func plan(_ sat: SDRSaturationSettings?, cdl: ASCCDLSettings? = nil,
                      output: TransferID = .linearScene) throws -> TransformPlan {
        try TransformPlan(settings: TransformSettings(inputTransfer: .linearScene, outputTransfer: output,
            inputSpace: .rec2020, outputSpace: .rec2020, inputRange: .data, outputRange: .data,
            exposureStops: 0, ascCDL: cdl, sdrSaturation: sat))
    }
    private func independentGamma2(_ p: RGB64) throws -> RGB64 {
        let q = (0..<3).map { p[$0] < 0 ? p[$0]/10.8 : sqrt(p[$0]/10.8) }
        let l = zip(y,q).map(*).reduce(0,+)
        guard l > 0 else { return p }
        // Pb/Pr terms cancel analytically; reconstructed RGB is q+(L^2-L).
        return try RGB64((q[0]+l*l-l)*10.8, (q[1]+l*l-l)*10.8, (q[2]+l*l-l)*10.8)
    }
    func testLegacyFixturesAndIndependentDecimalFractionalPowers() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        for name in ["sdr-saturation-legacy-reference.json", "sdr-saturation-independent-reference.json"] {
            let bytes=try Data(contentsOf:root.appendingPathComponent("tests/fixtures/native-contracts/\(name)"))
            let fixture=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
            var errors:[Double]=[]
            for item in fixture["cases"] as! [[String:Any]] {
                let sat=try SDRSaturationSettings(gamma:item["gamma"] as! Double)
                let kernel=try LegacySDRSaturation(settings:sat, outputPrimaries:.rec2020)
                for probe in item["probes"] as! [[String:Any]] {
                    let input=probe["input"] as! [Double]
                    let expected: [Double]
                    if let strings=probe["output"] as? [String] { expected=strings.map{Double($0)!} }
                    else { expected=probe["output"] as! [Double] }
                    let actual=try kernel.evaluateLegacy(RGB64(input[0],input[1],input[2]))
                    for c in 0..<3 {
                        let error=abs(actual[c]-expected[c])/max(1,abs(expected[c]))
                        errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
                    }
                }
            }
            report(name,errors:errors)
        }
    }
    func testStage11OrderCDLCombinationAndHLGEncoding() throws {
        let sat=try SDRSaturationSettings(gamma:2), cdl=try ASCCDLSettings(offset:RGB64(0.1,0.2,0.3))
        let p=try RGB64(0.2,0.4,0.8)
        let before=try plan(nil,cdl:cdl).evaluate(p)
        let expected=try independentGamma2(before)
        let t=try plan(sat,cdl:cdl).trace(p)
        XCTAssertEqual(t.stages.map(\.id),[1,2,3,4,8,10,11,13,19])
        let stage=try XCTUnwrap(t.stages.first{$0.id==11})
        XCTAssertEqual(stage.input,before)
        XCTAssertEqual(stage.inputSpace,.rec2020);XCTAssertEqual(stage.outputSpace,.rec2020)
        XCTAssertEqual(stage.inputUnit,.sceneReflectance)
        for c in 0..<3 {XCTAssertEqual(t.output[c],expected[c],accuracy:2e-12)}
        let hlg=try plan(sat,output:.rec2100HLG).evaluate(RGB64(0.6,0.7,0.8))
        let linear=try independentGamma2(RGB64(0.6,0.7,0.8))
        for c in 0..<3 {XCTAssertEqual(hlg[c],try HLGTransfer.encodeSceneToData(linear[c]),accuracy:2e-12)}
        XCTAssertTrue(try plan(sat).planVersion.contains("sdrsat"))
        XCTAssertThrowsError(try plan(sat).evaluateIndependentChannels(p))
        XCTAssertEqual(try plan(SDRSaturationSettings(enabled:false)).evaluate(p),p)
    }
    func testNoClampNegativeBranchNonPositiveLumaAndValidation() throws {
        for gamma in [0.0,0.99,2.01,Double.infinity,Double.nan] {
            XCTAssertThrowsError(try SDRSaturationSettings(gamma:gamma))
        }
        let sat=try SDRSaturationSettings(gamma:2)
        let kernel=try LegacySDRSaturation(settings:sat,outputPrimaries:.rec2020)
        let negative=try RGB64(-1,-2,-3)
        XCTAssertEqual(try kernel.evaluateScene(negative),negative)
        XCTAssertEqual(try kernel.evaluateScene(RGB64(0,0,0)),try RGB64(0,0,0))
        let mixed=try kernel.evaluateScene(RGB64(0,1,0))
        XCTAssertLessThan(mixed.r,0);XCTAssertLessThan(mixed.b,0)
        let hdr=try RGB64(21.6,21.6,21.6)
        let result=try kernel.evaluateScene(hdr)
        for c in 0..<3 {XCTAssertEqual(result[c],hdr[c],accuracy:2e-12)}
        // Positive cone inputs whose luminance power overflows fail at stage 11.
        XCTAssertThrowsError(try plan(sat).evaluate(RGB64(Double.greatestFiniteMagnitude,
            Double.greatestFiniteMagnitude,Double.greatestFiniteMagnitude),sampleIndex:17)) {
            XCTAssertEqual($0 as? PlanError,.numeric(stageID:11,sampleIndex:17))
        }
    }
    func testFull33And65GridsAgainstIndependentQuadraticLuminance() throws {
        let transform=try plan(SDRSaturationSettings(gamma:2))
        let domain=try LUTDomain(min:RGB64(-0.5,-0.5,-0.5),max:RGB64(21.6,21.6,21.6))
        var errors:[Double]=[]
        for size in [33,65] {
            let grid=try Grid3D(size:size,domain:domain)
            for i in 0..<grid.nodeCount {
                let p=try grid.coordinate(at:i), expected=try independentGamma2(p)
                let actual=try transform.evaluate(p,sampleIndex:i)
                for c in 0..<3 {
                    let error=abs(actual[c]-expected[c])/max(1,abs(expected[c]))
                    errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
                }
            }
        }
        report("independent 33³/65³",errors:errors)
    }
    func testFullLegacyDecodeGamutExposureCDLSDRPipeline() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let bytes=try Data(contentsOf:root.appendingPathComponent("tests/fixtures/native-contracts/sdr-saturation-legacy-pipeline17.f64"))
        let cdl=try ASCCDLSettings(slope:RGB64(1.25,0.75,1.5),offset:RGB64(-0.125,0.0625,-0.25),
            power:RGB64(0.5,1.25,2.5),saturation:0.625)
        let settings=TransformSettings(inputTransfer:.djiDLog2,outputTransfer:.linearScene,
            inputSpace:.djiDGamut2,outputSpace:.rec2020,inputRange:.data,outputRange:.data,
            exposureStops:1,ascCDL:cdl,sdrSaturation:try SDRSaturationSettings())
        let grid=try Grid3D(size:17,domain:.unit), plan=try TransformPlan(settings:settings)
        XCTAssertEqual(bytes.count,grid.nodeCount*3*8)
        var errors:[Double]=[]
        for i in 0..<grid.nodeCount {
            let actual=try plan.evaluate(grid.coordinate(at:i),sampleIndex:i)
            for c in 0..<3 {
                let bits=bytes.withUnsafeBytes{$0.loadUnaligned(fromByteOffset:(i*3+c)*8,as:UInt64.self)}
                let expected=Double(bitPattern:UInt64(littleEndian:bits))
                let error=abs(actual[c]-expected)/max(1,abs(expected))
                errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
            }
        }
        report("legacy decode/gamut/exposure/CDL/SDR 17³",errors:errors)
    }
}

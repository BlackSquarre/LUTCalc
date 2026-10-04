import Foundation
import XCTest
import LUTCore

final class MultitoneContractsTests: XCTestCase {
    private func root() -> URL {
        URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    func testLegacyAndIndependentDecimalFixtures() throws {
        for name in ["multitone-legacy-reference.json","multitone-independent-reference.json"] {
            let fixture=try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/\(name)"))) as! [String:Any]
            var errors:[Double]=[]
            for item in fixture["cases"] as! [[String:Any]] {
                let tones=try (item["tones"] as! [[String:Any]]).map {
                    try MultitoneTone(stop:$0["stop"] as! Double,hue:UInt8($0["hue"] as! Int),saturation:UInt8($0["saturation"] as! Int))
                }
                let setting=try MultitoneSettings(saturationByStop:item["saturationByStop"] as! [Double],tones:tones)
                let kernel=try LegacyMultitone(settings:setting,outputPrimaries:.rec2020)
                for probe in item["probes"] as! [[String:Any]] {
                    let p=probe["input"] as! [Double]
                    let expected=(probe["output"] as? [String])?.map{Double($0)!} ?? probe["output"] as! [Double]
                    let actual=try kernel.evaluateLegacy(RGB64(p[0],p[1],p[2]))
                    for c in 0..<3 {
                        let e=abs(actual[c]-expected[c])/max(1,abs(expected[c]))
                        errors.append(e);XCTAssertLessThanOrEqual(e,2e-12)
                    }
                }
            }
            report(name,errors:errors)
        }
    }
    private func report(_ name:String,errors:[Double]) {
        let sorted=errors.sorted(), n=Double(errors.count)
        print("Multitone \(name) scaled errors: count=\(errors.count), max=\(sorted.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/n)), P99=\(sorted[Int(ceil(n*0.99))-1])")
    }
    func testFullGridsIndependentSaturationByStopNegativeAndHDR() throws {
        let saturation=(0..<17).map{Double($0)/8}
        let settings=try MultitoneSettings(saturationByStop:saturation,tones:[])
        let plan=try TransformPlan(settings:TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,
            inputSpace:.sonySGamut3Cine,outputSpace:.sonySGamut3Cine,inputRange:.data,outputRange:.data,
            exposureStops:0,multitone:settings))
        let domain=try LUTDomain(min:RGB64(-0.18,-0.18,-0.18),max:RGB64(46.08,46.08,46.08))
        var errors:[Double]=[]
        for size in [33,65] {
            let grid=try Grid3D(size:size,domain:domain)
            let reference=try Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/multitone-independent-grid\(size).f64"))
            XCTAssertEqual(reference.count,grid.nodeCount*3*8)
            let metadata=try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/multitone-independent-grid.json"))) as! [String:Any]
            let item=(metadata["grids"] as! [[String:Any]]).first{$0["size"] as? Int==size}!
            let axis=item["axisDoubleBits"] as! [String]
            for r in 0..<size {
                let p=try grid.coordinate(at:r)
                XCTAssertEqual(p.r.bitPattern,UInt64(axis[r],radix:16)!.byteSwapped)
            }
            for i in 0..<grid.nodeCount {
                let p=try grid.coordinate(at:i)
                let actual=try plan.evaluate(p,sampleIndex:i)
                for c in 0..<3 {
                    let bits=reference.withUnsafeBytes{$0.loadUnaligned(fromByteOffset:(i*3+c)*8,as:UInt64.self)}
                    let expected=Double(bitPattern:UInt64(littleEndian:bits))
                    let e=abs(actual[c]-expected)/max(1,abs(expected))
                    if e>2e-12 {print("Multitone Decimal failing grid=\(size) index=\(i) channel=\(c) p=\(p) actual=\(actual[c]) expected=\(expected)")}
                    errors.append(e);XCTAssertLessThanOrEqual(e,2e-12)
                }
            }
        }
        report("independent 33³/65³ saturation",errors:errors)
    }
    func testStage9OrderIndependent1DRejectionAndParameterDomains() throws {
        let tone=try MultitoneTone(stop:0,hue:17,saturation:245)
        let mt=try MultitoneSettings(saturationByStop:Array(repeating:0.5,count:17),tones:[tone])
        let cdl=try ASCCDLSettings(offset:RGB64(0.1,0.2,0.3))
        let settings=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,
            outputSpace:.rec2020,inputRange:.data,outputRange:.data,exposureStops:0,ascCDL:cdl,multitone:mt)
        let plan=try TransformPlan(settings:settings), trace=try plan.trace(RGB64(0.3,0.4,0.6))
        XCTAssertEqual(trace.stages.map(\.id),[1,2,3,4,8,9,10,13,19])
        XCTAssertEqual(trace.stages.first{$0.id==9}?.inputSpace,.sonySGamut3Cine)
        XCTAssertEqual(trace.stages.first{$0.id==9}?.inputUnit,.sceneReflectance)
        XCTAssertTrue(plan.planVersion.contains("multitone"))
        XCTAssertThrowsError(try plan.evaluateIndependentChannels(RGB64(0.1,0.2,0.3)))
        for count in [0,16,18] {XCTAssertThrowsError(try MultitoneSettings(saturationByStop:Array(repeating:1,count:count)))}
        for sat in [-0.01,2.01,Double.nan,Double.infinity] {
            XCTAssertThrowsError(try MultitoneSettings(saturationByStop:Array(repeating:sat,count:17)))
        }
        XCTAssertThrowsError(try MultitoneTone(stop:.infinity,hue:0,saturation:0))
        XCTAssertThrowsError(try MultitoneSettings(tones:[tone,tone]))
        // Tone stops have no hard numeric slider bound; finite ordered values remain valid.
        XCTAssertNoThrow(try MultitoneSettings(tones:[MultitoneTone(stop:-100,hue:0,saturation:0),MultitoneTone(stop:100,hue:255,saturation:255)]))
        let off=try MultitoneSettings(enabled:false)
        let neutral=try TransformPlan(settings:settings.withASCCDL(nil).withMultitone(off))
        XCTAssertEqual(try neutral.evaluate(RGB64(0.1,0.2,0.3)),try RGB64(0.1,0.2,0.3))
    }
    func testActualLegacyCDLMultitoneSDRPipeline17() throws {
        let bytes=try Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/multitone-legacy-pipeline17.f64"))
        let mt=try MultitoneSettings(saturationByStop:(0..<17).map{0.15+Double($0%5)*0.35},
            tones:[MultitoneTone(stop:-3,hue:17,saturation:245),MultitoneTone(stop:0,hue:101,saturation:187),MultitoneTone(stop:4,hue:231,saturation:213)])
        let cdl=try ASCCDLSettings(slope:RGB64(1.25,0.75,1.5),offset:RGB64(-0.125,0.0625,-0.25),
            power:RGB64(0.5,1.25,2.5),saturation:0.625)
        let plan=try TransformPlan(settings:TransformSettings(inputTransfer:.djiDLog2,outputTransfer:.linearScene,
            inputSpace:.djiDGamut2,outputSpace:.rec2020,inputRange:.data,outputRange:.data,exposureStops:1,
            ascCDL:cdl,sdrSaturation:try SDRSaturationSettings(),multitone:mt))
        let grid=try Grid3D(size:17,domain:.unit);XCTAssertEqual(bytes.count,grid.nodeCount*3*8)
        var errors:[Double]=[]
        for i in 0..<grid.nodeCount {
            let actual=try plan.evaluate(grid.coordinate(at:i),sampleIndex:i)
            for c in 0..<3 {
                let bits=bytes.withUnsafeBytes{$0.loadUnaligned(fromByteOffset:(i*3+c)*8,as:UInt64.self)}
                let expected=Double(bitPattern:UInt64(littleEndian:bits))
                let e=abs(actual[c]-expected)/max(1,abs(expected));errors.append(e);XCTAssertLessThanOrEqual(e,2e-12)
            }
        }
        report("legacy decode/CDL/Multitone/SDR 17³",errors:errors)
    }
}

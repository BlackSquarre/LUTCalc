import Foundation
import XCTest
import LUTCore

final class GamutLimiterContractsTests:XCTestCase {
    private func root()->URL {
        URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private func report(_ name:String,_ errors:[Double]) {
        let sorted=errors.sorted(),n=Double(errors.count)
        print("Gamut Limiter \(name) scaled errors: count=\(errors.count), max=\(sorted.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/n)), P99=\(sorted[Int(ceil(0.99*n))-1])")
    }
    func testActualLegacyTwoStageAndEncodedBranches() throws {
        let f=try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/gamut-limiter-legacy-reference.json"))) as! [String:Any]
        var errors:[Double]=[]
        for item in f["cases"] as! [[String:Any]] {
            let base:ColorSpaceID=item["base"] as! String == "Rec2020" ? .rec2020 : .srgb
            let name=item["secondary"] as? String
            let secondary:ColorSpaceID?=name.map{$0 == "Rec2020" ? .rec2020 : .srgb}
            let linear=item["linear"] as! Bool
            let s=try GamutLimiterSettings(mode:linear ? .linear : .postGamma,linearStops:-1,postLevel:0.85,
                secondarySpace:secondary,protectBoth:item["both"] as! Bool)
            let k=try LegacyGamutLimiter(settings:s,outputSpace:base,adaptation:.cieCAT02)
            let y=(item["luma"] as! [String]).map{Double($0)!}
            for c in 0..<3{XCTAssertEqual(k.luma[c],y[c],accuracy:2e-12)}
            func encode(_ p:RGB64)throws->RGB64 {
                try RGB64(Rec709Transfer.encodeLegacy(p.r),Rec709Transfer.encodeLegacy(p.g),Rec709Transfer.encodeLegacy(p.b))
            }
            for probe in item["probes"] as! [[String:Any]] {
                let x=(probe["input"] as! [String]).map{Double($0)!},expected=(probe["output"] as! [String]).map{Double($0)!}
                let input=try RGB64(x[0],x[1],x[2]),actual:RGB64
                if linear{actual=try k.evaluateLinearLegacy(input)}
                else{
                    let secondary=try k.secondaryLegacy(input).map{try encode($0)}
                    actual=try k.evaluateEncodedLegal(encode(input),secondary:secondary)
                }
                for c in 0..<3 {
                    let error=abs(actual[c]-expected[c])/max(1,abs(expected[c]))
                    errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
                }
                if !linear,let values=probe["secondary12"] as? [String] {
                    let prepared=try XCTUnwrap(k.secondaryLegacy(input))
                    for c in 0..<3{XCTAssertEqual(prepared[c],Double(values[c])!,accuracy:2e-12)}
                }
            }
        }
        for item in f["encoded"] as! [[String:Any]] {
            let a=item["primary"] as! [Double],b=item["secondary"] as? [Double]
            let s=try GamutLimiterSettings(postLevel:item["level"] as! Double,secondarySpace:b == nil ? nil : .srgb,protectBoth:item["both"] as! Bool)
            let k=try LegacyGamutLimiter(settings:s,outputSpace:.rec2020,adaptation:.cieCAT02)
            let actual=try k.evaluateEncodedLegal(RGB64(a[0],a[1],a[2]),secondary:b.map{try RGB64($0[0],$0[1],$0[2])})
            let y=(item["output"] as! [String]).map{Double($0)!}
            for c in 0..<3{let error=abs(actual[c]-y[c])/max(1,abs(y[c]));errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)}
        }
        report("actual legacy",errors)
    }
    func testParametersStage12And17PayloadUnitsAndFailure() throws {
        for x in [-6.1,6.1,Double.nan,Double.infinity]{XCTAssertThrowsError(try GamutLimiterSettings(linearStops:x))}
        for x in [0,0.009,1.091,Double.nan,Double.infinity]{XCTAssertThrowsError(try GamutLimiterSettings(postLevel:x))}
        let p=try RGB64(-0.25,2,0.5)
        for mode in [GamutLimiterMode.linear,.postGamma] {
            let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,outputSpace:.rec2020,
                inputRange:.data,outputRange:.data,exposureStops:0,gamutLimiter:try GamutLimiterSettings(mode:mode))
            let plan=try TransformPlan(settings:s),trace=try plan.trace(p)
            XCTAssertEqual(trace.stages.map(\.id),mode == .linear ? [1,2,3,4,10,12,13,19] : [1,2,3,4,10,12,13,17,19])
            XCTAssertGreaterThanOrEqual(trace.output.r,0)
            XCTAssertTrue(plan.planVersion.contains("gamut-limiter"))
            XCTAssertThrowsError(try plan.evaluateIndependentChannels(p))
        }
        let post=try GamutLimiterSettings(postLevel:0.85,secondarySpace:.srgb,protectBoth:true)
        let k=try LegacyGamutLimiter(settings:post,outputSpace:.rec2020,adaptation:.cieCAT02)
        XCTAssertThrowsError(try k.evaluateEncodedLegal(p,secondary:nil))
        let disabled=try LegacyGamutLimiter(settings:GamutLimiterSettings(enabled:false),outputSpace:.rec2020,adaptation:.cieCAT02)
        XCTAssertEqual(try disabled.evaluateEncodedLegal(p,secondary:nil),p)
        XCTAssertEqual(try disabled.evaluateLinearLegacy(p),p)
        let baseline=TransformSettings(inputTransfer:.linearScene,outputTransfer:.djiDLog2,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0)
        let encoded=try TransformPlan(settings:baseline).evaluate(p),scale=876.0/1023,offset=64.0/1023
        let primaryLegal=try RGB64((encoded.r-offset)/scale,(encoded.g-offset)/scale,(encoded.b-offset)/scale)
        let simple=try LegacyGamutLimiter(settings:GamutLimiterSettings(postLevel:0.85),outputSpace:.rec2020,adaptation:.cieCAT02)
        let limited=try simple.evaluateEncodedLegal(primaryLegal,secondary:nil)
        let actual=try TransformPlan(settings:baseline.withGamutLimiter(GamutLimiterSettings(postLevel:0.85))).evaluate(p)
        for c in 0..<3{XCTAssertEqual(actual[c],limited[c]*scale+offset,accuracy:2e-12)}
    }
    func testIndependentDecimalAndFullLinearPostGrids() throws {
        let f=try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/gamut-limiter-independent-reference.json"))) as! [String:Any]
        var errors:[Double]=[]
        for item in f["cases"] as! [[String:Any]] {
            let base=ColorSpaceID(rawValue:item["base"] as! String)!,secondary=(item["secondary"] as? String).flatMap{ColorSpaceID(rawValue:$0)}
            let linear=item["linear"] as! Bool
            let k=try LegacyGamutLimiter(settings:GamutLimiterSettings(mode:linear ? .linear : .postGamma,linearStops:-1,postLevel:0.85,
                secondarySpace:secondary,protectBoth:item["both"] as! Bool),outputSpace:base,adaptation:.cieCAT02)
            func encode(_ x:RGB64)throws->RGB64{try RGB64(Rec709Transfer.encodeLegacy(x.r),Rec709Transfer.encodeLegacy(x.g),Rec709Transfer.encodeLegacy(x.b))}
            for probe in item["probes"] as! [[String:Any]] {
                let x=(probe["input"] as! [String]).map{Double($0)!},expected=(probe["output"] as! [String]).map{Double($0)!}
                let p=try RGB64(x[0],x[1],x[2]),actual:RGB64
                if linear{actual=try k.evaluateLinearLegacy(p)}
                else{actual=try k.evaluateEncodedLegal(encode(p),secondary:k.secondaryLegacy(p).map{try encode($0)})}
                for c in 0..<3{let error=abs(actual[c]-expected[c])/max(1,abs(expected[c]));errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)}
            }
        }
        report("independent Decimal",errors);errors=[]
        for fixture in f["grids"] as! [[String:Any]] {
            let linear=fixture["linear"] as! Bool,size=fixture["size"] as! Int
            let limiter=try GamutLimiterSettings(mode:linear ? .linear : .postGamma,linearStops:-1,postLevel:0.85,secondarySpace:.srgb)
            let settings=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,outputSpace:.rec2020,
                inputRange:.data,outputRange:.data,exposureStops:0,gamutLimiter:limiter)
            let plan=try TransformPlan(settings:settings),grid=try Grid3D(size:size,domain:LUTDomain(min:RGB64(-0.5,-0.5,-0.5),max:RGB64(2,2,2)))
            let bytes=try Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/\(fixture["file"] as! String)"))
            XCTAssertEqual(bytes.count,grid.nodeCount*3*8)
            for i in 0..<grid.nodeCount {
                let actual=try plan.evaluate(grid.coordinate(at:i),sampleIndex:i)
                for c in 0..<3 {
                    let bits=bytes.withUnsafeBytes{$0.loadUnaligned(fromByteOffset:(i*3+c)*8,as:UInt64.self)}
                    let expected=Double(bitPattern:UInt64(littleEndian:bits)),error=abs(actual[c]-expected)/max(1,abs(expected))
                    errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
                }
            }
        }
        report("independent linear/post 33³/65³",errors)
    }
    func testActualLegacyCombinedChain17() throws {
        for linear in [true,false] {
        let bytes=try Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/gamut-limiter-legacy-pipeline17-\(linear ? "linear" : "post").f64"))
        let cdl=try ASCCDLSettings(slope:RGB64(1.25,0.75,1.5),offset:RGB64(-0.125,0.0625,-0.25),power:RGB64(0.5,1.25,2.5),saturation:0.625)
        let mt=try MultitoneSettings(saturationByStop:(0..<17).map{0.15+Double($0%5)*0.35},tones:[
            MultitoneTone(stop:-3,hue:17,saturation:245),MultitoneTone(stop:0,hue:101,saturation:187),MultitoneTone(stop:4,hue:231,saturation:213)])
        let s=TransformSettings(inputTransfer:.djiDLog2,outputTransfer:.djiDLog2,inputSpace:.djiDGamut2,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:1,ascCDL:cdl,sdrSaturation:try SDRSaturationSettings(),multitone:mt,
            blackGamma:try BlackGammaSettings(upperStops:0,featherStops:2,power:0.5),
            blackHighlight:try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.025,blackLock:true,highReferenceScene:0.72,highMap:0.91,highLock:true),knee:try KneeSettings(startStops:-2,clipStops:4,clipSlope:1,smoothness:0.35,legal:false),highlightGamut:try HighlightGamutSettings(highlightSpace:.srgb,transition:.logarithmicStops,lowStops:-1,highStops:3),gamutLimiter:try GamutLimiterSettings(mode:linear ? .linear : .postGamma,linearStops:-1,postLevel:0.85,secondarySpace:.srgb))
        let plan=try TransformPlan(settings:s),grid=try Grid3D(size:17,domain:.unit)
        XCTAssertEqual(bytes.count,grid.nodeCount*3*8)
        var errors:[Double]=[]
        for i in 0..<grid.nodeCount {
            let actual=try plan.evaluate(grid.coordinate(at:i),sampleIndex:i)
            for c in 0..<3 {
                let bits=bytes.withUnsafeBytes{$0.loadUnaligned(fromByteOffset:(i*3+c)*8,as:UInt64.self)}
                let expected=Double(bitPattern:UInt64(littleEndian:bits)),error=abs(actual[c]-expected)/max(1,abs(expected))
                errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
            }
        }
        report("legacy \(linear ? "linear" : "post") combined chain 17³",errors)
        }
    }
}

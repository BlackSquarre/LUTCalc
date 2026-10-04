import Foundation
import XCTest
@testable import LUTCore

final class DisplayConversionContractsTests:XCTestCase {
    private func root()->URL {URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()}
    private func fixture(_ name:String)throws->[String:Any] {
        try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/\(name)"))) as! [String:Any]
    }
    private func report(_ name:String,_ errors:[Double]) {
        let a=errors.sorted(),n=Double(a.count)
        print("Display Conversion \(name) scaled errors: count=\(a.count), max=\(a.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/n)), P99=\(a[Int(ceil(0.99*n))-1])")
    }
    func testLegacyAllSDRCurvesMatricesAnd1DPath() throws {
        XCTAssertEqual(DisplayCurve.allCases.count,23);XCTAssertEqual(DisplayGamut.allCases.count,7)
        let f=try fixture("display-conversion-legacy-reference.json");var errors:[Double]=[]
        for item in f["cases"] as! [[String:Any]] {
            let s=DisplayConversionSettings(baseCurve:DisplayCurve(rawValue:item["baseCurve"] as! String)!,outputCurve:DisplayCurve(rawValue:item["outputCurve"] as! String)!,
                baseGamut:DisplayGamut(rawValue:item["baseGamut"] as! String)!,outputGamut:DisplayGamut(rawValue:item["outputGamut"] as! String)!)
            let k=try LegacyDisplayConversion(settings:s),oneD=item["oneD"] as! Bool
            for probe in item["probes"] as! [[String:Any]] {
                let x=(probe["input"] as! [String]).map{Double($0)!},y=(probe["output"] as! [String]).map{Double($0)!}
                let actual=try k.evaluateLegal(RGB64(x[0],x[1],x[2]),independentChannels:oneD)
                for c in 0..<3{let e=abs(actual[c]-y[c])/max(1,abs(y[c]));errors.append(e);XCTAssertLessThanOrEqual(e,2e-12,"\(item["baseCurve"]!)/\(item["outputCurve"]!)")}
            }
        }
        report("actual legacy 23 curves/49 matrices",errors)
    }
    func testStage16UnitsMetadataIndependentAndOverflow() throws {
        let display=DisplayConversionSettings(baseCurve:.sceneReflectance,outputCurve:.sceneIRE,baseGamut:.rec2020,outputGamut:.p3DCI)
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,outputSpace:.rec2020,inputRange:.data,outputRange:.data,exposureStops:0,displayConversion:display)
        let plan=try TransformPlan(settings:s),p=try RGB64(-0.1,0.2,0.8),trace=try plan.trace(p)
        XCTAssertEqual(trace.stages.map(\.id),[1,2,3,4,10,13,16,19])
        let st=try XCTUnwrap(trace.stages.first{$0.id==16})
        XCTAssertEqual(st.inputDisplayGamut,.rec2020);XCTAssertEqual(st.outputDisplayGamut,.p3DCI)
        XCTAssertNil(st.outputSpace);XCTAssertEqual(trace.stages.last?.outputDisplayGamut,.p3DCI)
        XCTAssertEqual(try plan.evaluateIndependentChannels(p).r,p.r/0.9,accuracy:2e-12)
        XCTAssertEqual(try plan.evaluateIndependentChannels(p).g,p.g/0.9,accuracy:2e-12)
        XCTAssertNotEqual(trace.output,try plan.evaluateIndependentChannels(p))
        let off=try TransformPlan(settings:s.withDisplayConversion(DisplayConversionSettings(enabled:false)))
        XCTAssertEqual(try off.evaluate(p),p)
        let data=TransformSettings(inputTransfer:.linearScene,outputTransfer:.djiDLog2,inputSpace:.rec2020,outputSpace:.rec2020,inputRange:.data,outputRange:.data,exposureStops:0,displayConversion:DisplayConversionSettings(baseCurve:.rec709,outputCurve:.gamma22))
        let plain=try TransformPlan(settings:data.withDisplayConversion(nil)).evaluate(p),scale=876.0/1023,offset=64.0/1023
        let k=try LegacyDisplayConversion(settings:data.displayConversion!)
        let expected=try k.evaluateLegal(RGB64((plain.r-offset)/scale,(plain.g-offset)/scale,(plain.b-offset)/scale))
        let actual=try TransformPlan(settings:data).evaluate(p)
        for c in 0..<3{XCTAssertEqual(actual[c],expected[c]*scale+offset,accuracy:2e-12)}
        XCTAssertTrue(plan.planVersion.contains(display.algorithm.rawValue))
        let extreme=s.withDisplayConversion(DisplayConversionSettings(baseCurve:.gamma26,outputCurve:.sceneIRE))
        XCTAssertThrowsError(try TransformPlan(settings:extreme).evaluate(RGB64(1e200,1e200,1e200),sampleIndex:17)) {
            XCTAssertEqual($0 as? PlanError,.numeric(stageID:16,sampleIndex:17))
        }
    }
    func testIndependentDecimalAndComplete33And65Grids() throws {
        let f=try fixture("display-conversion-independent-reference.json");var errors:[Double]=[]
        for item in f["cases"] as! [[String:Any]] {
            let settings=try JSONDecoder().decode(DisplayConversionSettings.self,from:JSONSerialization.data(withJSONObject:item["settings"]!))
            let kernel=try LegacyDisplayConversion(settings:settings)
            for probe in item["probes"] as! [[String:Any]] {
                let x=(probe["input"] as! [String]).map{Double($0)!},y=(probe["output"] as! [String]).map{Double($0)!}
                let actual=try kernel.evaluateLegal(RGB64(x[0],x[1],x[2]),independentChannels:item["oneD"] as! Bool)
                for c in 0..<3{let e=abs(actual[c]-y[c])/max(1,abs(y[c]));errors.append(e);XCTAssertLessThanOrEqual(e,2e-12)}
            }
        }
        report("independent Decimal",errors);errors=[]
        for item in f["grids"] as! [[String:Any]] {
            let settings=try JSONDecoder().decode(DisplayConversionSettings.self,from:JSONSerialization.data(withJSONObject:item["settings"]!))
            let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,outputSpace:.rec2020,inputRange:.data,outputRange:.data,exposureStops:0,displayConversion:settings)
            let plan=try TransformPlan(settings:s),grid=try Grid3D(size:item["size"] as! Int,domain:LUTDomain(min:RGB64(-0.5,-0.5,-0.5),max:RGB64(2,2,2)))
            let bytes=try Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/\(item["file"]!)"))
            XCTAssertEqual(bytes.count,grid.nodeCount*3*8)
            for i in 0..<grid.nodeCount {
                let actual=try plan.evaluate(grid.coordinate(at:i))
                for c in 0..<3{let bits=bytes.withUnsafeBytes{$0.loadUnaligned(fromByteOffset:(i*3+c)*8,as:UInt64.self)},y=Double(bitPattern:UInt64(littleEndian:bits)),e=abs(actual[c]-y)/max(1,abs(y));errors.append(e);XCTAssertLessThanOrEqual(e,2e-12)}
            }
        }
        report("independent two matrix pairs 33³/65³",errors)
    }
    func testActualLegacyCombinedChain17() throws {
        for linear in [true,false] {
        let bytes=try Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/display-conversion-legacy-pipeline17-\(linear ? "linear" : "post").f64"))
        let cdl=try ASCCDLSettings(slope:RGB64(1.25,0.75,1.5),offset:RGB64(-0.125,0.0625,-0.25),power:RGB64(0.5,1.25,2.5),saturation:0.625)
        let mt=try MultitoneSettings(saturationByStop:(0..<17).map{0.15+Double($0%5)*0.35},tones:[
            MultitoneTone(stop:-3,hue:17,saturation:245),MultitoneTone(stop:0,hue:101,saturation:187),MultitoneTone(stop:4,hue:231,saturation:213)])
        let s=TransformSettings(inputTransfer:.djiDLog2,outputTransfer:.djiDLog2,inputSpace:.djiDGamut2,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:1,ascCDL:cdl,sdrSaturation:try SDRSaturationSettings(),multitone:mt,
            blackGamma:try BlackGammaSettings(upperStops:0,featherStops:2,power:0.5),
            blackHighlight:try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.025,blackLock:true,highReferenceScene:0.72,highMap:0.91,highLock:true),knee:try KneeSettings(startStops:-2,clipStops:4,clipSlope:1,smoothness:0.35,legal:false),highlightGamut:try HighlightGamutSettings(highlightSpace:.srgb,transition:.logarithmicStops,lowStops:-1,highStops:3),gamutLimiter:try GamutLimiterSettings(mode:linear ? .linear : .postGamma,linearStops:-1,postLevel:0.85,secondarySpace:.srgb),displayConversion:DisplayConversionSettings(baseCurve:.rec709,outputCurve:.srgb,baseGamut:.rec2020,outputGamut:.p3D60))
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

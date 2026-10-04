import Foundation
import XCTest
import LUTCore

final class FinalOutputContractsTests:XCTestCase {
    private func root()->URL {URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()}
    func testActualLegacyModesFormatBoundsHDRAndReversedLimits() throws {
        let f=try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/final-output-legacy-reference.json"))) as! [String:Any]
        var errors:[Double]=[]
        for item in f["cases"] as! [[String:Any]] {
            let settings=try JSONDecoder().decode(FinalOutputSettings.self,from:JSONSerialization.data(withJSONObject:item["settings"]!))
            let k=try LegacyFinalOutput(settings:settings,outputRange:SignalNormalization(rawValue:item["outputRange"] as! String)!,
                hdrOutputActive:item["hdrOutputActive"] as! Bool,hdrMaximumLegal:item["hdrMaximumLegal"] as? Double,
                displayConversionActive:item["displayConversionActive"] as! Bool)
            let x=(item["input"] as! [String]).map{Double($0)!},y=(item["output"] as! [String]).map{Double($0)!}
            for i in x.indices{let a=try k.evaluateLegal(x[i]),e=abs(a-y[i])/max(1,abs(y[i]));errors.append(e);XCTAssertLessThanOrEqual(e,2e-12)}
        }
        let a=errors.sorted(),n=Double(a.count)
        print("Final Output legacy scaled errors: count=\(a.count), max=\(a.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/n)), P99=\(a[Int(ceil(0.99*n))-1])")
    }
    func testSettingsStage19IdentityHDRDependencyAndFailure() throws {
        for v in [Double.nan,Double.infinity]{XCTAssertThrowsError(try FinalOutputSettings(minimumCode10:v));XCTAssertThrowsError(try FinalOutputSettings(maximumCode10:v))}
        let settings=try FinalOutputSettings(mode:.both,clipLegal:true,minimumCode10:-1023,maximumCode10:67025937)
        let data=try LegacyFinalOutput(settings:settings,outputRange:.data),video=try LegacyFinalOutput(settings:settings,outputRange:.video)
        XCTAssertEqual(try data.evaluateLegal(-1),64.0/1023);XCTAssertEqual(try data.evaluateLegal(2),959.0/1023)
        XCTAssertEqual(try video.evaluateLegal(-1),0);XCTAssertEqual(try video.evaluateLegal(2),1)
        XCTAssertThrowsError(try LegacyFinalOutput(settings:settings,outputRange:.data,hdrOutputActive:true))
        XCTAssertNoThrow(try LegacyFinalOutput(settings:settings,outputRange:.data,hdrOutputActive:true,displayConversionActive:true))
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.gamma22,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,finalOutput:settings)
        let plan=try TransformPlan(settings:s),p=try RGB64(-1,0,16),trace=try plan.trace(p)
        XCTAssertEqual(trace.stages.last?.id,19);XCTAssertEqual(trace.output.r,64.0/1023);XCTAssertEqual(trace.output.b,959.0/1023)
        XCTAssertEqual(try plan.evaluateIndependentChannels(p),trace.output)
        XCTAssertTrue(plan.planVersion.contains(settings.algorithm.rawValue))
        let base=s.withFinalOutput(nil),disabled=s.withFinalOutput(try FinalOutputSettings(enabled:false))
        XCTAssertEqual(try TransformPlan(settings:base).evaluate(p),try TransformPlan(settings:disabled).evaluate(p))
        XCTAssertThrowsError(try TransformPlan(settings:s.withOutput(transfer:.rec2100PQ,space:.rec2020))) {
            XCTAssertEqual($0 as? FinalOutputError,.hdrLimitUnavailable)
        }
        XCTAssertThrowsError(try data.evaluateLegal(Double.greatestFiniteMagnitude))
        // The policy uses normalized 10-bit format definitions independently of
        // the stored video range bit depth; adjacent clamp boundaries remain exact.
        XCTAssertEqual(try TransformPlan(settings:s.withRangeBitDepth(12)).evaluate(p),trace.output)
        for x in [Double(0).nextDown,0,Double(0).nextUp,Double(1).nextDown,1,Double(1).nextUp] {
            XCTAssertEqual(try video.evaluateLegal(x),min(1,max(0,x)))
        }
    }
    func testIndependentDecimalAndCompleteLegalDataGrids() throws {
        let f=try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/final-output-independent-reference.json"))) as! [String:Any]
        var errors:[Double]=[]
        for item in f["cases"] as! [[String:Any]] {
            let settings=try JSONDecoder().decode(FinalOutputSettings.self,from:JSONSerialization.data(withJSONObject:item["settings"]!)),hdr=item["hdrMaximumLegal"] as? Double
            let k=try LegacyFinalOutput(settings:settings,outputRange:SignalNormalization(rawValue:item["outputRange"] as! String)!,
                hdrOutputActive:hdr != nil,hdrMaximumLegal:hdr,displayConversionActive:item["displayConversionActive"] as! Bool)
            let x=(item["input"] as! [String]).map{Double($0)!},y=(item["output"] as! [String]).map{Double($0)!}
            for i in x.indices{let e=abs(try k.evaluateLegal(x[i])-y[i])/max(1,abs(y[i]));errors.append(e);XCTAssertLessThanOrEqual(e,2e-12)}
        }
        func report(_ label:String,_ e:[Double]) {let a=e.sorted(),n=Double(a.count)
            print("Final Output \(label) scaled errors: count=\(a.count), max=\(a.last!), RMS=\(sqrt(e.reduce(0){$0+$1*$1}/n)), P99=\(a[Int(ceil(0.99*n))-1])")}
        report("independent Decimal",errors);errors=[]
        for item in f["grids"] as! [[String:Any]] {
            let final=try JSONDecoder().decode(FinalOutputSettings.self,from:JSONSerialization.data(withJSONObject:item["settings"]!))
            let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,outputSpace:.rec2020,
                inputRange:.data,outputRange:SignalNormalization(rawValue:item["outputRange"] as! String)!,exposureStops:0,finalOutput:final)
            let plan=try TransformPlan(settings:s),grid=try Grid3D(size:item["size"] as! Int,domain:LUTDomain(min:RGB64(-0.5,-0.5,-0.5),max:RGB64(2,2,2)))
            let bytes=try Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/\(item["file"]!)"))
            XCTAssertEqual(bytes.count,grid.nodeCount*24)
            for i in 0..<grid.nodeCount{let a=try plan.evaluate(grid.coordinate(at:i))
                for c in 0..<3{let bits=bytes.withUnsafeBytes{$0.loadUnaligned(fromByteOffset:(i*3+c)*8,as:UInt64.self)},y=Double(bitPattern:UInt64(littleEndian:bits))
                    let e=abs(a[c]-y)/max(1,abs(y));errors.append(e);XCTAssertLessThanOrEqual(e,2e-12)}
            }
        }
        report("independent four 33³/65³",errors)
    }

    func testActualLegacyCombinedChain17() throws {
        for linear in [true,false] {
        let bytes=try Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/final-output-legacy-pipeline17-\(linear ? "linear" : "post").f64"))
        let cdl=try ASCCDLSettings(slope:RGB64(1.25,0.75,1.5),offset:RGB64(-0.125,0.0625,-0.25),power:RGB64(0.5,1.25,2.5),saturation:0.625)
        let mt=try MultitoneSettings(saturationByStop:(0..<17).map{0.15+Double($0%5)*0.35},tones:[
            MultitoneTone(stop:-3,hue:17,saturation:245),MultitoneTone(stop:0,hue:101,saturation:187),MultitoneTone(stop:4,hue:231,saturation:213)])
        let s=TransformSettings(inputTransfer:.djiDLog2,outputTransfer:.djiDLog2,inputSpace:.djiDGamut2,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:1,ascCDL:cdl,sdrSaturation:try SDRSaturationSettings(),multitone:mt,
            blackGamma:try BlackGammaSettings(upperStops:0,featherStops:2,power:0.5),
            blackHighlight:try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.025,blackLock:true,highReferenceScene:0.72,highMap:0.91,highLock:true),knee:try KneeSettings(startStops:-2,clipStops:4,clipSlope:1,smoothness:0.35,legal:false),highlightGamut:try HighlightGamutSettings(highlightSpace:.srgb,transition:.logarithmicStops,lowStops:-1,highStops:3),gamutLimiter:try GamutLimiterSettings(mode:linear ? .linear : .postGamma,linearStops:-1,postLevel:0.85,secondarySpace:.srgb),displayConversion:DisplayConversionSettings(baseCurve:.rec709,outputCurve:.srgb,baseGamut:.rec2020,outputGamut:.p3D60),falseColour:try FalseColourSettings(doOrange:true),finalOutput:try FinalOutputSettings(mode:.both,minimumCode10:-1023))
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
        let a=errors.sorted(),n=Double(a.count)
        print("Final Output legacy \(linear ? "linear" : "post") combined 17³ scaled errors: count=\(a.count), max=\(a.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/n)), P99=\(a[Int(ceil(0.99*n))-1])")
        }
    }
}

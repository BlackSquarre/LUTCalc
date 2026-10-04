import Foundation
import XCTest
import LUTCore

final class FalseColourContractsTests:XCTestCase {
    private func root()->URL {URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()}
    func testActualLegacyAll128BandCombinationsAndBoundaryProbes() throws {
        let f=try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/false-colour-boundary-audit.json"))) as! [String:Any]
        XCTAssertEqual(f["changedProbes"] as! Int,192)
        var count=0,maxError=0.0
        for item in f["cases"] as! [[String:Any]] {
            let s=try JSONDecoder().decode(FalseColourSettings.self,from:JSONSerialization.data(withJSONObject:item["settings"]!))
            let k=try LegacyFalseColour(settings:s)
            
            let t=(item["thresholds"] as! [String]).map{Double($0)!}
            for i in 0..<10{XCTAssertEqual(k.thresholds[i].bitPattern,t[i].bitPattern)}
            for probe in item["probes"] as! [[String:Any]] {
                let x=(probe["work"] as! [String]).map{Double($0)!},y=Double(probe["luma"] as! String)!
                let expected=(probe["band"] as? Int).flatMap{FalseColourBand(rawValue:$0)}
                XCTAssertEqual(try k.classifyLumaLegacy(y),expected)
                XCTAssertEqual(try k.classifyLegacy(RGB64(x[0],x[1],x[2])),expected)
                let a=try k.overlayLegal(RGB64(-0.125,0.375,1.25),band:expected),v=(probe["output"] as! [String]).map{Double($0)!}
                for c in 0..<3{let e=abs(a[c]-v[c])/max(1,abs(v[c]));count+=1;maxError=max(maxError,e);XCTAssertLessThanOrEqual(e,2e-12)}
            }
        }
        print("False Colour independently audited boundary palette scaled errors: count=\(count), max=\(maxError)")
    }
    func testParameterValidationStage5SnapshotStage18AndIndependentRefusal() throws {
        for x in [0,0.99,Double.nan,Double.infinity]{XCTAssertThrowsError(try FalseColourSettings(blueStopsBelowGray:x))}
        for x in [0,3.01,Double.nan,Double.infinity]{XCTAssertThrowsError(try FalseColourSettings(yellowStopsBelowClip:x))}
        for x in [3.49,Double.nan,Double.infinity]{XCTAssertThrowsError(try FalseColourSettings(redStopsAboveGray:x))}
        XCTAssertThrowsError(try LegacyFalseColour(settings:FalseColourSettings(redStopsAboveGray:2000)))
        let fc=try FalseColourSettings()
        let cdl=try ASCCDLSettings(slope:RGB64(10,10,10))
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.djiDLog2,inputSpace:.sonySGamut3Cine,outputSpace:.sonySGamut3Cine,
            inputRange:.data,outputRange:.data,exposureStops:1,ascCDL:cdl,falseColour:fc)
        let plan=try TransformPlan(settings:s),p=try RGB64(0.09,0.09,0.09),trace=try plan.trace(p)
        XCTAssertEqual(trace.stages.map(\.id),[1,2,3,4,5,8,10,13,18,19])
        XCTAssertEqual(trace.stages.first{$0.id==5}?.falseColourBand,.green)
        XCTAssertEqual(trace.stages.first{$0.id==18}?.falseColourBand,.green)
        let a=876.0/1023,b=64.0/1023
        XCTAssertEqual(trace.output,try RGB64(b,0.7*a+b,b))
        XCTAssertNil(trace.stages.first{$0.id==18}?.outputSpace)
        XCTAssertThrowsError(try plan.evaluateIndependentChannels(p))
        XCTAssertTrue(plan.planVersion.contains(fc.algorithm.rawValue))
        let none=try FalseColourSettings(doPurple:false,doBlue:false,doGreen:false,doPink:false,doOrange:false,doYellow:false,doRed:false)
        let plain=try TransformPlan(settings:s.withFalseColour(nil)),off=try TransformPlan(settings:s.withFalseColour(none))
        XCTAssertEqual(try plain.evaluate(p),try off.evaluate(p))
        XCTAssertEqual(try plain.evaluateIndependentChannels(p),try off.evaluateIndependentChannels(p))
        let extreme=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.sonySGamut3Cine,outputSpace:.sonySGamut3Cine,
            inputRange:.data,outputRange:.data,exposureStops:0,falseColour:fc)
        XCTAssertThrowsError(try TransformPlan(settings:extreme).evaluate(RGB64(Double.greatestFiniteMagnitude,Double.greatestFiniteMagnitude,Double.greatestFiniteMagnitude),sampleIndex:19)) {
            XCTAssertEqual($0 as? PlanError,.numeric(stageID:5,sampleIndex:19))
        }
    }
    func testIndependentDecimalBoundariesAndComplete33And65Grids() throws {
        let f=try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/false-colour-independent-reference.json"))) as! [String:Any]
        for item in f["cases"] as! [[String:Any]] {
            let settings=try JSONDecoder().decode(FalseColourSettings.self,from:JSONSerialization.data(withJSONObject:item["settings"]!))
            let kernel=try LegacyFalseColour(settings:settings),t=(item["thresholds"] as! [String]).map{Double($0)!}
            for i in 0..<10{XCTAssertEqual(kernel.thresholds[i].bitPattern,t[i].bitPattern)}
            for probe in item["probes"] as! [[String:Any]] {
                XCTAssertEqual(try kernel.classifyLumaLegacy(Double(probe["luma"] as! String)!),
                    (probe["band"] as? Int).flatMap{FalseColourBand(rawValue:$0)})
            }
        }
        var errors:[Double]=[],bandCounts=[Int](repeating:0,count:11)
        for item in f["grids"] as! [[String:Any]] {
            let fc=try JSONDecoder().decode(FalseColourSettings.self,from:JSONSerialization.data(withJSONObject:item["settings"]!))
            let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.sonySGamut3Cine,outputSpace:.sonySGamut3Cine,
                inputRange:.data,outputRange:.data,exposureStops:0,falseColour:fc)
            let plan=try TransformPlan(settings:s),grid=try Grid3D(size:item["size"] as! Int,
                domain:LUTDomain(min:RGB64(-0.5,-0.5,-0.5),max:RGB64(16,16,16)))
            let bytes=try Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/\(item["file"]!)")),
                bands=try Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/\(item["bandsFile"]!)"))
            XCTAssertEqual(bytes.count,grid.nodeCount*24);XCTAssertEqual(bands.count,grid.nodeCount)
            for i in 0..<grid.nodeCount {
                let actual=try plan.evaluate(grid.coordinate(at:i)),band=try plan.trace(grid.coordinate(at:i)).stages.first{$0.id==5}!.falseColourBand!
                XCTAssertEqual(band.rawValue,Int(bands[i]));bandCounts[band.rawValue]+=1
                for c in 0..<3{let bits=bytes.withUnsafeBytes{$0.loadUnaligned(fromByteOffset:(i*3+c)*8,as:UInt64.self)},y=Double(bitPattern:UInt64(littleEndian:bits))
                    let e=abs(actual[c]-y)/max(1,abs(y));errors.append(e);XCTAssertLessThanOrEqual(e,2e-12)}
            }
        }
        let a=errors.sorted(),n=Double(a.count)
        print("False Colour independent four 33³/65³ scaled errors: count=\(a.count), max=\(a.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/n)), P99=\(a[Int(ceil(0.99*n))-1]), bands=\(bandCounts)")
    }

    func testActualLegacyCombinedChain17() throws {
        for linear in [true,false] {
        let bytes=try Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/false-colour-legacy-pipeline17-\(linear ? "linear" : "post").f64"))
        let cdl=try ASCCDLSettings(slope:RGB64(1.25,0.75,1.5),offset:RGB64(-0.125,0.0625,-0.25),power:RGB64(0.5,1.25,2.5),saturation:0.625)
        let mt=try MultitoneSettings(saturationByStop:(0..<17).map{0.15+Double($0%5)*0.35},tones:[
            MultitoneTone(stop:-3,hue:17,saturation:245),MultitoneTone(stop:0,hue:101,saturation:187),MultitoneTone(stop:4,hue:231,saturation:213)])
        let s=TransformSettings(inputTransfer:.djiDLog2,outputTransfer:.djiDLog2,inputSpace:.djiDGamut2,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:1,ascCDL:cdl,sdrSaturation:try SDRSaturationSettings(),multitone:mt,
            blackGamma:try BlackGammaSettings(upperStops:0,featherStops:2,power:0.5),
            blackHighlight:try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.025,blackLock:true,highReferenceScene:0.72,highMap:0.91,highLock:true),knee:try KneeSettings(startStops:-2,clipStops:4,clipSlope:1,smoothness:0.35,legal:false),highlightGamut:try HighlightGamutSettings(highlightSpace:.srgb,transition:.logarithmicStops,lowStops:-1,highStops:3),gamutLimiter:try GamutLimiterSettings(mode:linear ? .linear : .postGamma,linearStops:-1,postLevel:0.85,secondarySpace:.srgb),displayConversion:DisplayConversionSettings(baseCurve:.rec709,outputCurve:.srgb,baseGamut:.rec2020,outputGamut:.p3D60),falseColour:try FalseColourSettings(doOrange:true))
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
        print("False Colour legacy \(linear ? "linear" : "post") combined 17³ scaled errors: count=\(a.count), max=\(a.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/n)), P99=\(a[Int(ceil(0.99*n))-1])")
        }
    }
}

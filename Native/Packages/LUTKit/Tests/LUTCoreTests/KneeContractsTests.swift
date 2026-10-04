import Foundation
import XCTest
import LUTCore

final class KneeContractsTests:XCTestCase {
    private func root()->URL {
        URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private func settings(_ knee:KneeSettings?,output:TransferID = .linearScene,
                          levels:BlackHighlightSettings? = nil,gamma:BlackGammaSettings? = nil)->TransformSettings {
        TransformSettings(inputTransfer:.linearScene,outputTransfer:output,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,blackGamma:gamma,blackHighlight:levels,knee:knee)
    }
    private func report(_ name:String,_ errors:[Double]) {
        let n=Double(errors.count),sorted=errors.sorted()
        print("Knee \(name) scaled errors: count=\(errors.count), max=\(sorted.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/n)), P99=\(sorted[Int(ceil(0.99*n))-1])")
    }
    func testActualLegacyPreparationAndSamples() throws {
        let fixture=try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/knee-legacy-reference.json"))) as! [String:Any]
        var errors:[Double]=[]
        for item in fixture["cases"] as! [[String:Any]] {
            let name=item["name"] as! String,p=item["parameters"] as! [String:Any]
            let output:TransferID=name == "Rec709" ? .rec709LUTCalcLegacy : name == "DJI D-Log2" ? .djiDLog2 : name == "Scene Reflectance" ? .linearScene : .sonySLog3LUTCalcLegacy
            let plain=try TransformPlan(settings:settings(nil,output:output))
            let scale=output == .djiDLog2 || output == .sonySLog3LUTCalcLegacy ? 876.0/1023 : 1
            let offset=scale == 1 ? 0 : 64.0/1023
            let cdl:ASCCDLSettings?
            if let a=item["cdl"] as? [Double] {cdl=try ASCCDLSettings(slope:RGB64(a[0],a[1],a[2]),offset:RGB64(a[3],a[4],a[5]),power:RGB64(a[6],a[7],a[8]),saturation:a[9])}else{cdl=nil}
            let s=try KneeSettings(startStops:p["kneeStart"] as! Double,clipStops:p["kneeClip"] as! Double,
                clipSlope:p["clipSlope"] as! Double,smoothness:p["smoothness"] as! Double,legal:p["legal"] as! Bool)
            let kernel=try LegacyKnee(settings:s,cdl:cdl) {x in
                let scene=try LinearScale.legacyToScene(x)
                return (try plain.evaluate(RGB64(scene,scene,scene)).r-offset)/scale
            }
            XCTAssertEqual(kernel.active,item["active"] as! Bool)
            let expected=(item["coefficients"] as! [String]).map{Double($0)!}
            let actual=[kernel.startStops,kernel.clipStops,kernel.thresholdLegacy,kernel.spanStops,kernel.p0,kernel.p1,kernel.p2,kernel.d0,kernel.d1,kernel.d2,kernel.split,kernel.tailSlope]
            for i in actual.indices {XCTAssertEqual(actual[i],expected[i],accuracy:2e-12)}
            for probe in item["probes"] as! [[String:Any]] {
                let x=Double(probe["input"] as! String)!,encoded=Double(probe["encoded"] as! String)!,y=Double(probe["output"] as! String)!
                let actual=try kernel.evaluateLegacy(x,encodedLegal:encoded),error=abs(actual-y)/max(1,abs(y))
                errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
            }
        }
        report("actual legacy",errors)
    }
    func testBoundsInvalidCDLDisabledAndLegacyNonmonotonicity() throws {
        for x in [-5.1,8.1,Double.nan,Double.infinity]{XCTAssertThrowsError(try KneeSettings(startStops:x))}
        for x in [0,8.1,Double.nan]{XCTAssertThrowsError(try KneeSettings(clipStops:x))}
        for x in [-0.01,2.51,Double.nan]{XCTAssertThrowsError(try KneeSettings(clipSlope:x))}
        for x in [-0.01,1.01,Double.nan]{XCTAssertThrowsError(try KneeSettings(smoothness:x))}
        XCTAssertThrowsError(try KneeSettings(startStops:1,clipStops:1))
        let s=try KneeSettings(),negative=try ASCCDLSettings(slope:RGB64(0,0,0),offset:RGB64(-1,-1,-1))
        XCTAssertThrowsError(try LegacyKnee(settings:s,cdl:negative,encodeLegacyToLegal:{$0*0.9}))
        let reduced=try ASCCDLSettings(slope:RGB64(0.001,0.001,0.001))
        let reversed=try LegacyKnee(settings:s,cdl:reduced,encodeLegacyToLegal:{$0*0.9})
        XCTAssertFalse(reversed.active)
        XCTAssertEqual(try reversed.evaluateLegacy(20,encodedLegal:0.75),0.75)
        let disabledPlan=try TransformPlan(settings:settings(s).withASCCDL(reduced))
        let normalPlan=try TransformPlan(settings:settings(nil).withASCCDL(reduced))
        for x in [-0.5,0,0.18,1,20] {
            let rgb=try RGB64(x,x,x)
            XCTAssertEqual(try disabledPlan.evaluate(rgb),try normalPlan.evaluate(rgb))
            XCTAssertEqual(try disabledPlan.evaluateIndependentChannels(rgb),try normalPlan.evaluateIndependentChannels(rgb))
        }
        let disabled=try LegacyKnee(settings:KneeSettings(enabled:false),encodeLegacyToLegal:{$0})
        XCTAssertEqual(try disabled.evaluateLegacy(20,encodedLegal:-0.0).bitPattern,(-0.0).bitPattern)
        XCTAssertThrowsError(try disabled.evaluateLegacy(.infinity,encodedLegal:0))
        let fallback=try LegacyKnee(settings:KneeSettings(startStops:4,clipStops:8),encodeLegacyToLegal:{$0*0.9})
        XCTAssertNotEqual(fallback.split,0.5)
        let plain=try TransformPlan(settings:settings(nil,output:.rec709LUTCalcLegacy))
        let kernel=try LegacyKnee(settings:KneeSettings(startStops:1,clipStops:6,clipSlope:0)) {x in
            try plain.evaluate(RGB64(x*0.9,x*0.9,x*0.9)).r
        }
        var previous = -Double.infinity,foundDecrease=false
        for i in 0...1000 {
            let x=0.2*pow(2,kernel.startStops+kernel.spanStops*Double(i)/1000)
            let y=try kernel.evaluateLegacy(x,encodedLegal:0)
            if y < previous-1e-12{foundDecrease=true};previous=y
        }
        XCTAssertTrue(foundDecrease,"The legacy version must not silently claim monotonicity")
    }
    func testStage13IndependentChannelsLevelsGammaAnchorsAndRanges() throws {
        let knee=try KneeSettings(startStops:-2,clipStops:4,clipSlope:1,smoothness:0.35,legal:false)
        let plain=try TransformPlan(settings:settings(knee))
        let p=try RGB64(0.018,0.5,20),trace=try plain.trace(p)
        XCTAssertEqual(trace.stages.map(\.id),[1,2,3,4,10,13,19])
        XCTAssertEqual(trace.output,try plain.evaluateIndependentChannels(p))
        XCTAssertTrue(plain.planVersion.contains("knee"))
        let levels=try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.05,blackLock:true,highMap:0.85,highLock:true)
        let gamma=try BlackGammaSettings(upperStops:0,featherStops:2,power:0.5)
        func anchor(_ x:Double)throws->Double{try plain.evaluate(RGB64(x,x,x)).r}
        let levelKernel=try LegacyBlackHighlight(settings:levels,blackDefault:anchor(0),highDefault:anchor(0.9))
        let gammaKernel=try LegacyBlackGamma(settings:gamma,black:levelKernel.evaluate(anchor(0)),
            lower:levelKernel.evaluate(anchor(0.045)),upper:levelKernel.evaluate(anchor(0.18)))
        let combined=try TransformPlan(settings:settings(knee,levels:levels,gamma:gamma)).trace(p)
        XCTAssertEqual(combined.stages.map(\.id),[1,2,3,4,10,13,14,15,19])
        for c in 0..<3 {XCTAssertEqual(combined.output[c],try gammaKernel.evaluate(levelKernel.evaluate(trace.output[c])),accuracy:2e-12)}
        let video=try TransformPlan(settings:settings(knee).withOutputRange(.video)),range=try CodeRange.videoRGB(bitDepth:10)
        for c in 0..<3 {XCTAssertEqual(try video.evaluate(p)[c],try range.dataToVideo(trace.output[c]),accuracy:2e-12)}
        let unlocked=try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.03,highMap:0.8)
        let changed=settings(nil,levels:unlocked).withKnee(knee)
        XCTAssertEqual(changed.blackHighlight,unlocked)
        XCTAssertEqual(settings(nil,levels:levels).withKnee(knee).blackHighlight,levels)
    }
    func testIndependentDecimalAndFull33And65Grids() throws {
        let f=try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/knee-independent-reference.json"))) as! [String:Any]
        var errors:[Double]=[]
        for item in f["cases"] as! [[String:Any]] {
            let s=try JSONDecoder().decode(KneeSettings.self,from:JSONSerialization.data(withJSONObject:item["settings"]!))
            let kernel=try LegacyKnee(settings:s,encodeLegacyToLegal:{$0*0.9})
            for probe in item["probes"] as! [[String:Any]] {
                let x=Double(probe["input"] as! String)!,encoded=Double(probe["encoded"] as! String)!,y=Double(probe["output"] as! String)!
                let actual=try kernel.evaluateLegacy(x,encodedLegal:encoded),error=abs(actual-y)/max(1,abs(y))
                errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
            }
        }
        report("independent Decimal",errors);errors=[]
        let plan=try TransformPlan(settings:settings(KneeSettings(startStops:-2,clipStops:4,clipSlope:1,smoothness:0.35,legal:false)))
        for axis in f["gridAxes"] as! [[String:Any]] {
            let size=axis["size"] as! Int,expected=(axis["outputs"] as! [String]).map{Double($0)!}
            let grid=try Grid3D(size:size,domain:LUTDomain(min:RGB64(-0.5,-0.5,-0.5),max:RGB64(32,32,32)))
            for i in 0..<grid.nodeCount {
                let actual=try plan.evaluate(grid.coordinate(at:i),sampleIndex:i),indices=[i%size,(i/size)%size,i/(size*size)]
                for c in 0..<3 {
                    let y=expected[indices[c]],error=abs(actual[c]-y)/max(1,abs(y))
                    errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
                }
            }
        }
        report("independent 33³/65³",errors)
    }
    func testActualLegacyCombinedChain17() throws {
        let bytes=try Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/knee-legacy-pipeline17.f64"))
        let cdl=try ASCCDLSettings(slope:RGB64(1.25,0.75,1.5),offset:RGB64(-0.125,0.0625,-0.25),power:RGB64(0.5,1.25,2.5),saturation:0.625)
        let mt=try MultitoneSettings(saturationByStop:(0..<17).map{0.15+Double($0%5)*0.35},tones:[
            MultitoneTone(stop:-3,hue:17,saturation:245),MultitoneTone(stop:0,hue:101,saturation:187),MultitoneTone(stop:4,hue:231,saturation:213)])
        let s=TransformSettings(inputTransfer:.djiDLog2,outputTransfer:.djiDLog2,inputSpace:.djiDGamut2,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:1,ascCDL:cdl,sdrSaturation:try SDRSaturationSettings(),multitone:mt,
            blackGamma:try BlackGammaSettings(upperStops:0,featherStops:2,power:0.5),
            blackHighlight:try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.025,blackLock:true,highReferenceScene:0.72,highMap:0.91,highLock:true),knee:try KneeSettings(startStops:-2,clipStops:4,clipSlope:1,smoothness:0.35,legal:false))
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
        report("legacy available combined chain 17³",errors)
    }
}

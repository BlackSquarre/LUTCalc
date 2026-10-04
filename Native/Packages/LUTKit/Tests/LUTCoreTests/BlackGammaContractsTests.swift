import Foundation
import XCTest
import LUTCore

final class BlackGammaContractsTests: XCTestCase {
    private func settings(_ gamma: BlackGammaSettings?, output: TransferID = .linearScene,
                          range: SignalNormalization = .data, cdl: ASCCDLSettings? = nil) -> TransformSettings {
        TransformSettings(inputTransfer:.linearScene,outputTransfer:output,inputSpace:.rec2020,
            outputSpace:.rec2020,inputRange:.data,outputRange:range,exposureStops:0,ascCDL:cdl,blackGamma:gamma)
    }
    func testIndependentFullGridsAndStage15RangeOrder() throws {
        let gamma=try BlackGammaSettings(upperStops:0,featherStops:2,power:2)
        let plan=try TransformPlan(settings:settings(gamma))
        var errors:[Double]=[]
        for size in [33,65] {
            let grid=try Grid3D(size:size,domain:LUTDomain(min:RGB64(-0.1,-0.1,-0.1),max:RGB64(1.2,1.2,1.2)))
            for index in 0..<grid.nodeCount {
                let input=try grid.coordinate(at:index),actual=try plan.evaluate(input,sampleIndex:index)
                for c in 0..<3 {
                    let x=input[c]
                    var expected=x
                    if x>0 && x<=0.18 {
                        let curved=x*x/0.18
                        if x>0.045 {
                            let t=(x-0.045)/0.135
                            expected=curved+(x-curved)*t*t
                        }else{expected=curved}
                    }
                    let error=abs(actual[c]-expected)/max(1,abs(expected))
                    errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
                }
            }
        }
        let sorted=errors.sorted(),n=Double(errors.count)
        print("Black Gamma independent 33³/65³ scaled errors: count=\(errors.count), max=\(sorted.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/n)), P99=\(sorted[Int(ceil(n*0.99))-1])")
        let p=try RGB64(0.02,0.1,0.5),t=try plan.trace(p)
        XCTAssertEqual(t.stages.map(\.id),[1,2,3,4,10,13,15,19])
        let video=try TransformPlan(settings:settings(gamma,range:.video)).trace(p)
        let code=try CodeRange.videoRGB(bitDepth:10)
        for c in 0..<3{XCTAssertEqual(video.output[c],try code.dataToVideo(t.output[c]),accuracy:2e-12)}
        XCTAssertTrue(plan.planVersion.contains("black-gamma"))
        XCTAssertEqual(try plan.evaluateIndependentChannels(p),try plan.evaluate(p))
    }
    func testLegacyPreparedKernelAndEncodedAnchorPreparation() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for name in ["black-gamma-legacy-reference.json","black-gamma-independent-reference.json"] {
        let fixture=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("tests/fixtures/native-contracts/\(name)"))) as! [String:Any]
        var errors:[Double]=[]
        for item in fixture["cases"] as! [[String:Any]] {
            let gamma=try BlackGammaSettings(upperStops:item["upperStops"] as! Double,featherStops:item["featherStops"] as! Double,power:item["power"] as! Double,
                algorithm:name.contains("legacy") ? .lutcalcOutputEncodedV1 : .lutcalcOutputEncodedStableV1)
            let a=(item["anchors"] as! [String]).map{Double($0)!}
            let kernel=try LegacyBlackGamma(settings:gamma,black:a[0],lower:a[1],upper:a[2])
            for probe in item["probes"] as! [[String:Any]] {
                let x=Double(probe["input"] as! String)!,expected=Double(probe["output"] as! String)!
                let actual=try kernel.evaluate(x),error=abs(actual-expected)/max(1,abs(expected))
                errors.append(error);XCTAssertLessThanOrEqual(error,2e-12,"\(item["name"]!) x=\(x) anchors=\(a)")
            }
            if let transfer=item["nativeTransfer"] as? String {
                let plan=try TransformPlan(settings:settings(gamma,output:TransferID(rawValue:transfer)!))
                let trace=try plan.trace(RGB64(0.018,0.05,0.1))
                let stage=try XCTUnwrap(trace.stages.first{$0.id==15})
                let na=(item["nativeAnchors"] as! [String]).map{Double($0)!}
                let native=try LegacyBlackGamma(settings:gamma,black:na[0],lower:na[1],upper:na[2])
                for c in 0..<3{XCTAssertEqual(stage.output[c],try native.evaluate(stage.input[c]),accuracy:2e-12,"\(transfer) \(gamma)")}
            }
        }
        let sorted=errors.sorted(),n=Double(errors.count)
        print("Black Gamma \(name) scaled errors: count=\(errors.count), max=\(sorted.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/n)), P99=\(sorted[Int(ceil(n*0.99))-1])")
        }
        let gamma=try BlackGammaSettings(upperStops:-1,featherStops:3,power:0.5)
        let cdl=try ASCCDLSettings(slope:RGB64(1,2,3),offset:RGB64(0.01,0.02,0.03),power:RGB64(1,1,1),saturation:0)
        let p=try RGB64(0.01,0.05,0.2)
        let base=try TransformPlan(settings:settings(nil,output:.rec709LUTCalcLegacy,cdl:cdl)).evaluate(p)
        let anchorPlan=try TransformPlan(settings:settings(nil,output:.rec709LUTCalcLegacy))
        let sop=try LegacyASCCDL(settings:cdl)
        func anchor(_ x:Double)throws->Double {
            let q=try anchorPlan.evaluate(sop.evaluateScene(RGB64(x,x,x),applySaturation:false))
            return 0.2126*q.r+0.7152*q.g+0.0722*q.b
        }
        let k=try LegacyBlackGamma(settings:gamma,black:anchor(0),lower:anchor(0.18/16),upper:anchor(0.18/2))
        let actual=try TransformPlan(settings:settings(gamma,output:.rec709LUTCalcLegacy,cdl:cdl)).evaluate(p)
        for c in 0..<3{XCTAssertEqual(actual[c],try k.evaluate(base[c]),accuracy:2e-12)}
    }
    func testActualLegacyDecodeCDLMultitoneSDRBlackGammaPipeline17() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data=try Data(contentsOf:root.appendingPathComponent("tests/fixtures/native-contracts/black-gamma-legacy-pipeline17.f64"))
        let cdl=try ASCCDLSettings(slope:RGB64(1.25,0.75,1.5),offset:RGB64(-0.125,0.0625,-0.25),power:RGB64(0.5,1.25,2.5),saturation:0.625)
        let mt=try MultitoneSettings(saturationByStop:(0..<17).map{0.15+Double($0%5)*0.35},tones:[
            MultitoneTone(stop:-3,hue:17,saturation:245),MultitoneTone(stop:0,hue:101,saturation:187),MultitoneTone(stop:4,hue:231,saturation:213)])
        let s=TransformSettings(inputTransfer:.djiDLog2,outputTransfer:.djiDLog2,inputSpace:.djiDGamut2,
            outputSpace:.rec2020,inputRange:.data,outputRange:.data,exposureStops:1,ascCDL:cdl,
            sdrSaturation:try SDRSaturationSettings(),multitone:mt,blackGamma:try BlackGammaSettings(upperStops:0,featherStops:2,power:0.5))
        let plan=try TransformPlan(settings:s),grid=try Grid3D(size:17,domain:.unit)
        XCTAssertEqual(data.count,grid.nodeCount*3*8)
        var errors:[Double]=[]
        for i in 0..<grid.nodeCount {
            let actual=try plan.evaluate(grid.coordinate(at:i),sampleIndex:i)
            for c in 0..<3 {
                let bits=data.withUnsafeBytes{$0.loadUnaligned(fromByteOffset:(i*3+c)*8,as:UInt64.self)}
                let expected=Double(bitPattern:UInt64(littleEndian:bits))
                let error=abs(actual[c]-expected)/max(1,abs(expected))
                errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
            }
        }
        let sorted=errors.sorted(),n=Double(errors.count)
        print("Black Gamma legacy full available chain 17³ scaled errors: count=\(errors.count), max=\(sorted.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/n)), P99=\(sorted[Int(ceil(n*0.99))-1])")
    }
    func testBoundariesZeroFeatherDisabledAndInvalidParameters() throws {
        let g=try BlackGammaSettings(upperStops:-9,featherStops:0,power:0.5)
        let k=try LegacyBlackGamma(settings:g,black:0.1,lower:0.3,upper:0.3)
        for x in [-1,0.1,0.3,0.30000001,40]{XCTAssertEqual(try k.evaluate(x),x,accuracy:2e-12)}
        XCTAssertEqual(try k.evaluate(0.15),0.2,accuracy:2e-12)
        let subnormal=Double.leastNonzeroMagnitude
        let literal=try LegacyBlackGamma(settings:BlackGammaSettings(upperStops:0,featherStops:2,power:0.01,algorithm:.lutcalcOutputEncodedV1),black:0,lower:0.045,upper:0.18)
        let stable=try LegacyBlackGamma(settings:BlackGammaSettings(upperStops:0,featherStops:2,power:0.01),black:0,lower:0.045,upper:0.18)
        let old=try literal.evaluate(subnormal),corrected=try stable.evaluate(subnormal)
        XCTAssertGreaterThan(abs(old-corrected),2e-12)
        print("Black Gamma subnormal correction: legacy=\(old), stable=\(corrected), difference=\(abs(old-corrected))")
        let disabled=try LegacyBlackGamma(settings:BlackGammaSettings(enabled:false),black:0,lower:0,upper:1)
        XCTAssertEqual(try disabled.evaluate(-0.0).bitPattern,(-0.0).bitPattern)
        let collapsed=try LegacyBlackGamma(settings:g,black:1,lower:1,upper:1)
        XCTAssertEqual(try collapsed.evaluate(0.5),0.5)
        XCTAssertThrowsError(try k.evaluate(.infinity))
        for x in [-9.01,2.01,Double.nan]{XCTAssertThrowsError(try BlackGammaSettings(upperStops:x))}
        for x in [-0.1,9.01,Double.infinity]{XCTAssertThrowsError(try BlackGammaSettings(featherStops:x))}
        for x in [0,0.009,10.01,Double.nan]{XCTAssertThrowsError(try BlackGammaSettings(power:x))}
    }
}

import Foundation
import XCTest
import LUTCore

final class BlackHighlightContractsTests: XCTestCase {
    private func settings(_ level:BlackHighlightSettings?, gamma:BlackGammaSettings? = nil,
                          output:TransferID = .linearScene, range:SignalNormalization = .data) -> TransformSettings {
        TransformSettings(inputTransfer:.linearScene,outputTransfer:output,inputSpace:.rec2020,
            outputSpace:.rec2020,inputRange:.data,outputRange:range,exposureStops:0,
            blackGamma:gamma,blackHighlight:level)
    }
    private func root()->URL {
        URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private func report(_ name:String,_ errors:[Double]) {
        let sorted=errors.sorted(),n=Double(errors.count)
        print("Black Highlight \(name) scaled errors: count=\(errors.count), max=\(sorted.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/n)), P99=\(sorted[Int(ceil(n*0.99))-1])")
    }
    func testLegacyAndIndependentDecimalKernels() throws {
        for name in ["black-highlight-legacy-reference.json","black-highlight-independent-reference.json"] {
            let f=try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/\(name)"))) as! [String:Any]
            var errors:[Double]=[]
            for item in f["cases"] as! [[String:Any]] {
                let level=try JSONDecoder().decode(BlackHighlightSettings.self,from:JSONSerialization.data(withJSONObject:item["settings"]!))
                let anchors=(item["defaults"] as! [String]).map{Double($0)!}
                let kernel=try LegacyBlackHighlight(settings:level,blackDefault:anchors[0],highDefault:anchors[1])
                for probe in item["probes"] as! [[String:Any]] {
                    let x=Double(probe["input"] as! String)!,expected=Double(probe["output"] as! String)!
                    let actual=try kernel.evaluate(x),error=abs(actual-expected)/max(1,abs(expected))
                    errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
                }
            }
            if let changes=f["changes"] as? [[String:Any]] {
                for change in changes {
                    let locked=change["lock"] as! Bool,kind=change["changed"] as! String
                    var level=try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.05,blackLock:locked,highMap:0.85,highLock:locked)
                    if kind == "changedRef" {level=try level.withHighReferenceScene(0.72)}
                    else {level=level.rebasedForChanges(outputChanged:kind == "changedOut",cdlChanged:kind == "changedASCCDL",hdrChanged:kind == "changedHDR")}
                    let b=Double(change["blackDefault"] as! String)!,h=Double(change["highDefault"] as! String)!
                    let k=try LegacyBlackHighlight(settings:level,blackDefault:b,highDefault:h)
                    XCTAssertEqual(k.blackMap,Double(change["blackMap"] as! String)!,accuracy:2e-12)
                    XCTAssertEqual(k.highMap,Double(change["highMap"] as! String)!,accuracy:2e-12)
                }
            }
            report(name,errors)
        }
    }
    func testIndependent33And65GridsStage14AndBlackGammaPreparation() throws {
        let level=try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.05,blackLock:true,
            highReferenceScene:0.9,highMap:0.85,highLock:true)
        let plan=try TransformPlan(settings:settings(level))
        var errors:[Double]=[]
        for size in [33,65] {
            let grid=try Grid3D(size:size,domain:LUTDomain(min:RGB64(-0.5,-0.5,-0.5),max:RGB64(2,2,2)))
            for i in 0..<grid.nodeCount {
                let x=try grid.coordinate(at:i),actual=try plan.evaluate(x,sampleIndex:i)
                for c in 0..<3 {
                    let expected=0.05+(0.85-0.05)*x[c]/0.9,error=abs(actual[c]-expected)/max(1,abs(expected))
                    errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
                }
            }
        }
        report("independent 33³/65³",errors)
        let p=try RGB64(0.018,0.08,0.5),t=try plan.trace(p)
        XCTAssertEqual(t.stages.map(\.id),[1,2,3,4,10,13,14,19])
        let gamma=try BlackGammaSettings(upperStops:0,featherStops:2,power:2)
        let combined=try TransformPlan(settings:settings(level,gamma:gamma)).trace(p)
        XCTAssertEqual(combined.stages.map(\.id),[1,2,3,4,10,13,14,15,19])
        let b=0.05,lower=0.05+0.8*0.045/0.9,upper=0.05+0.8*0.18/0.9
        let k=try LegacyBlackGamma(settings:gamma,black:b,lower:lower,upper:upper)
        for c in 0..<3{XCTAssertEqual(combined.output[c],try k.evaluate(t.output[c]),accuracy:2e-12)}
        let video=try TransformPlan(settings:settings(level,gamma:gamma,range:.video)).evaluate(p)
        let code=try CodeRange.videoRGB(bitDepth:10)
        for c in 0..<3{XCTAssertEqual(video[c],try code.dataToVideo(combined.output[c]),accuracy:2e-12)}
        for output in [TransferID.djiDLog2,.sonySLog3LUTCalcLegacy,.arriLogC4,.acesProxy10,.acesProxy12] {
            let encoded=try TransformPlan(settings:settings(level,output:output)).evaluate(RGB64(0,0,0))
            let expected=0.05*876/1023+64.0/1023
            for c in 0..<3{XCTAssertEqual(encoded[c],expected,accuracy:2e-12)}
        }
        for output in [TransferID.rec709LUTCalcLegacy,.srgbW3CExtended,.acesCCT,.rec2100HLG,.rec2100PQ] {
            let encoded=try TransformPlan(settings:settings(level,output:output)).evaluate(RGB64(0,0,0))
            for c in 0..<3{XCTAssertEqual(encoded[c],0.05,accuracy:2e-12)}
        }
        XCTAssertEqual(try plan.evaluateIndependentChannels(p),t.output)
        XCTAssertTrue(plan.planVersion.contains("black-highlight"))
    }
    func testAutomaticDefaultsLocksRebaseToleranceAndFailureBoundaries() throws {
        let auto=try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.00005,highMap:1.00005)
        let k=try LegacyBlackHighlight(settings:auto,blackDefault:0,highDefault:1)
        XCTAssertEqual(k.blackMap,0);XCTAssertEqual(k.highMap,1)
        let locked=try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.00005,blackLock:true,highMap:1.00005,highLock:true)
        XCTAssertEqual(try LegacyBlackHighlight(settings:locked,blackDefault:0,highDefault:1).blackMap,0.00005)
        let edit=try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.1,highMap:0.8)
        for resolved in [edit.rebasedForChanges(outputChanged:true),edit.rebasedForChanges(cdlChanged:true),edit.rebasedForChanges(hdrChanged:true)] {
            XCTAssertNil(resolved.blackLevel);XCTAssertNil(resolved.highMap)
        }
        let ref=try edit.withHighReferenceScene(0.72)
        XCTAssertEqual(ref.blackLevel,0.1);XCTAssertNil(ref.highMap)
        XCTAssertEqual(locked.rebasedForChanges(outputChanged:true),locked)
        XCTAssertEqual(try locked.withHighReferenceScene(0.72).highMap,locked.highMap)
        XCTAssertNil(settings(edit).withOutput(transfer:.djiDLog2,space:.rec2020).blackHighlight?.blackLevel)
        XCTAssertEqual(settings(edit).withOutput(transfer:.linearScene,space:.acesAP0).blackHighlight,edit)
        let cdl=try ASCCDLSettings(offset:RGB64(0.01,0,0))
        XCTAssertNil(settings(edit).withASCCDL(cdl).blackHighlight?.blackLevel)
        let flip=try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.5,blackLock:true,highMap:0.1,highLock:true)
        let inverse=try LegacyBlackHighlight(settings:flip,blackDefault:0,highDefault:1)
        XCTAssertEqual(try inverse.evaluate(2),-0.3,accuracy:2e-12)
        let disabled=try LegacyBlackHighlight(settings:BlackHighlightSettings(enabled:false),blackDefault:0,highDefault:0)
        XCTAssertEqual(try disabled.evaluate(-0.0).bitPattern,(-0.0).bitPattern)
        XCTAssertThrowsError(try LegacyBlackHighlight(settings:edit,blackDefault:1,highDefault:1))
        for x in [-0.073,-1,Double.infinity,Double.nan]{XCTAssertThrowsError(try BlackHighlightSettings(blackLevel:x))}
        for x in [0,-1,Double.infinity,Double.nan]{XCTAssertThrowsError(try BlackHighlightSettings(highReferenceScene:x))}
        XCTAssertThrowsError(try planOverflow().evaluate(RGB64(3,3,3),sampleIndex:11)) {
            XCTAssertEqual($0 as? PlanError,.numeric(stageID:14,sampleIndex:11))
        }
    }
    private func planOverflow() throws -> TransformPlan {
        try TransformPlan(settings:settings(BlackHighlightSettings(doHigh:true,highMap:Double.greatestFiniteMagnitude*0.5,highLock:true)))
    }
    func testActualLegacyCombinedChain17() throws {
        let bytes=try Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/black-highlight-legacy-pipeline17.f64"))
        let cdl=try ASCCDLSettings(slope:RGB64(1.25,0.75,1.5),offset:RGB64(-0.125,0.0625,-0.25),power:RGB64(0.5,1.25,2.5),saturation:0.625)
        let mt=try MultitoneSettings(saturationByStop:(0..<17).map{0.15+Double($0%5)*0.35},tones:[
            MultitoneTone(stop:-3,hue:17,saturation:245),MultitoneTone(stop:0,hue:101,saturation:187),MultitoneTone(stop:4,hue:231,saturation:213)])
        let s=TransformSettings(inputTransfer:.djiDLog2,outputTransfer:.djiDLog2,inputSpace:.djiDGamut2,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:1,ascCDL:cdl,sdrSaturation:try SDRSaturationSettings(),multitone:mt,
            blackGamma:try BlackGammaSettings(upperStops:0,featherStops:2,power:0.5),
            blackHighlight:try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.025,blackLock:true,highReferenceScene:0.72,highMap:0.91,highLock:true))
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

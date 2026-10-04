import Foundation
import XCTest
@testable import LUTCore

final class OutputCodeUnitsContractsTests:XCTestCase {
    private let wrapped:[TransferID] = [.cieLStar,.proPhoto,.bbc04,.bbc05,.bbc06,.bbcWHP283400,.bbcWHP283800,
        .gamma15,.gamma16,.gamma17,.gamma18,.gamma19,.gamma20,.gamma21,.gamma22,.gamma23,.gamma24,.gamma25,.gamma26]
    private func settings(_ tf:TransferID,policy:OutputCodeUnitPolicy = .completeV2,levels:Bool = false,knee:Bool = false,limiter:Bool = false,secondary:Bool = false,both:Bool = true,blackGamma:Bool = false)throws->TransformSettings {
        TransformSettings(inputTransfer:.linearScene,outputTransfer:tf,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,
            blackGamma:blackGamma ? try BlackGammaSettings(upperStops:0,featherStops:2,power:0.5) : nil,
            blackHighlight:levels ? try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.05,blackLock:true,highMap:0.85,highLock:true) : nil,
            knee:knee ? try KneeSettings(startStops:-2,clipStops:4,clipSlope:1,smoothness:0.35,legal:false) : nil,
            gamutLimiter:limiter ? try GamutLimiterSettings(postLevel:0.6,secondarySpace:secondary ? .srgb : nil,protectBoth:both) : nil,outputCodeUnits:policy)
    }
    private func root()->URL {URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()}
    private func fixture(_ name:String)throws->[String:Any] {
        try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/\(name)"))) as! [String:Any]
    }
    private func report(_ name:String,_ errors:[Double]) {
        let sorted=errors.sorted(),n=Double(errors.count)
        print("Output Code Units \(name) scaled errors: count=\(errors.count), max=\(sorted.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/n)), P99=\(sorted[Int(ceil(0.99*n))-1])")
    }
    func testActualNativeWrappersAndPolicyBoundary() throws {
        let data:[TransferID]=[.blackmagicFilmGen5,.blackmagicFilmGen5LUTCalcLegacy,.djiDLog2,.sonySLog3,.sonySLog3LUTCalcLegacy,.arriLogC4,.arriLogCSUP2Scene,.arriLogCSUP3Scene,.panasonicVLog,.fujifilmFLog2,
            .fujifilmFLog2LUTCalcLegacy,.insta360ILog,.xiaomiMiLog,.leicaLLog,.kineLog3,.appleLogOriginal,.appleLog2,.acesProxy10,.acesProxy12]
        let canonical:[TransferID]=[.linearScene,.srgbW3CExtended,.srgbLUTCalcLegacy,.rec709LUTCalcLegacy,.acesCC,.acesCCT,
            .rec2100HLG,.rec2100PQ,.bt1886,.parameterizedGamma]
        XCTAssertEqual(Set((wrapped+data+canonical).map(\.rawValue)).count,48)
        for tf in data{XCTAssertTrue(tf.hasNormalizedDataEncoding)}
        for tf in canonical{XCTAssertFalse(tf.hasNormalizedDataEncoding)}
        for tf in wrapped {
            XCTAssertTrue(tf.hasNormalizedDataEncoding,tf.rawValue)
            let current=try NativeOutputEncoder(settings:settings(tf)),old=try NativeOutputEncoder(settings:settings(tf,policy:.partialV1))
            XCTAssertEqual(current.legalScale,0.85630498533724)
            XCTAssertEqual(current.legalOffset,0.06256109481916)
            XCTAssertEqual(old.legalScale,1);XCTAssertEqual(old.legalOffset,0)
            for x in [-0.5,0,0.18,0.9,2] {
                let native=try current.encodeScene(x)
                XCTAssertEqual(try old.encodeScene(x),native)
                XCTAssertEqual(try current.encodeLegacyToLegal(x/0.9),(native-current.legalOffset)/current.legalScale,accuracy:2e-12)
            }
        }
        let level=try settings(.gamma22,levels:true),fixed=try TransformPlan(settings:level),old=try TransformPlan(settings:level.withOutputCodeUnits(.partialV1))
        let black=try fixed.evaluate(RGB64(0,0,0)),oldBlack=try old.evaluate(RGB64(0,0,0))
        XCTAssertEqual(black.r,0.05*0.85630498533724+0.06256109481916,accuracy:2e-12)
        XCTAssertEqual(oldBlack.r,0.05,accuracy:2e-12)
        XCTAssertGreaterThan(abs(black.r-oldBlack.r),0.05)
        XCTAssertTrue(fixed.planVersion.contains(OutputCodeUnitPolicy.completeV2.rawValue))
        XCTAssertTrue(old.planVersion.contains(OutputCodeUnitPolicy.partialV1.rawValue))
        for tf in [TransferID.linearScene,.rec709LUTCalcLegacy,.srgbLUTCalcLegacy,.djiDLog2,.rec2100PQ] {
            let p=try RGB64(0.01,0.2,1)
            XCTAssertEqual(try TransformPlan(settings:settings(tf)).evaluate(p),try TransformPlan(settings:settings(tf,policy:.partialV1)).evaluate(p))
        }
    }
    func testActualLegacyAdjustmentChains() throws {
        let f=try fixture("output-code-units-legacy-reference.json");var errors:[Double]=[]
        for item in f["cases"] as! [[String:Any]] {
            let plan=try TransformPlan(settings:settings(TransferID(rawValue:item["transfer"] as! String)!,levels:item["levels"] as! Bool,
                knee:item["knee"] as! Bool,limiter:item["limiter"] as! Bool,secondary:item["secondary"] as! Bool,
                both:item["both"] as! Bool,blackGamma:item["blackGamma"] as! Bool))
            for probe in item["probes"] as! [[String:Any]] {
                let x=(probe["inputScene"] as! [String]).map{Double($0)!},y=(probe["outputData"] as! [String]).map{Double($0)!}
                let output=try plan.evaluate(RGB64(x[0],x[1],x[2]))
                for c in 0..<3{let e=abs(output[c]-y[c])/max(1,abs(y[c]));errors.append(e);XCTAssertLessThanOrEqual(e,2e-12,"\(item["transfer"]!)")}
            }
        }
        report("actual legacy Knee/levels/post limiter",errors)
    }
    func testIndependentDecimalAndAllWrappedFullGrids() throws {
        let f=try fixture("output-code-units-independent-reference.json");var scalar:[Double]=[]
        for item in f["cases"] as! [[String:Any]] {
            let tf=TransferID(rawValue:item["transfer"] as! String)!,plan=try TransformPlan(settings:settings(tf,levels:true,limiter:true,secondary:item["secondary"] as! Bool,both:item["both"] as! Bool))
            for probe in item["probes"] as! [[String:Any]] {
                let x=(probe["inputScene"] as! [String]).map{Double($0)!},y=(probe["outputData"] as! [String]).map{Double($0)!}
                let actual=try plan.evaluate(RGB64(x[0],x[1],x[2]))
                for c in 0..<3{let e=abs(actual[c]-y[c])/max(1,abs(y[c]));scalar.append(e);XCTAssertLessThanOrEqual(e,2e-12)}
            }
        }
        report("independent Decimal coupled",scalar)
        for size in [33,65] {
            let grid=try Grid3D(size:size,domain:LUTDomain(min:RGB64(-0.5,-0.5,-0.5),max:RGB64(2,2,2)));var errors:[Double]=[]
            for item in f["axes"] as! [[String:Any]] {
                let tf=TransferID(rawValue:item["transfer"] as! String)!,plan=try TransformPlan(settings:settings(tf,levels:true))
                let expected=(item["size\(size)"] as! [String]).map{Double($0)!}
                for i in 0..<grid.nodeCount {
                    let actual=try plan.evaluate(grid.coordinate(at:i))
                    let indices=[i%size,(i/size)%size,i/(size*size)]
                    for c in 0..<3{let y=expected[indices[c]],e=abs(actual[c]-y)/max(1,abs(y));errors.append(e);XCTAssertLessThanOrEqual(e,2e-12)}
                }
            }
            report("independent 19 wrapped \(size)³",errors)
        }
    }
}

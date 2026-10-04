import Foundation
import XCTest
import LUTCore

final class HighlightGamutContractsTests:XCTestCase {
    private func root()->URL {
        URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private func report(_ name:String,_ errors:[Double]) {
        let n=Double(errors.count),sorted=errors.sorted()
        print("Highlight Gamut \(name) scaled errors: count=\(errors.count), max=\(sorted.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/n)), P99=\(sorted[Int(ceil(0.99*n))-1])")
    }
    func testActualLegacyLinearLogMatricesAndNegativeDomain() throws {
        let f=try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/highlight-gamut-legacy-reference.json"))) as! [String:Any]
        var errors:[Double]=[]
        for item in f["cases"] as! [[String:Any]] {
            let base:ColorPrimaries=item["baseKey"] as! String == "rec2020" ? .rec2020 : .srgb
            let high:ColorSpaceID=item["highKey"] as! String == "rec2020" ? .rec2020 : .srgb
            let settings=try HighlightGamutSettings(highlightSpace:high,
                transition:item["linear"] as! Bool ? .linearReflectance : .logarithmicStops,
                lowStops:item["low"] as! Double,highStops:item["upper"] as! Double)
            let kernel=try LegacyHighlightGamut(settings:settings,basePrimaries:base,adaptation:.cieCAT02)
            let y=(item["workingLuma"] as! [String]).map{Double($0)!}
            for c in 0..<3{XCTAssertEqual(kernel.workingLuma[c],y[c],accuracy:2e-12)}
            for probe in item["probes"] as! [[String:Any]] {
                let x=(probe["input"] as! [String]).map{Double($0)!},expected=(probe["output"] as! [String]).map{Double($0)!}
                let actual=try kernel.evaluateLegacy(RGB64(x[0],x[1],x[2]))
                for c in 0..<3 {
                    let error=abs(actual[c]-expected[c])/max(1,abs(expected[c]))
                    errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
                }
            }
        }
        report("actual legacy",errors)
    }
    func testBoundsEndpointsDisabledAndStage10Replacement() throws {
        for (low,high) in [(0.0,0.0),(1.0,0.0),(.nan,1),(0,.infinity),(-1075,-1074),(1024,1025),(0,Double.leastNonzeroMagnitude)] {
            XCTAssertThrowsError(try HighlightGamutSettings(highlightSpace:.srgb,lowStops:low,highStops:high))
        }
        let h=try HighlightGamutSettings(highlightSpace:.srgb,lowStops:0,highStops:2)
        let kernel=try LegacyHighlightGamut(settings:h,basePrimaries:.rec2020,adaptation:.cieCAT02)
        let work=ColorPrimaries.sonySGamut3Cine,base=try ColorPrimaries.conversion(from:work,to:.rec2020,adaptation:.cieCAT02)
        let alternate=try ColorPrimaries.conversion(from:work,to:.srgb,adaptation:.cieCAT02)
        for x in [-2,0,0.18] {
            let p=try RGB64(x,x,x),v=try kernel.evaluateScene(p)
            for c in 0..<3 {XCTAssertEqual(v[c],try base.applying(to:p)[c],accuracy:2e-12)}
        }
        let p=try RGB64(2,3,4),v=try kernel.evaluateScene(p)
        for c in 0..<3 {XCTAssertEqual(v[c],try alternate.applying(to:p)[c],accuracy:2e-12)}
        let disabled=try LegacyHighlightGamut(settings:HighlightGamutSettings(enabled:false,highlightSpace:.srgb),basePrimaries:.rec2020,adaptation:.cieCAT02)
        XCTAssertEqual(try disabled.evaluateLegacy(p),try base.applying(to:p))
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.sonySGamut3Cine,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,highlightGamut:h)
        let plan=try TransformPlan(settings:s),trace=try plan.trace(p)
        XCTAssertEqual(trace.stages.map(\.id),[1,2,3,4,10,13,19])
        XCTAssertEqual(trace.stages[2].outputSpace,.sonySGamut3Cine)
        for c in 0..<3 {XCTAssertEqual(trace.stages[4].output[c],v[c],accuracy:2e-12)}
        XCTAssertTrue(plan.planVersion.contains("highlight-gamut"))
        XCTAssertThrowsError(try plan.evaluateIndependentChannels(p))
        let same=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,highlightGamut:h)
        let sameTrace=try TransformPlan(settings:same).trace(p)
        XCTAssertEqual(sameTrace.stages[2].outputSpace,.sonySGamut3Cine)
        XCTAssertNotEqual(sameTrace.output,p)
    }
    func testIndependentRationalCATDecimalAndFullGrids() throws {
        let f=try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/highlight-gamut-independent-reference.json"))) as! [String:Any]
        func primaries(_ key:String)->ColorPrimaries {
            switch key {
            case ColorSpaceID.srgb.rawValue:return .srgb
            case ColorSpaceID.acesAP0.rawValue:return .acesAP0
            case ColorSpaceID.proPhoto.rawValue:return .proPhoto
            default:return .rec2020
            }
        }
        var errors:[Double]=[]
        for item in f["cases"] as! [[String:Any]] {
            let s=try HighlightGamutSettings(highlightSpace:ColorSpaceID(rawValue:item["highlight"] as! String)!,
                transition:item["linear"] as! Bool ? .linearReflectance : .logarithmicStops,
                lowStops:item["low"] as! Double,highStops:item["high"] as! Double)
            let kernel=try LegacyHighlightGamut(settings:s,basePrimaries:primaries(item["base"] as! String),
                adaptation:ChromaticAdaptation(rawValue:item["adaptation"] as! String)!)
            for probe in item["probes"] as! [[String:Any]] {
                let x=(probe["input"] as! [String]).map{Double($0)!},y=(probe["output"] as! [String]).map{Double($0)!}
                let actual=try kernel.evaluateLegacy(RGB64(x[0],x[1],x[2]))
                for c in 0..<3 {
                    let error=abs(actual[c]-y[c])/max(1,abs(y[c]));errors.append(error)
                    XCTAssertLessThanOrEqual(error,2e-12)
                }
            }
        }
        report("independent CAT Decimal",errors);errors=[]
        for grid in f["grids"] as! [[String:Any]] {
            let size=grid["size"] as! Int,linear=grid["linear"] as! Bool
            let h=try HighlightGamutSettings(highlightSpace:.srgb,transition:linear ? .linearReflectance : .logarithmicStops,lowStops:-1,highStops:3)
            let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.sonySGamut3Cine,outputSpace:.rec2020,
                inputRange:.data,outputRange:.data,exposureStops:0,highlightGamut:h)
            let plan=try TransformPlan(settings:s),domain=try LUTDomain(min:RGB64(-0.5,-0.5,-0.5),max:RGB64(2,2,2)),g=try Grid3D(size:size,domain:domain)
            let bytes=try Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/\(grid["file"] as! String)"))
            XCTAssertEqual(bytes.count,g.nodeCount*3*8)
            for i in 0..<g.nodeCount {
                let actual=try plan.evaluate(g.coordinate(at:i),sampleIndex:i)
                for c in 0..<3 {
                    let bits=bytes.withUnsafeBytes{$0.loadUnaligned(fromByteOffset:(i*3+c)*8,as:UInt64.self)}
                    let expected=Double(bitPattern:UInt64(littleEndian:bits)),error=abs(actual[c]-expected)/max(1,abs(expected))
                    errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
                }
            }
        }
        report("independent linear/log 33³/65³",errors)
    }
    func testActualLegacyCombinedChain17() throws {
        let bytes=try Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/highlight-gamut-legacy-pipeline17.f64"))
        let cdl=try ASCCDLSettings(slope:RGB64(1.25,0.75,1.5),offset:RGB64(-0.125,0.0625,-0.25),power:RGB64(0.5,1.25,2.5),saturation:0.625)
        let mt=try MultitoneSettings(saturationByStop:(0..<17).map{0.15+Double($0%5)*0.35},tones:[
            MultitoneTone(stop:-3,hue:17,saturation:245),MultitoneTone(stop:0,hue:101,saturation:187),MultitoneTone(stop:4,hue:231,saturation:213)])
        let s=TransformSettings(inputTransfer:.djiDLog2,outputTransfer:.djiDLog2,inputSpace:.djiDGamut2,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:1,ascCDL:cdl,sdrSaturation:try SDRSaturationSettings(),multitone:mt,
            blackGamma:try BlackGammaSettings(upperStops:0,featherStops:2,power:0.5),
            blackHighlight:try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.025,blackLock:true,highReferenceScene:0.72,highMap:0.91,highLock:true),knee:try KneeSettings(startStops:-2,clipStops:4,clipSlope:1,smoothness:0.35,legal:false),highlightGamut:try HighlightGamutSettings(highlightSpace:.srgb,transition:.logarithmicStops,lowStops:-1,highStops:3))
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

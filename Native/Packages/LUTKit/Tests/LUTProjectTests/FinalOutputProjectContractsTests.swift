import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTCatalog

final class FinalOutputProjectContractsTests:XCTestCase {
    func testSchema15VersionOldMigrationStrictFieldsAndHelpers() throws {
        let catalog=try AlgorithmCatalog.builtIn(),final=try FinalOutputSettings(mode:.both,minimumCode10:-1023,maximumCode10:1019,forceBlackLegal:true)
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.gamma22,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,finalOutput:final)
        let current=ProjectManifest(settings:s,cubeSize:33,domain:.unit)
        XCTAssertEqual(current.schemaVersion,ProjectManifest.currentSchema);XCTAssertEqual(current.algorithmVersions["finalOutput"],final.algorithm.rawValue)
        let bytes=try ProjectCodec.encode(current,catalog:catalog)
        XCTAssertEqual(try ProjectCodec.decode(bytes,catalog:catalog),current)
        for schema in 1...14{var raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any];raw["schemaVersion"]=schema
            let old=try JSONSerialization.data(withJSONObject:raw)
            XCTAssertThrowsError(try ProjectCodec.decode(old,catalog:catalog));XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self,from:old))
        }
        let base=ProjectManifest(id:current.id,settings:s.withFinalOutput(nil),cubeSize:33,domain:.unit)
        var raw=try JSONSerialization.jsonObject(with:ProjectCodec.encode(base,catalog:catalog)) as! [String:Any];raw["schemaVersion"]=14
        XCTAssertEqual(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog),base)
        for (key,value) in [("extra","x"),("mode","invalid"),("algorithm","unknown")] {
            raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any];var settings=raw["settings"] as! [String:Any],object=settings["finalOutput"] as! [String:Any]
            object[key]=value;settings["finalOutput"]=object;raw["settings"]=settings
            XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog))
        }
        raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any];var versions=raw["algorithmVersions"] as! [String:String]
        versions["finalOutput"]="unknown";raw["algorithmVersions"]=versions
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)) {XCTAssertEqual($0 as? ProjectError,.algorithmMismatch)}
        var editing=try ProjectEditingSession(new:base,catalog:catalog);try editing.apply(current)
        XCTAssertTrue(editing.undo());XCTAssertNil(editing.current.settings.finalOutput);XCTAssertTrue(editing.redo());XCTAssertEqual(editing.current.settings.finalOutput,final)
        let off=ProjectManifest(settings:s.withFinalOutput(try FinalOutputSettings(enabled:false)),cubeSize:33,domain:.unit)
        XCTAssertEqual(off.algorithmVersions["finalOutput"],final.algorithm.rawValue)
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(off,catalog:catalog),catalog:catalog),off)
        for copy in [s.withInputRange(.video),s.withOutputRange(.video),s.withRangeBitDepth(12),s.withExposureStops(1),s.withAdaptation(.bradford),
            s.withOutput(transfer:.linearScene,space:.srgb),s.withASCCDL(nil),s.withBlackHighlight(nil),s.withBlackGamma(nil),s.withKnee(nil),
            s.withGamutLimiter(nil),s.withHighlightGamut(nil),s.withSDRSaturation(nil),s.withMultitone(nil),s.withDisplayConversion(nil),
            s.withFalseColour(nil),s.withOutputCodeUnits(.partialV1)] {XCTAssertEqual(copy.finalOutput,final)}
    }
}

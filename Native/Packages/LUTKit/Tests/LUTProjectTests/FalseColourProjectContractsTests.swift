import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTCatalog

final class FalseColourProjectContractsTests:XCTestCase {
    func testSchema14NilDefaultsDisabledVersionsAndOldMigration() throws {
        let catalog=try AlgorithmCatalog.builtIn(),fc=try FalseColourSettings(blueStopsBelowGray:nil,yellowStopsBelowClip:nil,redStopsAboveGray:nil)
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.gamma22,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,falseColour:fc)
        let current=ProjectManifest(settings:s,cubeSize:33,domain:.unit)
        XCTAssertEqual(current.schemaVersion,ProjectManifest.currentSchema);XCTAssertEqual(current.algorithmVersions["falseColour"],fc.algorithm.rawValue)
        let bytes=try ProjectCodec.encode(current,catalog:catalog)
        XCTAssertEqual(try ProjectCodec.decode(bytes,catalog:catalog),current)
        for schema in 1...13 {
            var raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any];raw["schemaVersion"]=schema
            let old=try JSONSerialization.data(withJSONObject:raw)
            XCTAssertThrowsError(try ProjectCodec.decode(old,catalog:catalog))
            XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self,from:old))
        }
        let base=ProjectManifest(id:current.id,settings:s.withFalseColour(nil),cubeSize:33,domain:.unit)
        var raw=try JSONSerialization.jsonObject(with:ProjectCodec.encode(base,catalog:catalog)) as! [String:Any];raw["schemaVersion"]=13
        let migrated=try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)
        XCTAssertEqual(migrated,base);XCTAssertEqual(migrated.settings.outputCodeUnits,.completeV2)
        for (key,value) in [("extra","x"),("usage","previewOverlay"),("algorithm","unknown")] {
            raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
            var settings=raw["settings"] as! [String:Any],object=settings["falseColour"] as! [String:Any]
            object[key]=value;settings["falseColour"]=object;raw["settings"]=settings
            XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog))
        }
        raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        var versions=raw["algorithmVersions"] as! [String:String];versions["falseColour"]="unknown";raw["algorithmVersions"]=versions
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)) {
            XCTAssertEqual($0 as? ProjectError,.algorithmMismatch)
        }
        var editing=try ProjectEditingSession(new:base,catalog:catalog);try editing.apply(current)
        XCTAssertTrue(editing.undo());XCTAssertNil(editing.current.settings.falseColour)
        XCTAssertTrue(editing.redo());XCTAssertEqual(editing.current.settings.falseColour,fc)
        let off=ProjectManifest(settings:s.withFalseColour(try FalseColourSettings(enabled:false)),cubeSize:33,domain:.unit)
        XCTAssertEqual(off.algorithmVersions["falseColour"],fc.algorithm.rawValue)
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(off,catalog:catalog),catalog:catalog),off)
        for copy in [s.withInputRange(.video),s.withOutputRange(.video),s.withRangeBitDepth(12),s.withExposureStops(1),
            s.withAdaptation(.bradford),s.withOutput(transfer:.linearScene,space:.srgb),s.withASCCDL(nil),s.withBlackHighlight(nil),
            s.withBlackGamma(nil),s.withKnee(nil),s.withGamutLimiter(nil),s.withHighlightGamut(nil),s.withSDRSaturation(nil),
            s.withMultitone(nil),s.withDisplayConversion(nil),s.withOutputCodeUnits(.partialV1)] {XCTAssertEqual(copy.falseColour,fc)}
    }
}

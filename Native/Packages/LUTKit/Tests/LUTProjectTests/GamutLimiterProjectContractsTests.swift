import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTCatalog

final class GamutLimiterProjectContractsTests:XCTestCase {
    func testSchema11StrictStorageMigrationAndSnapshots() throws {
        let catalog=try AlgorithmCatalog.builtIn(),highlight=try GamutLimiterSettings(mode:.postGamma,linearStops:-2,postLevel:0.85,secondarySpace:.srgb,protectBoth:false)
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,knee:try KneeSettings(),gamutLimiter:highlight)
        let m=ProjectManifest(settings:s,cubeSize:33,domain:.unit),bytes=try ProjectCodec.encode(m,catalog:catalog)
        XCTAssertEqual(m.schemaVersion,ProjectManifest.currentSchema);XCTAssertEqual(try ProjectCodec.decode(bytes,catalog:catalog),m)
        XCTAssertEqual(m.algorithmVersions["gamutLimiter"],highlight.algorithm.rawValue)
        for copied in [s.withInputRange(.video),s.withOutputRange(.video),s.withRangeBitDepth(12),s.withExposureStops(1),s.withAdaptation(.bradford),
            s.withInput(transfer:.djiDLog2,space:.djiDGamut2),s.withOutput(transfer:.rec709LUTCalcLegacy,space:.srgb),
            s.withASCCDL(nil),s.withMultitone(nil),s.withSDRSaturation(nil),s.withBlackGamma(nil),s.withBlackHighlight(nil),s.withKnee(nil),s.withHighlightGamut(nil)] {
            XCTAssertEqual(copied.gamutLimiter,highlight)
        }
        let snapshot=try TransformPlan(settings:s)
        var edit=try ProjectEditingSession(new:m,catalog:catalog)
        try edit.apply(ProjectManifest(id:m.id,settings:s.withGamutLimiter(nil),cubeSize:33,domain:.unit))
        XCTAssertTrue(edit.undo());XCTAssertEqual(edit.current.settings.gamutLimiter,highlight)
        XCTAssertTrue(edit.redo());XCTAssertNil(edit.current.settings.gamutLimiter)
        XCTAssertEqual(snapshot.settings.gamutLimiter,highlight)
        var raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any];raw["schemaVersion"]=10
        let old=try JSONSerialization.data(withJSONObject:raw)
        XCTAssertThrowsError(try ProjectCodec.decode(old,catalog:catalog))
        XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self,from:old))
        let previous=ProjectManifest(id:m.id,settings:s.withGamutLimiter(nil),cubeSize:33,domain:.unit)
        raw=try JSONSerialization.jsonObject(with:ProjectCodec.encode(previous,catalog:catalog)) as! [String:Any];raw["schemaVersion"]=10
        let migrated=try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)
        XCTAssertEqual(migrated.schemaVersion,ProjectManifest.currentSchema);XCTAssertEqual(migrated.settings,previous.settings)
        raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        var settings=raw["settings"] as! [String:Any],hg=settings["gamutLimiter"] as! [String:Any]
        hg["unknown"]=0;settings["gamutLimiter"]=hg;raw["settings"]=settings
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)) {
            XCTAssertEqual($0 as? ProjectError,.unknownField("settings.gamutLimiter.unknown"))
        }
        raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        var versions=raw["algorithmVersions"] as! [String:String];versions["gamutLimiter"]="unknown";raw["algorithmVersions"]=versions
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)) {
            XCTAssertEqual($0 as? ProjectError,.algorithmMismatch)
        }
        let disabled=try GamutLimiterSettings(enabled:false,secondarySpace:.srgb)
        let off=ProjectManifest(settings:s.withGamutLimiter(disabled),cubeSize:33,domain:.unit)
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(off,catalog:catalog),catalog:catalog).settings.gamutLimiter,disabled)
        XCTAssertEqual(off.algorithmVersions["gamutLimiter"],disabled.algorithm.rawValue)
    }
}

import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTCatalog

final class KneeProjectContractsTests:XCTestCase {
    func testSchema9MigrationStrictKeysVersionsAndSnapshots() throws {
        let catalog=try AlgorithmCatalog.builtIn(),knee=try KneeSettings(startStops:-2,clipStops:4,smoothness:0.35,legal:false)
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.djiDLog2,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,blackHighlight:try BlackHighlightSettings(),knee:knee)
        let m=ProjectManifest(settings:s,cubeSize:33,domain:.unit),bytes=try ProjectCodec.encode(m,catalog:catalog)
        XCTAssertEqual(m.schemaVersion,ProjectManifest.currentSchema);XCTAssertEqual(try ProjectCodec.decode(bytes,catalog:catalog),m)
        XCTAssertEqual(m.algorithmVersions["knee"],knee.algorithm.rawValue)
        for copied in [s.withInputRange(.video),s.withOutputRange(.video),s.withExposureStops(1),s.withRangeBitDepth(12),
            s.withAdaptation(.bradford),s.withInput(transfer:.djiDLog2,space:.djiDGamut2),s.withOutput(transfer:.rec709LUTCalcLegacy,space:.rec2020),
            s.withASCCDL(nil),s.withSDRSaturation(nil),s.withMultitone(nil),s.withBlackGamma(nil),s.withBlackHighlight(nil)] {
            XCTAssertEqual(copied.knee,knee)
        }
        let plan=try TransformPlan(settings:s)
        var editor=try ProjectEditingSession(new:m,catalog:catalog)
        try editor.apply(ProjectManifest(id:m.id,settings:s.withKnee(nil),cubeSize:33,domain:.unit))
        XCTAssertTrue(editor.undo());XCTAssertEqual(editor.current.settings.knee,knee)
        XCTAssertTrue(editor.redo());XCTAssertNil(editor.current.settings.knee)
        XCTAssertEqual(plan.settings.knee,knee)
        var raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        raw["schemaVersion"]=8
        let old=try JSONSerialization.data(withJSONObject:raw)
        XCTAssertThrowsError(try ProjectCodec.decode(old,catalog:catalog))
        XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self,from:old))
        let previous=ProjectManifest(id:m.id,settings:s.withKnee(nil),cubeSize:33,domain:.unit)
        var migration=try JSONSerialization.jsonObject(with:ProjectCodec.encode(previous,catalog:catalog)) as! [String:Any]
        migration["schemaVersion"]=8
        let migrated=try ProjectCodec.decode(JSONSerialization.data(withJSONObject:migration),catalog:catalog)
        XCTAssertEqual(migrated.schemaVersion,ProjectManifest.currentSchema);XCTAssertEqual(migrated.settings,previous.settings)
        raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        var settings=raw["settings"] as! [String:Any],payload=settings["knee"] as! [String:Any]
        payload["unknown"]=0;settings["knee"]=payload;raw["settings"]=settings
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)) {
            XCTAssertEqual($0 as? ProjectError,.unknownField("settings.knee.unknown"))
        }
        raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        var versions=raw["algorithmVersions"] as! [String:String];versions["knee"]="unknown";raw["algorithmVersions"]=versions
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)) {
            XCTAssertEqual($0 as? ProjectError,.algorithmMismatch)
        }
        let disabled=try KneeSettings(enabled:false),off=ProjectManifest(settings:s.withKnee(disabled),cubeSize:33,domain:.unit)
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(off,catalog:catalog),catalog:catalog).settings.knee,disabled)
        XCTAssertEqual(off.algorithmVersions["knee"],disabled.algorithm.rawValue)
    }
}

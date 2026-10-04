import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTCatalog

final class BlackHighlightProjectContractsTests:XCTestCase {
    func testSchema8ExactStorageMigrationVersionAndLockSnapshots() throws {
        let catalog=try AlgorithmCatalog.builtIn()
        let level=try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.025,blackLock:true,highReferenceScene:0.72,highMap:0.91,highLock:true)
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.rec709LUTCalcLegacy,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,ascCDL:try ASCCDLSettings(),sdrSaturation:try SDRSaturationSettings(enabled:false),
            multitone:try MultitoneSettings(enabled:false),blackGamma:try BlackGammaSettings(),blackHighlight:level)
        let m=ProjectManifest(settings:s,cubeSize:33,domain:.unit),bytes=try ProjectCodec.encode(m,catalog:catalog)
        XCTAssertEqual(m.schemaVersion,ProjectManifest.currentSchema);XCTAssertEqual(try ProjectCodec.decode(bytes,catalog:catalog),m)
        XCTAssertEqual(m.algorithmVersions["blackHighlight"],BlackHighlightAlgorithm.lutcalcLegalAffineV1.rawValue)
        let snapshot=try TransformPlan(settings:s)
        for edited in [s.withInputRange(.video),s.withOutputRange(.video),s.withExposureStops(1),s.withRangeBitDepth(12),s.withAdaptation(.bradford),
            s.withASCCDL(nil),s.withSDRSaturation(nil),s.withMultitone(nil),s.withBlackGamma(nil),s.withInput(transfer:.djiDLog2,space:.djiDGamut2),
            s.withOutput(transfer:.rec2100HLG,space:.rec2020)] {XCTAssertEqual(edited.blackHighlight,level)}
        var editor=try ProjectEditingSession(new:m,catalog:catalog)
        try editor.apply(ProjectManifest(id:m.id,settings:s.withBlackHighlight(nil),cubeSize:33,domain:.unit))
        XCTAssertTrue(editor.undo());XCTAssertEqual(editor.current.settings.blackHighlight,level)
        XCTAssertTrue(editor.redo());XCTAssertNil(editor.current.settings.blackHighlight)
        XCTAssertEqual(snapshot.settings.blackHighlight,level)
        var raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any];raw["schemaVersion"]=7
        let old=try JSONSerialization.data(withJSONObject:raw)
        XCTAssertThrowsError(try ProjectCodec.decode(old,catalog:catalog))
        XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self,from:old))
        let oldManifest=ProjectManifest(id:m.id,settings:s.withBlackHighlight(nil),cubeSize:33,domain:.unit)
        var legacy=try JSONSerialization.jsonObject(with:ProjectCodec.encode(oldManifest,catalog:catalog)) as! [String:Any]
        legacy["schemaVersion"]=7
        let migrated=try ProjectCodec.decode(JSONSerialization.data(withJSONObject:legacy),catalog:catalog)
        XCTAssertEqual(migrated.schemaVersion,ProjectManifest.currentSchema);XCTAssertEqual(migrated.settings,oldManifest.settings)
        raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        var settings=raw["settings"] as! [String:Any],levels=settings["blackHighlight"] as! [String:Any]
        levels["unknown"]=1;settings["blackHighlight"]=levels;raw["settings"]=settings
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)){
            XCTAssertEqual($0 as? ProjectError,.unknownField("settings.blackHighlight.unknown"))
        }
        raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        var versions=raw["algorithmVersions"] as! [String:String];versions["blackHighlight"]="unknown";raw["algorithmVersions"]=versions
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)){
            XCTAssertEqual($0 as? ProjectError,.algorithmMismatch)
        }
        let disabled=try BlackHighlightSettings(enabled:false,blackLevel:0.03,blackLock:true)
        let disabledManifest=ProjectManifest(settings:s.withBlackHighlight(disabled),cubeSize:33,domain:.unit)
        let decoded=try ProjectCodec.decode(ProjectCodec.encode(disabledManifest,catalog:catalog),catalog:catalog)
        XCTAssertEqual(decoded.settings.blackHighlight,disabled)
        XCTAssertEqual(decoded.algorithmVersions["blackHighlight"],disabled.algorithm.rawValue)
    }
}

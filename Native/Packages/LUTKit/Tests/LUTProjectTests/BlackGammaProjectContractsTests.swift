import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTCatalog

final class BlackGammaProjectContractsTests: XCTestCase {
    func testSchema7ExactRoundtripMigrationStrictKeysAndImmutableSnapshots() throws {
        let catalog=try AlgorithmCatalog.builtIn(), gamma=try BlackGammaSettings(upperStops:-1.37,featherStops:3.17,power:0.73)
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.rec709LUTCalcLegacy,inputSpace:.rec2020,
            outputSpace:.rec2020,inputRange:.data,outputRange:.data,exposureStops:0,
            ascCDL:try ASCCDLSettings(),sdrSaturation:try SDRSaturationSettings(enabled:false),
            multitone:try MultitoneSettings(enabled:false),blackGamma:gamma)
        let m=ProjectManifest(settings:s,cubeSize:33,domain:.unit)
        let bytes=try ProjectCodec.encode(m,catalog:catalog)
        XCTAssertEqual(m.schemaVersion,ProjectManifest.currentSchema);XCTAssertEqual(try ProjectCodec.decode(bytes,catalog:catalog),m)
        XCTAssertEqual(m.algorithmVersions["blackGamma"],BlackGammaAlgorithm.lutcalcOutputEncodedStableV1.rawValue)
        let snapshot=try TransformPlan(settings:s)
        for change in [s.withInputRange(.video),s.withOutputRange(.video),s.withExposureStops(1),s.withRangeBitDepth(12),
            s.withAdaptation(.bradford),s.withASCCDL(nil),s.withSDRSaturation(nil),s.withMultitone(nil),
            s.withInput(transfer:.djiDLog2,space:.djiDGamut2),s.withOutput(transfer:.rec2100HLG,space:.rec2020)]{
            XCTAssertEqual(change.blackGamma,gamma)
        }
        var editor=try ProjectEditingSession(new:m,catalog:catalog)
        try editor.apply(ProjectManifest(id:m.id,settings:s.withBlackGamma(nil),cubeSize:33,domain:.unit))
        XCTAssertTrue(editor.undo());XCTAssertEqual(editor.current.settings.blackGamma,gamma)
        XCTAssertTrue(editor.redo());XCTAssertNil(editor.current.settings.blackGamma)
        XCTAssertEqual(snapshot.settings.blackGamma,gamma)
        var raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        raw["schemaVersion"]=6
        let old=try JSONSerialization.data(withJSONObject:raw)
        XCTAssertThrowsError(try ProjectCodec.decode(old,catalog:catalog))
        XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self,from:old))
        let oldManifest=ProjectManifest(id:m.id,settings:s.withBlackGamma(nil),cubeSize:33,domain:.unit)
        var legacy=try JSONSerialization.jsonObject(with:ProjectCodec.encode(oldManifest,catalog:catalog)) as! [String:Any]
        legacy["schemaVersion"]=6
        let migrated=try ProjectCodec.decode(JSONSerialization.data(withJSONObject:legacy),catalog:catalog)
        XCTAssertEqual(migrated.schemaVersion,ProjectManifest.currentSchema);XCTAssertEqual(migrated.settings,oldManifest.settings)
        raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        var setting=raw["settings"] as! [String:Any],g=setting["blackGamma"] as! [String:Any]
        g["unknown"]=1;setting["blackGamma"]=g;raw["settings"]=setting
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)){
            XCTAssertEqual($0 as? ProjectError,.unknownField("settings.blackGamma.unknown"))
        }
        raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        var versions=raw["algorithmVersions"] as! [String:String];versions["blackGamma"]="unknown";raw["algorithmVersions"]=versions
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)){
            XCTAssertEqual($0 as? ProjectError,.algorithmMismatch)
        }
        let invalid=Data("{\"algorithm\":\"lutcalc.black-gamma-output-encoded.v1\",\"enabled\":true,\"upperStops\":0,\"featherStops\":0,\"power\":0}".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(BlackGammaSettings.self,from:invalid))
    }
}

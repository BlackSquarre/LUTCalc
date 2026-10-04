import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTCatalog

final class MultitoneProjectContractsTests: XCTestCase {
    func testSchema6MigrationStrictFieldsAndSnapshots() throws {
        let catalog=try AlgorithmCatalog.builtIn()
        let mt=try MultitoneSettings(saturationByStop:(0..<17).map{Double($0)/8},
            tones:[MultitoneTone(stop:-2,hue:12,saturation:231),MultitoneTone(stop:3,hue:245,saturation:151)])
        let settings=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,
            outputSpace:.rec2020,inputRange:.data,outputRange:.data,exposureStops:0,
            ascCDL:try ASCCDLSettings(),sdrSaturation:try SDRSaturationSettings(),multitone:mt)
        let m=ProjectManifest(settings:settings,cubeSize:33,domain:.unit)
        let bytes=try ProjectCodec.encode(m,catalog:catalog)
        XCTAssertEqual(m.schemaVersion,ProjectManifest.currentSchema);XCTAssertEqual(try ProjectCodec.decode(bytes,catalog:catalog),m)
        XCTAssertEqual(m.algorithmVersions["multitone"],MultitoneAlgorithm.lutcalcWorkingV1.rawValue)
        let snapshot=try TransformPlan(settings:settings)
        for update in [settings.withInputRange(.video),settings.withOutputRange(.video),settings.withRangeBitDepth(12),
            settings.withExposureStops(1),settings.withAdaptation(.bradford),settings.withASCCDL(nil),settings.withSDRSaturation(nil),
            settings.withInput(transfer:.djiDLog2,space:.djiDGamut2),settings.withOutput(transfer:.rec2100HLG,space:.rec2020)] {
            XCTAssertEqual(update.multitone,mt)
        }
        var edit=try ProjectEditingSession(new:m,catalog:catalog)
        try edit.apply(ProjectManifest(id:m.id,settings:settings.withMultitone(nil),cubeSize:33,domain:.unit))
        XCTAssertTrue(edit.undo());XCTAssertEqual(edit.current.settings.multitone,mt)
        XCTAssertTrue(edit.redo());XCTAssertNil(edit.current.settings.multitone);XCTAssertEqual(snapshot.settings.multitone,mt)
        var raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        raw["schemaVersion"]=5
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog))
        XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self,from:JSONSerialization.data(withJSONObject:raw)))
        let legacy=ProjectManifest(settings:settings.withMultitone(nil),cubeSize:33,domain:.unit)
        var old=try JSONSerialization.jsonObject(with:ProjectCodec.encode(legacy,catalog:catalog)) as! [String:Any]
        old["schemaVersion"]=5
        let migrated=try ProjectCodec.decode(JSONSerialization.data(withJSONObject:old),catalog:catalog)
        XCTAssertEqual(migrated.schemaVersion,ProjectManifest.currentSchema);XCTAssertNil(migrated.settings.multitone)
        XCTAssertEqual(migrated.settings.ascCDL,settings.ascCDL);XCTAssertEqual(migrated.settings.sdrSaturation,settings.sdrSaturation)
        raw["schemaVersion"]=6
        var s=raw["settings"] as! [String:Any], object=s["multitone"] as! [String:Any]
        var tones=object["tones"] as! [[String:Any]];tones[0]["unknown"]=0
        object["tones"]=tones;s["multitone"]=object;raw["settings"]=s
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)) {
            XCTAssertEqual($0 as? ProjectError,.unknownField("settings.multitone.tones[0].unknown"))
        }
        raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        var versions=raw["algorithmVersions"] as! [String:String];versions["multitone"]="unknown";raw["algorithmVersions"]=versions
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)) {
            XCTAssertEqual($0 as? ProjectError,.algorithmMismatch)
        }
    }
}

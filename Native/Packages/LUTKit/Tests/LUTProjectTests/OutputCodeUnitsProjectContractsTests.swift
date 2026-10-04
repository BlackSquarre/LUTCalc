import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTCatalog

final class OutputCodeUnitsProjectContractsTests:XCTestCase {
    func testSchema12ExplicitIdentityOldSchema11ReplaysPartialAndStrictRejection() throws {
        let catalog=try AlgorithmCatalog.builtIn()
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.gamma22,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,
            blackHighlight:try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.05,blackLock:true,highMap:0.85,highLock:true))
        let current=ProjectManifest(settings:s,cubeSize:33,domain:.unit)
        XCTAssertEqual(current.schemaVersion,ProjectManifest.currentSchema)
        XCTAssertEqual(current.algorithmVersions["outputCodeUnits"],OutputCodeUnitPolicy.completeV2.rawValue)
        let bytes=try ProjectCodec.encode(current,catalog:catalog)
        XCTAssertEqual(try ProjectCodec.decode(bytes,catalog:catalog),current)
        var raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        raw["schemaVersion"]=11
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog))
        XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self,from:JSONSerialization.data(withJSONObject:raw)))
        var settings=raw["settings"] as! [String:Any],versions=raw["algorithmVersions"] as! [String:String]
        settings.removeValue(forKey:"outputCodeUnits");versions.removeValue(forKey:"outputCodeUnits")
        raw["settings"]=settings;raw["algorithmVersions"]=versions
        let oldBytes=try JSONSerialization.data(withJSONObject:raw),migrated=try ProjectCodec.decode(oldBytes,catalog:catalog)
        XCTAssertEqual(migrated.schemaVersion,ProjectManifest.currentSchema)
        XCTAssertEqual(migrated.settings.outputCodeUnits,.partialV1)
        XCTAssertEqual(migrated.algorithmVersions["outputCodeUnits"],OutputCodeUnitPolicy.partialV1.rawValue)
        XCTAssertEqual(try JSONDecoder().decode(ProjectManifest.self,from:oldBytes),migrated)
        let oldPlan=try TransformPlan(settings:migrated.settings),newPlan=try TransformPlan(settings:s)
        XCTAssertEqual(try oldPlan.evaluate(RGB64(0,0,0)).r,0.05,accuracy:2e-12)
        XCTAssertGreaterThan(try newPlan.evaluate(RGB64(0,0,0)).r,0.1)
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(migrated,catalog:catalog),catalog:catalog),migrated)
        let corrected=ProjectManifest(id:migrated.id,settings:migrated.settings.withOutputCodeUnits(.completeV2),cubeSize:33,domain:.unit)
        var edit=try ProjectEditingSession(new:migrated,catalog:catalog);try edit.apply(corrected)
        XCTAssertTrue(edit.undo());XCTAssertEqual(edit.current.settings.outputCodeUnits,.partialV1)
        XCTAssertTrue(edit.redo());XCTAssertEqual(edit.current.settings.outputCodeUnits,.completeV2)
        for copied in [migrated.settings.withOutput(transfer:.parameterizedGamma,space:.rec2020),migrated.settings.withInputRange(.video),
            migrated.settings.withOutputRange(.video),migrated.settings.withRangeBitDepth(12),migrated.settings.withExposureStops(1),
            migrated.settings.withAdaptation(.bradford),migrated.settings.withASCCDL(nil),migrated.settings.withBlackHighlight(nil),
            migrated.settings.withBlackGamma(nil),migrated.settings.withKnee(nil),migrated.settings.withGamutLimiter(nil),
            migrated.settings.withHighlightGamut(nil),migrated.settings.withSDRSaturation(nil),migrated.settings.withMultitone(nil)] {
            XCTAssertEqual(copied.outputCodeUnits,.partialV1)
        }
        XCTAssertEqual(oldPlan.settings.outputCodeUnits,.partialV1)
        raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any];settings=raw["settings"] as! [String:Any]
        settings["outputCodeUnits"]="unknown";raw["settings"]=settings
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog))
        raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any];versions=raw["algorithmVersions"] as! [String:String]
        versions["outputCodeUnits"]=OutputCodeUnitPolicy.partialV1.rawValue;raw["algorithmVersions"]=versions
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)) {
            XCTAssertEqual($0 as? ProjectError,.algorithmMismatch)
        }
        raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any];settings=raw["settings"] as! [String:Any]
        settings.removeValue(forKey:"outputCodeUnits");raw["settings"]=settings
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog))
    }
}

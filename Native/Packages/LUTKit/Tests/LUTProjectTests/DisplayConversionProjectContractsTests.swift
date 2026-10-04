import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTCatalog

final class DisplayConversionProjectContractsTests:XCTestCase {
    func testSchema13RoundtripMigrationStrictFieldsAndVersion() throws {
        let catalog=try AlgorithmCatalog.builtIn()
        let display=DisplayConversionSettings(baseCurve:.bbc04,outputCurve:.gamma22,baseGamut:.p3D60,outputGamut:.proPhoto)
        let s=TransformSettings(inputTransfer:.linearScene,outputTransfer:.gamma22,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,displayConversion:display)
        let current=ProjectManifest(settings:s,cubeSize:33,domain:.unit)
        XCTAssertEqual(current.schemaVersion,ProjectManifest.currentSchema)
        XCTAssertEqual(current.algorithmVersions["displayConversion"],display.algorithm.rawValue)
        let bytes=try ProjectCodec.encode(current,catalog:catalog)
        XCTAssertEqual(try ProjectCodec.decode(bytes,catalog:catalog),current)
        for schema in 1...12 {
            var old=try JSONSerialization.jsonObject(with:bytes) as! [String:Any];old["schemaVersion"]=schema
            let oldBytes=try JSONSerialization.data(withJSONObject:old)
            XCTAssertThrowsError(try ProjectCodec.decode(oldBytes,catalog:catalog))
            XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self,from:oldBytes))
        }
        let without=ProjectManifest(id:current.id,settings:s.withDisplayConversion(nil),cubeSize:33,domain:.unit)
        let plain=try ProjectCodec.encode(without,catalog:catalog)
        var old=try JSONSerialization.jsonObject(with:plain) as! [String:Any];old["schemaVersion"]=12
        let migrated=try ProjectCodec.decode(JSONSerialization.data(withJSONObject:old),catalog:catalog)
        XCTAssertEqual(migrated.settings.outputCodeUnits,.completeV2);XCTAssertNil(migrated.settings.displayConversion)
        XCTAssertEqual(migrated,without)
        let oldBase=ProjectManifest(settings:TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,
            inputSpace:.rec2020,outputSpace:.rec2020,inputRange:.data,outputRange:.data,exposureStops:0),cubeSize:33,domain:.unit)
        for schema in 1...12 {
            var raw=try JSONSerialization.jsonObject(with:ProjectCodec.encode(oldBase,catalog:catalog)) as! [String:Any]
            raw["schemaVersion"]=schema
            if schema==1{raw.removeValue(forKey:"assetRoles")}
            XCTAssertEqual(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog),oldBase)
        }
        for (key,value) in [("unexpected","x"),("algorithm","unknown"),("baseCurve","unknown"),("outputGamut","unknown")] {
            var raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
            var settings=raw["settings"] as! [String:Any],d=settings["displayConversion"] as! [String:Any]
            d[key]=value;settings["displayConversion"]=d;raw["settings"]=settings
            XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog))
        }
        var raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any],versions=raw["algorithmVersions"] as! [String:String]
        versions["displayConversion"]="unknown";raw["algorithmVersions"]=versions
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)) {
            XCTAssertEqual($0 as? ProjectError,.algorithmMismatch)
        }
        let disabled=s.withDisplayConversion(DisplayConversionSettings(enabled:false,baseCurve:.bbc04,outputCurve:.gamma22,baseGamut:.p3D60,outputGamut:.proPhoto))
        let off=ProjectManifest(settings:disabled,cubeSize:33,domain:.unit)
        XCTAssertEqual(off.algorithmVersions["displayConversion"],display.algorithm.rawValue)
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(off,catalog:catalog),catalog:catalog),off)
        var editing=try ProjectEditingSession(new:without,catalog:catalog);try editing.apply(current)
        XCTAssertTrue(editing.undo());XCTAssertNil(editing.current.settings.displayConversion)
        XCTAssertTrue(editing.redo());XCTAssertEqual(editing.current.settings.displayConversion,display)
        for copy in [s.withInputRange(.video),s.withOutputRange(.video),s.withRangeBitDepth(12),s.withExposureStops(1),
            s.withAdaptation(.bradford),s.withOutput(transfer:.linearScene,space:.srgb),s.withASCCDL(nil),
            s.withBlackHighlight(nil),s.withBlackGamma(nil),s.withKnee(nil),s.withGamutLimiter(nil),
            s.withHighlightGamut(nil),s.withSDRSaturation(nil),s.withMultitone(nil),s.withOutputCodeUnits(.partialV1)] {
            XCTAssertEqual(copy.displayConversion,display)
        }
    }
}

import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTCatalog

final class SDRSaturationProjectContractsTests: XCTestCase {
    private func manifest(_ sat: SDRSaturationSettings?) throws -> ProjectManifest {
        ProjectManifest(settings:TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,
            inputSpace:.rec2020,outputSpace:.rec2020,inputRange:.data,outputRange:.data,
            exposureStops:0,ascCDL:try ASCCDLSettings(),sdrSaturation:sat),cubeSize:33,domain:.unit)
    }
    func testSchema5VersionSnapshotUndoAndAllHelpers() throws {
        let catalog=try AlgorithmCatalog.builtIn(), sat=try SDRSaturationSettings(gamma:1.23456789012345)
        let m=try manifest(sat), bytes=try ProjectCodec.encode(m,catalog:catalog)
        XCTAssertEqual(m.schemaVersion,ProjectManifest.currentSchema)
        XCTAssertEqual(m.algorithmVersions["sdrSaturation"],SDRSaturationAlgorithm.lutcalcOutputLinearV1.rawValue)
        XCTAssertEqual(try ProjectCodec.decode(bytes,catalog:catalog),m)
        let old=m.settings, snapshot=try TransformPlan(settings:old)
        for updated in [old.withInputRange(.video),old.withOutputRange(.video),old.withRangeBitDepth(12),
            old.withExposureStops(0.5),old.withAdaptation(.bradford),old.withASCCDL(nil),
            old.withInput(transfer:.djiDLog2,space:.djiDGamut2),old.withOutput(transfer:.rec2100HLG,space:.rec2020)] {
            XCTAssertEqual(updated.sdrSaturation,sat)
        }
        var edit=try ProjectEditingSession(new:m,catalog:catalog)
        try edit.apply(ProjectManifest(id:m.id,settings:old.withSDRSaturation(nil),cubeSize:m.cubeSize,domain:m.domain));XCTAssertTrue(edit.undo());XCTAssertEqual(edit.current.settings.sdrSaturation,sat)
        XCTAssertTrue(edit.redo());XCTAssertNil(edit.current.settings.sdrSaturation)
        XCTAssertEqual(snapshot.settings.sdrSaturation,sat)
    }
    func testSchema4MigrationForbiddenNewFieldUnknownKeysAndMismatch() throws {
        let catalog=try AlgorithmCatalog.builtIn()
        let original=try ProjectCodec.encode(manifest(nil),catalog:catalog)
        var raw=try JSONSerialization.jsonObject(with:original) as! [String:Any]
        raw["schemaVersion"]=4
        let old=try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)
        XCTAssertEqual(old.schemaVersion,ProjectManifest.currentSchema);XCTAssertNil(old.settings.sdrSaturation)
        XCTAssertNotNil(old.settings.ascCDL)
        let bytes=try ProjectCodec.encode(manifest(SDRSaturationSettings()),catalog:catalog)
        raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        raw["schemaVersion"]=4
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog))
        XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self,from:JSONSerialization.data(withJSONObject:raw)))
        raw["schemaVersion"]=5
        var settings=raw["settings"] as! [String:Any], sat=settings["sdrSaturation"] as! [String:Any]
        sat["unknown"]=0;settings["sdrSaturation"]=sat;raw["settings"]=settings
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)) {
            XCTAssertEqual($0 as? ProjectError,.unknownField("settings.sdrSaturation.unknown"))
        }
        sat.removeValue(forKey:"unknown");sat["gamma"]=0
        settings["sdrSaturation"]=sat;raw["settings"]=settings
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog))
        raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        var versions=raw["algorithmVersions"] as! [String:String];versions["sdrSaturation"]="unverified";raw["algorithmVersions"]=versions
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)) {
            XCTAssertEqual($0 as? ProjectError,.algorithmMismatch)
        }
        let disabled=try manifest(SDRSaturationSettings(enabled:false))
        XCTAssertNotNil(disabled.algorithmVersions["sdrSaturation"])
    }
}

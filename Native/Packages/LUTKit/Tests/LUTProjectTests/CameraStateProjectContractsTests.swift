import Foundation
import XCTest
import LUTCore
import LUTCatalog
import LUTProject

final class CameraStateProjectContractsTests:XCTestCase {
    func testFrozenSchema18DiskReadDoesNotInventCameraOrRewriteBytes()throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let before=try Data(contentsOf:root.appendingPathComponent("tests/fixtures/native-contracts/camera-state-schema18-original.json"))
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("camera-schema18-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:folder)}
        let path=folder.appendingPathComponent("manifest.json");try before.write(to:path)
        let session=try ProjectEditingSession(opening:folder,catalog:AlgorithmCatalog.builtIn())
        XCTAssertEqual(session.current.schemaVersion,ProjectManifest.currentSchema);XCTAssertNil(session.current.settings.cameraExposure)
        XCTAssertEqual(session.current.settings.inputLogC?.exposureIndex,800)
        let after=try Data(contentsOf:path);XCTAssertEqual(before,after)
        if let target=ProcessInfo.processInfo.environment["LUTCALC_CAMERA_ARTIFACT_DIR"] {
            let retained=URL(fileURLWithPath:target).appendingPathComponent(folder.lastPathComponent)
            try FileManager.default.createDirectory(at:retained,withIntermediateDirectories:true)
            try before.write(to:retained.appendingPathComponent("manifest-before.json"));try after.write(to:retained.appendingPathComponent("manifest-after.json"))
            try FileManager.default.copyItem(at:folder,to:retained.appendingPathComponent("schema18.lutcalc"))
        }
    }
    func testSchema19StrictCameraStateIdentityAndHistoricalRejection() throws {
        let catalog=try AlgorithmCatalog.builtIn()
        let base=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0)
        let camera=try CameraExposureSettings.fromRecordedISO(profileID:"camera.sony.venice.v1",recordedISO:1501,inputPolicy:.explicitCurrentInput)
        let s=try CameraPresetResolver.applying(camera,to:base)
        let doc=ProjectManifest(settings:s,cubeSize:33,domain:.unit)
        XCTAssertEqual(doc.schemaVersion,ProjectManifest.currentSchema);XCTAssertEqual(doc.algorithmVersions["cameraExposure"],camera.algorithm)
        let bytes=try ProjectCodec.encode(doc,catalog:catalog)
        XCTAssertEqual(try ProjectCodec.decode(bytes,catalog:catalog),doc)
        for schema in 1...18 {
            var raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any];raw["schemaVersion"]=schema
            let invalid=try JSONSerialization.data(withJSONObject:raw)
            XCTAssertThrowsError(try ProjectCodec.decode(invalid,catalog:catalog))
            XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self,from:invalid))
        }
        for (key,value) in [("algorithm","unknown"),("profileID","unknown"),("source","unknown"),("inputPolicy","unknown")] {
            var raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
            var settings=raw["settings"] as! [String:Any],payload=settings["cameraExposure"] as! [String:Any]
            payload[key]=value;settings["cameraExposure"]=payload;raw["settings"]=settings
            XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog))
        }
        var raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        var settings=raw["settings"] as! [String:Any];settings["exposureStops"]=0;raw["settings"]=settings
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog))
    }
}

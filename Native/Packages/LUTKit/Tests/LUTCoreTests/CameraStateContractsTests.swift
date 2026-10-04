import Foundation
import XCTest
@testable import LUTCore
import LUTCatalog

final class CameraStateContractsTests: XCTestCase {
    private func root() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private func reference() throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(contentsOf: root().appendingPathComponent("tests/fixtures/native-contracts/camera-state-independent.json"))) as! [String: Any]
    }
    func testAll66StableProfilesAndSourceMetadataArePreserved() throws {
        let raw=try reference(),profiles=CameraCatalog.profiles
        XCTAssertEqual(profiles.count,66); XCTAssertEqual(Set(profiles.map(\.id)).count,66)
        for item in raw["profiles"] as! [[String:Any]] {
            let p=try XCTUnwrap(CameraCatalog.profile(id:item["id"] as! String))
            XCTAssertEqual(p.make,item["make"] as? String); XCTAssertEqual(p.model,item["model"] as? String)
            XCTAssertEqual(p.baseISO,item["iso"] as? Int); XCTAssertEqual(p.behavior.rawValue,item["type"] as? Int)
            XCTAssertEqual(p.legacyGamma,item["defgamma"] as? String); XCTAssertEqual(p.legacyGamut,item["defgamut"] as? String)
            XCTAssertEqual(p.blackStops,item["bclip"] as! Double); XCTAssertEqual(p.clipStops,item["wclip"] as! Double)
            XCTAssertFalse(p.source.isEmpty)
        }
        XCTAssertNil(CameraCatalog.profile(id:"camera.unknown.v1"))
        let generic=try XCTUnwrap(CameraCatalog.profile(id:"camera.generic.v1"))
        XCTAssertNil(generic.reportedNativeISO); XCTAssertEqual(generic.baseISO,800)
        XCTAssertEqual(profiles.filter{$0.behavior == .cineEI}.count,17)
        XCTAssertEqual(profiles.filter{$0.behavior == .curveParameters}.count,1)
    }
    func testRecordedISOAndRationalBinaryRoundingAgainstIndependentReference() throws {
        let raw=try reference();var errors:[Double]=[]
        for item in raw["roundCases"] as! [[String:String]] {
            let x=Double(item["input"]!)!,y=Double(item["output"]!)!
            XCTAssertEqual(CameraExposureMath.legacyFourDecimalStop(x).bitPattern,y.bitPattern)
        }
        for item in raw["cases"] as! [[String:Any]] {
            let state=try CameraExposureSettings.fromRecordedISO(profileID:item["profileID"] as! String,
                recordedISO:item["recordedISO"] as! Int,previousManualStops:item["previousManualStops"] as! Double,inputPolicy:.explicitCurrentInput)
            let actual=[state.stopCorrection,try state.gain,try state.blackScene,try state.clipScene]
            for (i,key) in ["stop","gain","black","clip"].enumerated() {
                let expected=Double(item[key] as! String)!,error=abs(actual[i]-expected)/max(1,abs(expected))
                errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
            }
        }
        let sorted=errors.sorted()
        print("Camera state Decimal: count=\(errors.count), max=\(sorted.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/Double(errors.count))), P99=\(sorted[Int(ceil(Double(errors.count)*0.99))-1])")
        let venice=try CameraExposureSettings.fromRecordedISO(profileID:"camera.sony.venice.v1",recordedISO:1501,inputPolicy:.explicitCurrentInput)
        XCTAssertEqual(venice.stopCorrection,1.5859);XCTAssertGreaterThan(abs(try venice.gain-3.002),1e-6)
        XCTAssertThrowsError(try CameraExposureSettings.fromRecordedISO(profileID:venice.profileID,recordedISO:0,inputPolicy:.explicitCurrentInput))
        XCTAssertThrowsError(try CameraExposureSettings.fromRecordedISO(profileID:"unknown",recordedISO:800,inputPolicy:.explicitCurrentInput))
    }
    func testManualShiftISOParameterPropagationBatchOverrideAndDefaultsCannotFallback() throws {
        let base=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0)
        let cine=try CameraExposureSettings.fromRecordedISO(profileID:"camera.sony.pxw-fx9.v1",recordedISO:2401,inputPolicy:.explicitCurrentInput)
        let manual=try cine.changingStopCorrection(0.125)
        XCTAssertEqual(manual.recordedISO,Int((800*pow(2,0.125)).rounded(.toNearestOrAwayFromZero)))
        let applied=try CameraPresetResolver.applying(cine,to:base)
        XCTAssertEqual(applied.cameraExposure,cine);XCTAssertEqual(applied.exposureStops,cine.stopCorrection)
        let replaced=applied.withExposureStops(1.0/3)
        XCTAssertEqual(replaced.cameraExposure?.recordedISO,cine.recordedISO)
        XCTAssertEqual(replaced.cameraExposure?.source,.batchOverride);XCTAssertEqual(replaced.exposureStops,1.0/3)
        XCTAssertEqual(try TransformPlan(settings:replaced).evaluate(RGB64(0.18,0.36,-0.1)).r,0.18*pow(2,1.0/3),accuracy:2e-12)
        XCTAssertTrue(try TransformPlan(settings:applied).planVersion.contains(cine.profileID))
        let logC=try ARRILogCSceneSettings(algorithm:.sup3Published,exposureIndex:800)
        let pair=base.withInput(transfer:.arriLogCSUP3Scene,space:.arriWideGamut3).withInputLogC(logC)
            .withOutput(transfer:.arriLogCSUP3Scene,space:.arriWideGamut3).withOutputLogC(logC)
        let arri=try CameraExposureSettings.fromRecordedISO(profileID:"camera.arri.alexa-amira.v1",recordedISO:1600,
            previousManualStops:0.125,inputPolicy:.explicitCurrentInput)
        let updated=try CameraPresetResolver.applying(arri,to:pair)
        XCTAssertEqual(updated.inputLogC?.exposureIndex,1600);XCTAssertEqual(updated.outputLogC?.exposureIndex,1600)
        XCTAssertEqual(updated.exposureStops,0.125)
        for id in ["camera.sony.venice.v1","camera.nikon.d800.v1","camera.red.epic-dragon.v1"] {
            XCTAssertThrowsError(try CameraPresetResolver.applying(CameraExposureSettings.selecting(profileID:id,inputPolicy:.publishedAvailableDefaults),to:base))
        }
        let defaults=try CameraPresetResolver.applying(CameraExposureSettings.selecting(profileID:"camera.sony.pxw-fx9.v1",inputPolicy:.legacyAvailableDefaults),to:base)
        XCTAssertEqual(defaults.inputTransfer,.sonySLog3LUTCalcLegacy);XCTAssertEqual(defaults.inputSpace,.sonySGamut3Cine)
        let pub=try CameraPresetResolver.applying(CameraExposureSettings.selecting(profileID:"camera.arri.alexa-amira.v1",inputPolicy:.publishedAvailableDefaults),to:base)
        XCTAssertEqual(pub.inputTransfer,.arriLogCSUP3Scene);XCTAssertEqual(pub.inputSpace,.arriWideGamut3)
        XCTAssertEqual(pub.inputLogC?.exposureIndex,800)
        XCTAssertThrowsError(try CameraPresetResolver.applying(CameraExposureSettings.selecting(profileID:"camera.arri.alexa-amira.v1",inputPolicy:.legacyAvailableDefaults),to:base))
    }
    func testFrozenLegacyHandlersAndEveryDefaultAvailabilityAndSettingsCopy() throws {
        let independent=try reference(),profiles=independent["profiles"] as! [[String:Any]]
        let old=try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/exposure-batch-legacy-reference.json"))) as! [String:Any]
        for item in old["cameraCases"] as! [[String:Any]] {
            let c=item["camera"] as! [String:Any]
            let id=try XCTUnwrap(profiles.first{$0["make"] as? String == c["make"] as? String && $0["model"] as? String == c["model"] as? String}?["id"] as? String)
            let state=try CameraExposureSettings.fromRecordedISO(profileID:id,recordedISO:item["recordedISO"] as! Int,inputPolicy:.explicitCurrentInput)
            XCTAssertEqual(state.stopCorrection,Double(item["stopShift"] as! String)!)
            let expected=Double(item["workerGain"] as! String)!
            XCTAssertLessThanOrEqual(abs(try state.gain-expected)/max(1,abs(expected)),2e-12)
        }
        let base=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0)
        var availability:[String:[[String:String]]]=[:]
        for policy in [CameraInputPolicy.legacyAvailableDefaults,.publishedAvailableDefaults] {
            var rows:[[String:String]]=[]
            for p in CameraCatalog.profiles {
                let state=try CameraExposureSettings.selecting(profileID:p.id,inputPolicy:policy)
                do {
                    let s=try CameraPresetResolver.applying(state,to:base)
                    rows.append(["profileID":p.id,"status":"available","transfer":s.inputTransfer.rawValue,"space":s.inputSpace.rawValue])
                }catch {
                    XCTAssertEqual(error as? CameraExposureError,.unsupportedDefaults(p.id))
                    rows.append(["profileID":p.id,"status":"blocked","legacyGamma":p.legacyGamma,"legacyGamut":p.legacyGamut])
                }
            }
            availability[policy.rawValue]=rows
            print("Camera defaults \(policy.rawValue): available=\(rows.filter{$0["status"] == "available"}.count), blocked=\(rows.filter{$0["status"] == "blocked"}.count)")
        }
        if let path=ProcessInfo.processInfo.environment["LUTCALC_CAMERA_ARTIFACT_DIR"] {
            let folder=URL(fileURLWithPath:path);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            try JSONSerialization.data(withJSONObject:availability,options:.sortedKeys).write(to:folder.appendingPathComponent("default-availability.json"))
        }
        let state=try CameraExposureSettings.fromRecordedISO(profileID:"camera.sony.pxw-fx9.v1",recordedISO:2401,inputPolicy:.explicitCurrentInput)
        let s=try CameraPresetResolver.applying(state,to:base)
        let copies=[s.withInputRange(.video),s.withOutputRange(.video),s.withRangeBitDepth(12),s.withAdaptation(.bradford),
            s.withInput(transfer:.sonySLog3,space:.sonySGamut3Cine),s.withOutput(transfer:.sonySLog3,space:.sonySGamut3Cine),
            s.withInputLogC(nil),s.withOutputLogC(nil),s.withFinalOutput(nil),s.withDisplayConversion(nil)]
        for copy in copies {XCTAssertEqual(copy.cameraExposure,state);_=try TransformPlan(settings:copy)}
        XCTAssertThrowsError(try state.changingStopCorrection(-100))
        XCTAssertThrowsError(try state.changingStopCorrection(.nan))
        XCTAssertThrowsError(try TransformPlan(settings:s.withExposureStops(.infinity)))
    }
}

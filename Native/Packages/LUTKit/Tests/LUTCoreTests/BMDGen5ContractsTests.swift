import Foundation
import XCTest
@testable import LUTCore
import LUTCatalog

final class BMDGen5ContractsTests:XCTestCase {
    private func root()->URL {
        URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private func fixture()throws->[String:Any] {
        try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/bmdgen5-independent.json"))) as! [String:Any]
    }
    func testPublishedAndLegacyFullCodesBranchesAndNonFinite()throws {
        let raw=try fixture();var errors:[Double]=[]
        for item in raw["curves"] as! [[String:Any]] {
            let legacy=item["legacy"] as! Bool,decode=item["decode"] as! Bool
            for row in item["points"] as! [[String]] {
                let x=Double(row[0])!,y=Double(row[1])!
                let actual:Double
                if legacy {
                    actual=decode ? try BMDGen5Transfer.decodeLegacyDataToLegacy(x) : try BMDGen5Transfer.encodeLegacyToData(x)
                }else {
                    actual=decode ? try BMDGen5Transfer.decodeDataToScene(x) : try BMDGen5Transfer.encodeSceneToData(x)
                }
                let error=abs(actual-y)/max(1,abs(y));errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
            }
        }
        let sorted=errors.sorted();print("BMD Gen5 curves: count=\(errors.count), max=\(sorted.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/Double(errors.count))), P99=\(sorted[Int(ceil(Double(errors.count)*0.99))-1])")
        for x in [Double.nan,Double.infinity,-Double.infinity] {
            XCTAssertThrowsError(try BMDGen5Transfer.decodeDataToScene(x));XCTAssertThrowsError(try BMDGen5Transfer.encodeSceneToData(x))
            XCTAssertThrowsError(try BMDGen5Transfer.decodeLegacyDataToLegacy(x));XCTAssertThrowsError(try BMDGen5Transfer.encodeLegacyToData(x))
        }
        XCTAssertThrowsError(try BMDGen5Transfer.decodeDataToScene(1e308))
        XCTAssertNotEqual(try BMDGen5Transfer.encodeSceneToData(0),try BMDGen5Transfer.encodeLegacyToData(0))
    }
    func testPublishedPrimariesBothCATsAllCurrentSpacesAndPlanIdentity()throws {
        let raw=try fixture();var errors:[Double]=[]
        let p=ColorPrimaries.blackmagicWideGamutGen5
        XCTAssertEqual(p.white.x,0.3127170);XCTAssertEqual(p.white.y,0.3290312)
        XCTAssertEqual(p.blue.y,-0.0820452)
        for item in raw["matrices"] as! [[String:Any]] {
            let matrix=try ColorPrimaries.conversion(from:ColorSpaceID(rawValue:item["source"] as! String)!.primaries,
                to:ColorSpaceID(rawValue:item["target"] as! String)!.primaries,adaptation:ChromaticAdaptation(rawValue:item["cat"] as! String)!)
            for (i,word) in (item["values"] as! [String]).enumerated() {
                let y=Double(word)!,error=abs(matrix.rowMajor[i]-y)/max(1,abs(y));errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
            }
        }
        print("BMD Gen5 matrices: count=\(errors.count), max=\(errors.max()!)")
        let catalog=try AlgorithmCatalog.builtIn()
        for (id,transfer) in [("blackmagic.film-gen5-to-linear-ap0-published.v1",TransferID.blackmagicFilmGen5),
            ("blackmagic.film-gen5-to-linear-ap0-legacy.v1",TransferID.blackmagicFilmGen5LUTCalcLegacy)] {
            let s=try XCTUnwrap(catalog.preset(named:id)).settings
            XCTAssertEqual(s.inputTransfer,transfer);XCTAssertEqual(s.inputSpace,.blackmagicWideGamutGen5)
            let plan=try TransformPlan(settings:s);XCTAssertTrue(plan.planVersion.contains(transfer.rawValue))
            XCTAssertTrue(plan.planVersion.contains(ColorSpaceID.blackmagicWideGamutGen5.rawValue))
        }
    }
    func testFourCameraDefaultsSelectTheirExplicitAlgorithm()throws {
        let base=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,outputSpace:.rec2020,inputRange:.data,outputRange:.data,exposureStops:0)
        for id in ["camera.blackmagic.ursa-mini-pro-12k.v1","camera.blackmagic.ursa-cine.v1","camera.blackmagic.pyxis.v1","camera.blackmagic.pyxis-high-base.v1"] {
            for policy in [CameraInputPolicy.publishedAvailableDefaults,.legacyAvailableDefaults] {
                let camera=try CameraExposureSettings.selecting(profileID:id,inputPolicy:policy)
                let s=try CameraPresetResolver.applying(camera,to:base)
                XCTAssertEqual(s.inputTransfer,policy == .publishedAvailableDefaults ? .blackmagicFilmGen5 : .blackmagicFilmGen5LUTCalcLegacy)
                XCTAssertEqual(s.inputSpace,.blackmagicWideGamutGen5);XCTAssertEqual(s.cameraExposure,camera)
            }
        }
        let published=try TransformPlan(settings:base.withOutput(transfer:.blackmagicFilmGen5,space:.rec2020).withOutputRange(.video))
        let scene=try RGB64(0.18,0.3,-0.1),result=try published.evaluate(scene)
        XCTAssertEqual(result.r,(try BMDGen5Transfer.encodeSceneToData(scene.r)-64.0/1023)/(876.0/1023),accuracy:2e-12)
    }
}

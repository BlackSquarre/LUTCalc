import Foundation
import XCTest
import LUTCore
import LUTCatalog
import LUTProject

final class BMDGen5ProjectContractsTests:XCTestCase {
    func testActualFrozenSchema19DiskReadPreservesCameraAndOriginalBytes()throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let before=try Data(contentsOf:root.appendingPathComponent("tests/fixtures/native-contracts/bmdgen5-schema19-original.json"))
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("bmd-schema19-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:folder)}
        let file=folder.appendingPathComponent("manifest.json");try before.write(to:file)
        let editor=try ProjectEditingSession(opening:folder,catalog:AlgorithmCatalog.builtIn())
        XCTAssertEqual(editor.current.schemaVersion,ProjectManifest.currentSchema);XCTAssertEqual(editor.current.settings.cameraExposure?.recordedISO,1501)
        let after=try Data(contentsOf:file);XCTAssertEqual(before,after)
        if let path=ProcessInfo.processInfo.environment["LUTCALC_BMDGEN5_ARTIFACT_DIR"] {
            let retained=URL(fileURLWithPath:path).appendingPathComponent(folder.lastPathComponent)
            try FileManager.default.createDirectory(at:retained,withIntermediateDirectories:true)
            try before.write(to:retained.appendingPathComponent("manifest-before.json"));try after.write(to:retained.appendingPathComponent("manifest-after.json"))
        }
    }
    func testNewIdentitiesRejectedInAllHistoricalSchemasIncludingDisabledGamut()throws {
        let catalog=try AlgorithmCatalog.builtIn()
        let base=TransformSettings(inputTransfer:.blackmagicFilmGen5,outputTransfer:.linearScene,inputSpace:.blackmagicWideGamutGen5,outputSpace:.acesAP0,inputRange:.data,outputRange:.data,exposureStops:0)
        for s in [base,base.withInput(transfer:.linearScene,space:.rec2020).withOutput(transfer:.blackmagicFilmGen5LUTCalcLegacy,space:.rec2020),
            base.withInput(transfer:.linearScene,space:.rec2020).withHighlightGamut(try HighlightGamutSettings(enabled:false,highlightSpace:.blackmagicWideGamutGen5)),
            base.withInput(transfer:.linearScene,space:.rec2020).withGamutLimiter(try GamutLimiterSettings(enabled:false,secondarySpace:.blackmagicWideGamutGen5))] {
            let project=ProjectManifest(settings:s,cubeSize:33,domain:.unit),bytes=try ProjectCodec.encode(project,catalog:catalog)
            XCTAssertEqual(project.schemaVersion,ProjectManifest.currentSchema);XCTAssertEqual(try ProjectCodec.decode(bytes,catalog:catalog),project)
            for schema in 1...19 {
                var raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any];raw["schemaVersion"]=schema
                let invalid=try JSONSerialization.data(withJSONObject:raw)
                XCTAssertThrowsError(try ProjectCodec.decode(invalid,catalog:catalog));XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self,from:invalid))
            }
        }
    }
}

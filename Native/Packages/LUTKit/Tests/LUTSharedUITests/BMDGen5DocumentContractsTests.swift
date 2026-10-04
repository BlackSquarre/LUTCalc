import Foundation
import XCTest
import LUTCore
import LUTCatalog
import LUTProject
import LUTJobs
import LUTFormats
import LUTSharedUI

@MainActor final class BMDGen5DocumentContractsTests:XCTestCase {
    private func root()->URL {
        URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    func testEightCompleteColourFilesProjectsAndLossy1DRejection()async throws {
        let raw=try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/bmdgen5-independent.json"))) as! [String:Any]
        let bytes=try Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/bmdgen5-grids.f64"))
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("bmd-files-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:folder)}
        var errors:[Double]=[]
        for (index,item) in (raw["grids"] as! [[String:Any]]).enumerated() {
            let decode=item["decode"] as! Bool,legacy=item["legacy"] as! Bool,size=item["size"] as! Int
            let transfer:TransferID=legacy ? .blackmagicFilmGen5LUTCalcLegacy : .blackmagicFilmGen5
            let s=TransformSettings(inputTransfer:decode ? transfer : .linearScene,outputTransfer:decode ? .linearScene : transfer,
                inputSpace:ColorSpaceID(rawValue:item["source"] as! String)!,outputSpace:ColorSpaceID(rawValue:item["target"] as! String)!,
                inputRange:.data,outputRange:.data,exposureStops:0,adaptation:ChromaticAdaptation(rawValue:item["cat"] as! String)!)
            let domain=try LUTDomain(min:RGB64(-0.1,-0.1,-0.1),max:RGB64(1.2,1.2,1.2))
            let doc=try LUTProjectDocument(new:ProjectManifest(settings:s,cubeSize:size,domain:domain))
            let project=folder.appendingPathComponent("case-\(index).lutcalc")
            try doc.makeFileWrapper().write(to:project,options:.atomic,originalContentsURL:nil)
            let reopened=try LUTProjectDocument(fileWrapper:FileWrapper(url:project));XCTAssertEqual(reopened.manifest,doc.manifest)
            let path=folder.appendingPathComponent("case-\(index).cube")
            _=try await NativeExportService().generate(reopened.makeGenerationRequest(workerCount:4),to:path)
            let lut=try CubeParser.parse(Data(contentsOf:path));XCTAssertEqual(lut.samples.count,size*size*size)
            var offset=item["offsetBytes"] as! Int
            for sample in lut.samples {for channel in 0..<3 {
                let expected=Double(bitPattern:bytes.withUnsafeBytes{$0.loadUnaligned(fromByteOffset:offset,as:UInt64.self).littleEndian})
                offset+=8;let error=abs(sample[channel]-expected)/max(1,abs(expected));errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
            }}
            let spi=folder.appendingPathComponent("case-\(index).spi1d")
            do{_=try await NativeExportService().generate(reopened.makeGenerationRequest(),to:spi);XCTFail("Expected channel coupling rejection")}
            catch {XCTAssertEqual(error as? SPI1DFailure,SPI1DFailure(.lossyRepresentation,line:0))}
            XCTAssertFalse(FileManager.default.fileExists(atPath:spi.path))
        }
        let sorted=errors.sorted(),report:[String:Any]=["channels":errors.count,"maximum":sorted.last!,"RMS":sqrt(errors.reduce(0){$0+$1*$1}/Double(errors.count)),"P99":sorted[Int(ceil(Double(errors.count)*0.99))-1],"threshold":2e-12]
        try JSONSerialization.data(withJSONObject:report,options:.sortedKeys).write(to:folder.appendingPathComponent("numeric-results.json"))
        print("BMD Gen5 full files: \(report)")
        if let path=ProcessInfo.processInfo.environment["LUTCALC_BMDGEN5_ARTIFACT_DIR"] {
            let destination=URL(fileURLWithPath:path);try FileManager.default.createDirectory(at:destination,withIntermediateDirectories:true)
            try FileManager.default.copyItem(at:folder,to:destination.appendingPathComponent(folder.lastPathComponent))
        }
    }
    func testCameraEditsSnapshotUndoWorkerCancelAndDecodeOverflow()async throws {
        let base=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.acesAP0,outputSpace:.acesAP0,inputRange:.data,outputRange:.data,exposureStops:0)
        var doc=try LUTProjectDocument(new:ProjectManifest(settings:base,cubeSize:33,domain:.unit))
        try doc.applyCameraSelection(profileID:"camera.blackmagic.pyxis.v1",inputPolicy:.publishedAvailableDefaults,expectedRevision:doc.revision)
        let request=try doc.makeGenerationRequest(),revision=doc.revision
        try doc.applyCameraStopCorrection(0.125,expectedRevision:revision)
        XCTAssertNotEqual(try doc.makeGenerationRequest().plan.settings,request.plan.settings)
        XCTAssertThrowsError(try doc.applyCameraRecordedISO(800,expectedRevision:revision))
        _=doc.undo();XCTAssertEqual(doc.manifest.settings,request.plan.settings);_=doc.redo()
        var previous:[RGB64]?
        for workers in [1,4] {
            let sink=InMemoryCubeSink();_=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:request.plan,size:33,domain:.unit,blockNodes:17,workerCount:workers),sink:sink)
            let actual=await sink.samples;if let previous{XCTAssertEqual(actual,previous)}else{previous=actual}
        }
        let sink=InMemoryCubeSink(cancelAtBlock:1)
        do{_=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:request.plan,size:33,domain:.unit,blockNodes:17),sink:sink);XCTFail("Expected cancellation")}catch is CancellationError {}
        let state=await sink.state;XCTAssertEqual(state,.aborted)
        XCTAssertThrowsError(try request.plan.evaluate(RGB64(1e308,1e308,1e308))) {
            XCTAssertEqual($0 as? PlanError,.numeric(stageID:2,sampleIndex:nil))
        }
    }
}

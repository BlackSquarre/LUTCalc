import Foundation
import XCTest
import LUTCore
import LUTCatalog
import LUTProject
import LUTJobs
import LUTFormats
import LUTSharedUI

@MainActor final class CameraStateDocumentContractsTests:XCTestCase {
    private func root()->URL {
        URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private func retain(_ folder:URL)throws {
        if let target=ProcessInfo.processInfo.environment["LUTCALC_CAMERA_ARTIFACT_DIR"] {
            let parent=URL(fileURLWithPath:target);try FileManager.default.createDirectory(at:parent,withIntermediateDirectories:true)
            try FileManager.default.copyItem(at:folder,to:parent.appendingPathComponent(folder.lastPathComponent))
        }
    }
    private func base()->TransformSettings {
        TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0)
    }
    func testEightCompleteCubesAndFourSPI1DsAgainstIndependentExposure()async throws {
        let raw=try JSONSerialization.jsonObject(with:Data(contentsOf:root().appendingPathComponent("tests/fixtures/native-contracts/camera-state-independent.json"))) as! [String:Any]
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("camera-files-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:folder)}
        var errors:[Double]=[]
        for (index,item) in (raw["grids"] as! [[String:Any]]).enumerated() {
            let camera=try CameraExposureSettings.fromRecordedISO(profileID:item["profileID"] as! String,recordedISO:item["recordedISO"] as! Int,
                previousManualStops:item["previousManualStops"] as! Double,inputPolicy:.explicitCurrentInput)
            let s=try CameraPresetResolver.applying(camera,to:base()),size=item["size"] as! Int
            let lo=item["minimum"] as! Double,hi=item["maximum"] as! Double
            let domain=try LUTDomain(min:RGB64(lo,lo,lo),max:RGB64(hi,hi,hi))
            let doc=try LUTProjectDocument(new:ProjectManifest(settings:s,cubeSize:size,domain:domain))
            let project=folder.appendingPathComponent("case-\(index).lutcalc")
            try doc.makeFileWrapper().write(to:project,options:.atomic,originalContentsURL:nil)
            let reopened=try LUTProjectDocument(fileWrapper:FileWrapper(url:project))
            XCTAssertEqual(reopened.manifest,doc.manifest)
            let path=folder.appendingPathComponent("case-\(index).cube")
            _=try await NativeExportService().generate(reopened.makeGenerationRequest(workerCount:4),to:path)
            let lut=try CubeParser.parse(Data(contentsOf:path)),axis=(item["outputs"] as! [String]).map{Double($0)!}
            XCTAssertEqual(lut.samples.count,size*size*size)
            for node in 0..<lut.samples.count {for c in 0..<3 {
                let y=axis[[node%size,(node/size)%size,node/(size*size)][c]],error=abs(lut.samples[node][c]-y)/max(1,abs(y))
                errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
            }}
            if size == 33 {
                let spi=folder.appendingPathComponent("case-\(index).spi1d")
                _=try await NativeExportService().generate(reopened.makeGenerationRequest(workerCount:4),to:spi)
                let lut1D=try SPI1DParser.parse(Data(contentsOf:spi)).lut,expected=(item["spi1dOutputs"] as! [String]).map{Double($0)!}
                XCTAssertEqual(lut1D.samples.count,1024)
                for i in 0..<1024 {for c in 0..<3 {
                    let y=expected[i],error=abs(lut1D.samples[i][c]-y)/max(1,abs(y))
                    errors.append(error);XCTAssertLessThanOrEqual(error,2e-12)
                }}
            }
        }
        let sorted=errors.sorted(),report:[String:Any]=["channels":errors.count,"max":sorted.last!,
            "RMS":sqrt(errors.reduce(0){$0+$1*$1}/Double(errors.count)),"P99":sorted[Int(ceil(Double(errors.count)*0.99))-1],"threshold":2e-12]
        try JSONSerialization.data(withJSONObject:report,options:.sortedKeys).write(to:folder.appendingPathComponent("numeric-results.json"))
        print("Camera actual files: \(report)");try retain(folder)
    }
    func testDocumentEditsPreserveAssetsDraftGammaAndBatchOverrides()throws {
        let preset=try ExposureBatchPreset(sequence:ExposureBatchSequence(minimumStops:0,maximumStops:1,subdivisions:3),basename:"Camera",format:.cube)
        var doc=try LUTProjectDocument(new:ProjectManifest(settings:base(),cubeSize:33,domain:.unit,exposureBatchPreset:preset))
        let camera=try CameraExposureSettings.fromRecordedISO(profileID:"camera.sony.pxw-fx9.v1",recordedISO:2401,inputPolicy:.explicitCurrentInput)
        try doc.applyCameraExposure(camera,expectedRevision:doc.revision)
        _=try doc.storeImportedUserLUT(NativeUserLUTLoader.parse(Data("LUT_1D_SIZE 2\n0 0 0\n1 1 1\n".utf8),named:"user.cube"))
        let assets=doc.manifest.assetHashes,first=try doc.makeGenerationRequest(),revision=doc.revision
        let oldBatch=try doc.makeStoredExposureBatchRequest(directory:URL(fileURLWithPath:"/tmp"))
        try doc.applyCameraRecordedISO(800,expectedRevision:revision)
        XCTAssertThrowsError(try doc.applyCameraRecordedISO(1600,expectedRevision:revision))
        XCTAssertNotEqual(oldBatch.fingerprint,try doc.makeStoredExposureBatchRequest(directory:URL(fileURLWithPath:"/tmp")).fingerprint)
        XCTAssertEqual(first.plan.settings.cameraExposure?.recordedISO,2401)
        XCTAssertTrue(doc.undo());XCTAssertEqual(doc.manifest.settings.cameraExposure?.recordedISO,2401)
        XCTAssertTrue(doc.redo());XCTAssertEqual(doc.manifest.settings.cameraExposure?.recordedISO,800)
        try doc.applyCameraStopCorrection(0.125,expectedRevision:doc.revision)
        let current=try XCTUnwrap(doc.manifest.settings.cameraExposure)
        try doc.applyParameterizedGamma(.init(exponent:"2",linearSlope:"1",offset:"0",linearCut:"0",encodedCut:""),slot:.output,expectedRevision:doc.revision)
        XCTAssertEqual(doc.manifest.settings.cameraExposure,current);XCTAssertEqual(doc.manifest.assetHashes,assets)
        XCTAssertEqual(doc.manifest.exposureBatchPreset,preset)
        let batch=try doc.makeStoredExposureBatchRequest(directory:URL(fileURLWithPath:"/tmp"))
        XCTAssertEqual(batch.items.map{$0.request.plan.settings.exposureStops},[0,1.0/3,2.0/3,1])
        XCTAssertTrue(batch.items.allSatisfy{$0.request.plan.settings.cameraExposure?.recordedISO == current.recordedISO})
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("camera-backend-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:folder)}
        let project=folder.appendingPathComponent("self-contained.lutcalc")
        try doc.makeFileWrapper().write(to:project,options:.atomic,originalContentsURL:nil)
        let editor=EditorSession();try editor.openProject(at:project)
        XCTAssertEqual(try editor.makeSnapshot().plan.settings,doc.manifest.settings)
        XCTAssertNotNil(try editor.makeSnapshot().postLUT);try retain(folder)
    }
    func testSelectionFailureIsAtomicAndISOEditsKeepExplicitInput()throws {
        var doc=try LUTProjectDocument(new:ProjectManifest(settings:base(),cubeSize:33,domain:.unit))
        let original=doc.manifest,revision=doc.revision
        XCTAssertThrowsError(try doc.applyCameraSelection(profileID:"camera.nikon.d800.v1",inputPolicy:.publishedAvailableDefaults,expectedRevision:revision))
        XCTAssertEqual(doc.manifest,original);XCTAssertEqual(doc.revision,revision)
        try doc.applyCameraSelection(profileID:"camera.sony.pxw-fx9.v1",inputPolicy:.legacyAvailableDefaults,expectedRevision:doc.revision)
        var changed=doc.manifest.settings.withInput(transfer:.linearScene,space:.rec2020)
        try doc.apply(ProjectManifest(id:doc.manifest.id,settings:changed,cubeSize:33,domain:.unit))
        try doc.applyCameraRecordedISO(1501,expectedRevision:doc.revision)
        XCTAssertEqual(doc.manifest.settings.inputTransfer,.linearScene)
        changed=doc.manifest.settings
        XCTAssertEqual(changed.cameraExposure?.recordedISO,1501)
        let plan=try TransformPlan(settings:changed)
        XCTAssertEqual(try plan.evaluate(RGB64(100,100,100)).r,100*pow(2,changed.exposureStops),accuracy:2e-12)
        // Camera clipping is an auxiliary scene marker, never an automatic clamp.
        XCTAssertGreaterThan(try plan.evaluate(RGB64(100,100,100)).r,try changed.cameraExposure!.clipScene)
    }
    func testCameraPlanWorkerDeterminismCancellationAndStage4Overflow()async throws {
        let camera=try CameraExposureSettings.fromRecordedISO(profileID:"camera.sony.venice.v1",recordedISO:1501,inputPolicy:.explicitCurrentInput)
        let plan=try TransformPlan(settings:CameraPresetResolver.applying(camera,to:base()))
        var previous:[RGB64]?
        for workers in [1,4] {
            let sink=InMemoryCubeSink()
            _=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:plan,size:33,domain:.unit,blockNodes:17,workerCount:workers),sink:sink)
            let values=await sink.samples
            if let previous {XCTAssertEqual(values,previous)}else {previous=values}
        }
        let cancelled=InMemoryCubeSink(cancelAtBlock:1)
        do{_=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:plan,size:33,domain:.unit,blockNodes:17),sink:cancelled);XCTFail("Expected cancellation")}
        catch is CancellationError {}
        let state=await cancelled.state;XCTAssertEqual(state,.aborted)
        let domain=try LUTDomain(min:RGB64(1e308,1e308,1e308),max:RGB64(1.1e308,1.1e308,1.1e308)),failed=InMemoryCubeSink()
        do{_=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:plan,size:17,domain:domain,workerCount:1),sink:failed);XCTFail("Expected overflow")}
        catch {XCTAssertEqual(error as? PlanError,.numeric(stageID:4,sampleIndex:0))}
        let failedState=await failed.state;XCTAssertEqual(failedState,.aborted)
    }
}

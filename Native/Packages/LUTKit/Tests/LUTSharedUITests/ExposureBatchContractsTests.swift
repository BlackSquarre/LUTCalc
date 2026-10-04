import Foundation
import XCTest
import LUTCore
import LUTJobs
import LUTSharedUI
import LUTFormats
import LUTProject

final class ExposureBatchContractsTests:XCTestCase {
    private func base(size:Int = 17)throws->LUTGenerationRequest {
        try LUTGenerationRequest(plan:TransformPlan(settings:TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,
            inputSpace:.rec2020,outputSpace:.rec2020,inputRange:.data,outputRange:.data,exposureStops:7)),size:size,domain:.unit,workerCount:1)
    }
    private func folder()throws->URL {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:url,withIntermediateDirectories:true);return url
    }
    func testExactSequenceNamingBoundsAndImmutableReplacement()throws {
        let settings=try ExposureBatchSettings(minimumStops:-2,maximumStops:2,subdivisions:3)
        XCTAssertEqual(settings.stops.count,13)
        for i in 0..<13{XCTAssertEqual(settings.stops[i],Double(-6+i)/3)}
        XCTAssertEqual(settings.stops[6].bitPattern,Double(0).bitPattern)
        let url=try folder();defer{try? FileManager.default.removeItem(at:url)}
        let b=try base(),request=try ExposureBatchRequest(base:b,settings:settings,directory:url,basename:"曝光",format:.cube)
        XCTAssertEqual(request.items[0].filename,"曝光_-2p00.cube");XCTAssertEqual(request.items[6].filename,"曝光_0-Native.cube")
        XCTAssertEqual(request.items[7].filename,"曝光_0p33.cube")
        XCTAssertEqual(request.items[0].request.plan.settings.exposureStops,-2);XCTAssertEqual(b.plan.settings.exposureStops,7)
        XCTAssertEqual(request.items[0].request.workerCount,1);XCTAssertEqual(request.items[0].request.size,17)
        for parts in [0,5]{XCTAssertThrowsError(try ExposureBatchSettings(minimumStops:-2,maximumStops:2,subdivisions:parts))}
        XCTAssertThrowsError(try ExposureBatchSettings(minimumStops:2,maximumStops:-2,subdivisions:3))
        XCTAssertThrowsError(try ExposureBatchSettings(minimumStops:Int.min,maximumStops:Int.max,subdivisions:4))
        XCTAssertThrowsError(try ExposureBatchSettings(minimumStops:-1000,maximumStops:1000,subdivisions:1))
        for name in ["","../escape","a/b","a\\b",".",".."] {
            XCTAssertThrowsError(try ExposureBatchRequest(base:b,settings:settings,directory:url,basename:name,format:.cube))
        }
        XCTAssertThrowsError(try ExposureBatchRequest(base:b,settings:ExposureBatchSettings(minimumStops:2000,maximumStops:2000,subdivisions:1),directory:url,basename:"overflow",format:.cube))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath:url.path).isEmpty)
    }
    func testAll64LegacySelectionsAgainstIndependentRationalReference()throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let independent=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("tests/fixtures/native-contracts/exposure-batch-independent-reference.json"))) as! [String:Any]
        let legacy=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("tests/fixtures/native-contracts/exposure-batch-legacy-reference.json"))) as! [String:Any]
        let all=independent["cases"] as! [[String:Any]],old=legacy["cases"] as! [[String:Any]]
        XCTAssertEqual(all.count,64);XCTAssertEqual(old.count,64);XCTAssertEqual((legacy["cameras"] as! [Any]).count,66)
        XCTAssertTrue((legacy["minimumZeroReproduction"] as! [String:Any])["error"] as! String != "")
        let url=try folder();defer{try? FileManager.default.removeItem(at:url)}
        var maximumLegacyStopDifference=0.0,maximumIndependentGainError=0.0
        for i in all.indices {
            let item=all[i],settings=try ExposureBatchSettings(minimumStops:item["minimum"] as! Int,maximumStops:item["maximum"] as! Int,subdivisions:item["subdivisions"] as! Int)
            let request=try ExposureBatchRequest(base:base(),settings:settings,directory:url,basename:"Probe",format:.cube)
            let expected=(item["stops"] as! [String]).map{Double($0)!},gains=(item["gains"] as! [String]).map{Double($0)!},previous=old[i]["values"] as! [[String:String]]
            XCTAssertEqual(request.items.count,expected.count);XCTAssertEqual(previous.count,expected.count)
            for j in expected.indices {
                XCTAssertEqual(request.items[j].stop.bitPattern,expected[j].bitPattern)
                XCTAssertEqual(request.items[j].filename,previous[j]["filename"]!+".cube")
                let value=try request.items[j].request.plan.evaluate(RGB64(1,1,1)).r
                let error=abs(value-gains[j])/max(1,abs(gains[j]));maximumIndependentGainError=max(maximumIndependentGainError,error)
                XCTAssertLessThanOrEqual(error,2e-12)
                maximumLegacyStopDifference=max(maximumLegacyStopDifference,abs(request.items[j].stop-Double(previous[j]["stop"]!)!))
            }
        }
        print("Exposure Batch 64 choices: maximumLegacyStopDifference=\(maximumLegacyStopDifference), maximumIndependentGainError=\(maximumIndependentGainError)")
    }
    func testActualDiskIndependentBatchAndComplete33And65()async throws {
        let url=try folder();defer{try? FileManager.default.removeItem(at:url)}
        let request=try ExposureBatchRequest(base:base(),settings:ExposureBatchSettings(minimumStops:-1,maximumStops:1,subdivisions:3),directory:url,basename:"batch",format:.cube)
        let coordinator=ExposureBatchCoordinator(),report=try await coordinator.generate(request,exporter:NativeExportService())
        XCTAssertEqual(report.state,.completed);XCTAssertEqual(report.items.count,7)
        let file=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("tests/fixtures/native-contracts/exposure-batch-independent-reference.json")
        let reference=try JSONSerialization.jsonObject(with:Data(contentsOf:file)) as! [String:Any]
        let gains=(reference["gains"] as! [String]).map{Double($0)!}
        var errors:[Double]=[]
        for i in request.items.indices {
            let lut=try CubeParser.parse(Data(contentsOf:request.items[i].url)),grid=try Grid3D(size:17,domain:.unit)
            XCTAssertEqual(report.items[i].state,.completed);XCTAssertEqual(report.items[i].writtenNodes,grid.nodeCount)
            for j in 0..<grid.nodeCount {let p=try grid.coordinate(at:j)
                for c in 0..<3 {let expected=p[c]*gains[i],e=abs(lut.samples[j][c]-expected)/max(1,abs(expected));errors.append(e);XCTAssertLessThanOrEqual(e,2e-12)}
            }
        }
        for size in [33,65] {
            let r=try ExposureBatchRequest(base:base(size:size),settings:ExposureBatchSettings(minimumStops:0,maximumStops:1,subdivisions:3),directory:url,basename:"full\(size)",format:.cube)
            let completed=try await ExposureBatchCoordinator().generate(r,exporter:NativeExportService());XCTAssertEqual(completed.state,.completed)
            let fullGains=(reference["fullGains"] as! [String]).map{Double($0)!}
            for i in r.items.indices {
                let lut=try CubeParser.parse(Data(contentsOf:r.items[i].url)),grid=try Grid3D(size:size,domain:.unit)
                for j in 0..<grid.nodeCount {let p=try grid.coordinate(at:j);for c in 0..<3 {
                    let expected=p[c]*fullGains[i],e=abs(lut.samples[j][c]-expected)/max(1,abs(expected));errors.append(e);XCTAssertLessThanOrEqual(e,2e-12)}}
            }
        }
        let sorted=errors.sorted(),n=Double(errors.count)
        print("Exposure Batch independent disk scaled errors: count=\(errors.count), max=\(sorted.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/n)), P99=\(sorted[Int(ceil(n*0.99))-1])")
    }
    func testCancellationCheckpointResumeAndCompletedIdentity()async throws {
        let url=try folder();defer{try? FileManager.default.removeItem(at:url)}
        let request=try ExposureBatchRequest(base:base(),settings:ExposureBatchSettings(minimumStops:-1,maximumStops:1,subdivisions:1),directory:url,basename:"resume",format:.cube)
        let first=try await ExposureBatchCoordinator().generate(request,exporter:BatchInterruptExporter(at:1,cancel:true))
        XCTAssertEqual(first.state,.cancelled);XCTAssertEqual(first.items.map(\.state),[.completed,.cancelled,.pending])
        let bytes=try JSONEncoder().encode(first),checkpoint=url.appendingPathComponent("checkpoint.json")
        try bytes.write(to:checkpoint,options:.atomic)
        let reopened=try JSONDecoder().decode(ExposureBatchReport.self,from:Data(contentsOf:checkpoint))
        let original=try Data(contentsOf:request.items[0].url)
        let finished=try await ExposureBatchCoordinator().generate(request,exporter:NativeExportService(),resumeFrom:reopened)
        XCTAssertEqual(finished.state,.completed);XCTAssertEqual(try Data(contentsOf:request.items[0].url),original)
        // Replacing a completed inode with equal bytes must fail recovery.
        try FileManager.default.removeItem(at:request.items[0].url);try original.write(to:request.items[0].url)
        do{_=try await ExposureBatchCoordinator().generate(request,exporter:NativeExportService(),resumeFrom:finished);XCTFail("Expected replaced identity rejection")}
        catch{XCTAssertEqual(error as? ExposureBatchError,.completedOutputChanged(0))}
        let changed=try ExposureBatchRequest(base:base(size:33),settings:request.settings,directory:url,basename:"resume",format:.cube)
        do{_=try await ExposureBatchCoordinator().generate(changed,exporter:NativeExportService(),resumeFrom:finished);XCTFail("Expected identity mismatch")}
        catch{XCTAssertEqual(error as? ExposureBatchError,.checkpointMismatch)}
    }
    func testDocumentSnapshotPreservesAdjustmentAndUserResources()throws {
        let url=try folder();defer{try? FileManager.default.removeItem(at:url)}
        let original=try base(),policy=try FinalOutputSettings(enabled:false)
        let manifest=ProjectManifest(settings:original.plan.settings.withFinalOutput(policy),cubeSize:17,domain:.unit)
        var document=try LUTProjectDocument(new:manifest)
        let batch=try document.makeExposureBatchRequest(settings:ExposureBatchSettings(),directory:url,basename:"snapshot",format:.cube)
        try document.apply(ProjectManifest(id:manifest.id,settings:manifest.settings.withExposureStops(-3),cubeSize:33,domain:.unit))
        XCTAssertEqual(batch.items.count,13);XCTAssertEqual(batch.items[0].request.size,17)
        XCTAssertEqual(batch.items[0].request.plan.settings.finalOutput,policy)
        XCTAssertEqual(batch.items[0].request.plan.settings.exposureStops,-2)
        let post=try CubeLUT(dimension:.one,size:2,domain:.unit,samples:[RGB64(0,0,0),RGB64(1,1,1)])
        let withUser=try LUTGenerationRequest(plan:original.plan,size:17,domain:.unit,postLUT:post)
        let userBatch=try ExposureBatchRequest(base:withUser,settings:batch.settings,directory:url,basename:"snapshot",format:.cube)
        XCTAssertEqual(userBatch.items[0].request.postLUT,post);XCTAssertNotEqual(userBatch.fingerprint,batch.fingerprint)
    }
    func testSingleActorRejectsOverlapRealTaskCancelAndCommitBoundary()async throws {
        let url=try folder();defer{try? FileManager.default.removeItem(at:url)}
        for after in [false,true] {
            let request=try ExposureBatchRequest(base:base(),settings:ExposureBatchSettings(minimumStops:0,maximumStops:1,subdivisions:1),directory:url,basename:after ? "after" : "before",format:.cube)
            let exporter=BatchGateExporter(afterCommit:after),coordinator=ExposureBatchCoordinator()
            let task=Task{try await coordinator.generate(request,exporter:exporter)}
            await exporter.waitForStart()
            do{_=try await coordinator.generate(request,exporter:NativeExportService());XCTFail("Expected overlap rejection")}
            catch{XCTAssertEqual(error as? ExposureBatchError,.alreadyStarted)}
            task.cancel();await exporter.release();let report=try await task.value
            XCTAssertEqual(report.state,.cancelled)
            XCTAssertEqual(report.items.map(\.state),after ? [.completed,.cancelled] : [.cancelled,.pending])
            XCTAssertEqual(FileManager.default.fileExists(atPath:request.items[0].url.path),after)
            XCTAssertFalse(FileManager.default.fileExists(atPath:request.items[1].url.path))
        }
    }
    func testFailureOverwriteAndSPI1DIndependentPaths()async throws {
        let url=try folder();defer{try? FileManager.default.removeItem(at:url)}
        let r=try ExposureBatchRequest(base:base(),settings:ExposureBatchSettings(minimumStops:-1,maximumStops:1,subdivisions:1),directory:url,basename:"existing",format:.cube)
        let old=Data("existing-user-file".utf8);try old.write(to:r.items[1].url)
        let failed=try await ExposureBatchCoordinator().generate(r,exporter:NativeExportService())
        XCTAssertEqual(failed.state,.failed);XCTAssertEqual(failed.items.map(\.state),[.completed,.failed,.pending])
        XCTAssertEqual(try Data(contentsOf:r.items[1].url),old);XCTAssertFalse(FileManager.default.fileExists(atPath:r.items[2].url.path))
        let overwrite=try ExposureBatchRequest(base:base(),settings:r.settings,directory:url,basename:"existing",format:.cube,allowOverwrite:true)
        let succeeded=try await ExposureBatchCoordinator().generate(overwrite,exporter:NativeExportService())
        XCTAssertEqual(succeeded.state,.completed);XCTAssertNotEqual(try Data(contentsOf:r.items[1].url),old)
        let one=try ExposureBatchRequest(base:base(),settings:ExposureBatchSettings(minimumStops:0,maximumStops:0,subdivisions:1),directory:url,basename:"one",format:.spi1d)
        let exported=try await ExposureBatchCoordinator().generate(one,exporter:NativeExportService());XCTAssertEqual(exported.items[0].writtenNodes,1024)
        let samples=try SPI1DParser.parse(Data(contentsOf:one.items[0].url)).lut.samples
        for i in samples.indices{for c in 0..<3{XCTAssertEqual(samples[i][c],Double(i)/1023)}}
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath:url.path).contains{$0.hasPrefix(".lutcalc-")})
    }
}
private actor BatchInterruptExporter:ExposureBatchExporter {
    let at:Int,cancel:Bool;var index=0
    init(at:Int,cancel:Bool){self.at=at;self.cancel=cancel}
    func generate(_ request:LUTGenerationRequest,to output:URL,allowOverwrite:Bool)async throws->Int {
        let current=index;index+=1
        if current==at {if cancel{throw CancellationError()};throw JobFailure.injectedWriteFailure}
        return try await NativeExportService().generate(request,to:output,allowOverwrite:allowOverwrite)
    }
}

private actor BatchGateExporter:ExposureBatchExporter {
    let afterCommit:Bool
    var entered=false,gate:CheckedContinuation<Void,Never>?,waiters:[CheckedContinuation<Void,Never>]=[]
    init(afterCommit:Bool){self.afterCommit=afterCommit}
    func waitForStart()async {
        if entered{return};await withCheckedContinuation{waiters.append($0)}
    }
    func release(){gate?.resume();gate=nil}
    private func pause()async {
        await withCheckedContinuation{continuation in
            gate=continuation;entered=true
            for waiter in waiters{waiter.resume()};waiters=[]
        }
    }
    func generate(_ request:LUTGenerationRequest,to output:URL,allowOverwrite:Bool)async throws->Int {
        if !afterCommit{await pause()}
        let nodes=try await NativeExportService().generate(request,to:output,allowOverwrite:allowOverwrite)
        if afterCommit{await pause()}
        return nodes
    }
}

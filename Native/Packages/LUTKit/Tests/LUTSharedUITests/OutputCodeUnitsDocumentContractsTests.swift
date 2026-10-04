import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTSharedUI
import LUTJobs
import LUTFormats

@MainActor
final class OutputCodeUnitsDocumentContractsTests:XCTestCase {
    private func settings(_ policy:OutputCodeUnitPolicy)throws->TransformSettings {
        TransformSettings(inputTransfer:.linearScene,outputTransfer:.gamma22,inputSpace:.rec2020,outputSpace:.rec2020,
            inputRange:.data,outputRange:.data,exposureStops:0,
            blackHighlight:try BlackHighlightSettings(doBlack:true,doHigh:true,blackLevel:0.05,blackLock:true,highMap:0.85,highLock:true),
            outputCodeUnits:policy)
    }
    func testDiskCubeSPI1DIdentityGammaEditAndSnapshots() async throws {
        let domain=try LUTDomain(min:RGB64(-0.5,-0.5,-0.5),max:RGB64(2,2,2))
        var doc=try LUTProjectDocument(new:ProjectManifest(settings:settings(.completeV2),cubeSize:33,domain:domain))
        let request=try doc.makeGenerationRequest()
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:folder)}
        let project=folder.appendingPathComponent("code-units.lutcalc")
        try doc.makeFileWrapper().write(to:project,options:.atomic,originalContentsURL:nil)
        let reopened=try LUTProjectDocument(fileWrapper:FileWrapper(url:project))
        XCTAssertEqual(reopened.manifest.settings.outputCodeUnits,.completeV2)
        let editor=EditorSession();try editor.openProject(at:project)
        XCTAssertEqual(try editor.makeSnapshot().plan.settings.outputCodeUnits,.completeV2)
        let cubeURL=folder.appendingPathComponent("code-units.cube"),spiURL=folder.appendingPathComponent("code-units.spi1d")
        _=try await NativeExportService().generate(request,to:cubeURL)
        _=try await NativeExportService().generate(request,to:spiURL)
        let cube=try CubeParser.parse(Data(contentsOf:cubeURL)),spi=try SPI1DParser.parse(Data(contentsOf:spiURL))
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixture=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("tests/fixtures/native-contracts/output-code-units-independent-reference.json"))) as! [String:Any]
        let axis=(fixture["axes"] as! [[String:Any]]).first{$0["transfer"] as! String == TransferID.gamma22.rawValue}!
        let expected=(axis["size33"] as! [String]).map{Double($0)!}
        for i in [0,1,16,32,33*16+32,33*33*33-1] {
            let indices=[i%33,(i/33)%33,i/(33*33)]
            for c in 0..<3{XCTAssertLessThanOrEqual(abs(cube.samples[i][c]-expected[indices[c]])/max(1,abs(expected[indices[c]])),2e-12)}
        }
        let expected1D=(axis["size1024"] as! [String]).map{Double($0)!}
        XCTAssertEqual(spi.lut.samples.count,1024)
        for i in 0..<1024 {for c in 0..<3{XCTAssertLessThanOrEqual(abs(spi.lut.samples[i][c]-expected1D[i])/max(1,abs(expected1D[i])),2e-12)}}
        let draft=ParameterizedGammaDraft(exponent:"2",linearSlope:"1",offset:"0",linearCut:"0",encodedCut:"")
        try doc.applyParameterizedGamma(draft,slot:.output,expectedRevision:doc.revision)
        XCTAssertEqual(doc.manifest.settings.outputCodeUnits,.completeV2)
        XCTAssertTrue(doc.undo());XCTAssertTrue(doc.redo())
        XCTAssertEqual(request.plan.settings.outputTransfer,.gamma22)
        for policy in [OutputCodeUnitPolicy.partialV1,.completeV2] {
            var previous=try LUTProjectDocument(new:ProjectManifest(settings:settings(policy),cubeSize:33,domain:domain))
            try previous.applyParameterizedGamma(draft,slot:.input,expectedRevision:previous.revision)
            XCTAssertEqual(previous.manifest.settings.outputCodeUnits,policy)
            try previous.applyParameterizedGamma(draft,slot:.output,expectedRevision:previous.revision)
            XCTAssertEqual(previous.manifest.settings.outputCodeUnits,policy)
        }
    }
    func testPolicySnapshotWorkerDeterminismAndNumericAbort() async throws {
        let plan=try TransformPlan(settings:settings(.completeV2).withGamutLimiter(GamutLimiterSettings(postLevel:0.6,secondarySpace:.srgb)))
        var previous:[RGB64]?
        for workers in [1,4] {
            let sink=InMemoryCubeSink()
            _=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:plan,size:33,domain:.unit,workerCount:workers),sink:sink)
            let samples=await sink.samples
            if let previous{XCTAssertEqual(previous,samples)}else{previous=samples}
        }
        let s=try settings(.completeV2).withBlackHighlight(BlackHighlightSettings(doHigh:true,highMap:Double.greatestFiniteMagnitude/4,highLock:true))
        let extreme=try TransformPlan(settings:s),domain=try LUTDomain(min:RGB64(1e200,1e200,1e200),max:RGB64(2e200,2e200,2e200)),sink=InMemoryCubeSink()
        do{_=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:extreme,size:17,domain:domain,workerCount:1),sink:sink);XCTFail("Expected stage 14 numeric failure")}
        catch{XCTAssertEqual(error as? PlanError,.numeric(stageID:14,sampleIndex:0))}
        let state=await sink.state;XCTAssertEqual(state,.aborted)
    }
}

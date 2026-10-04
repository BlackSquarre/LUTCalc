import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTCatalog
import LUTJobs
import LUTFormats
import LUTSharedUI

@MainActor final class ARRILogCSceneDocumentContractsTests: XCTestCase {
    private func root() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private func fixture(_ name: String) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(contentsOf: root().appendingPathComponent(
            "tests/fixtures/native-contracts/" + name))) as! [String: Any]
    }
    private func payload(_ item: [String: Any]) throws -> ARRILogCSceneSettings {
        try ARRILogCSceneSettings(algorithm: item["firmware"] as! String == "sup2" ? .sup2Published : .sup3Published,
                                 exposureIndex: item["exposureIndex"] as! Int)
    }
    private func settings(_ item: [String: Any]) throws -> TransformSettings {
        let p = try payload(item), encoding = item["direction"] as! String == "encode"
        return TransformSettings(inputTransfer: encoding ? .linearScene : p.algorithm.transferID,
            outputTransfer: encoding ? p.algorithm.transferID : .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020, inputRange: .data, outputRange: .data,
            exposureStops: 0, inputLogC: encoding ? nil : p, outputLogC: encoding ? p : nil)
    }
    private func retain(_ folder: URL) throws {
        if let target = ProcessInfo.processInfo.environment["LUTCALC_LOGC_ROUTING_ARTIFACT_DIR"] {
            let parent = URL(fileURLWithPath: target)
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: folder, to: parent.appendingPathComponent(folder.lastPathComponent))
        }
    }
    func testCompleteCubeSPI1DAndMixedExposureFilesAgainstIndependentDecimal() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("logc-files-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let independent = try fixture("arri-logc-scene-routing-independent.json")
        let grids = (try fixture("arri-logc-compact-independent.json")["grids"] as! [[String: Any]])
            .filter { $0["domain"] as! String == "sceneExposure" }
        var errors: [Double] = []
        func check(_ actual: Double, _ expected: Double) {
            let error = abs(actual - expected) / max(1,abs(expected))
            errors.append(error); XCTAssertLessThanOrEqual(error, 2e-12)
        }
        func exportCube(_ settings: TransformSettings, _ item: [String: Any], _ name: String) async throws {
            let size = item["size"] as! Int
            let lo = (item["minimum"] as? Double) ?? Double(item["minimum"] as! String)!
            let hi = (item["maximum"] as? Double) ?? Double(item["maximum"] as! String)!
            let domain = try LUTDomain(min: RGB64(lo,lo,lo), max: RGB64(hi,hi,hi))
            let doc = try LUTProjectDocument(new: ProjectManifest(settings: settings, cubeSize: size, domain: domain))
            let project = folder.appendingPathComponent(name + ".lutcalc")
            try doc.makeFileWrapper().write(to: project, options: .atomic, originalContentsURL: nil)
            let reopened = try LUTProjectDocument(fileWrapper: FileWrapper(url: project))
            XCTAssertEqual(reopened.manifest, doc.manifest)
            let path = folder.appendingPathComponent(name + ".cube")
            _ = try await NativeExportService().generate(reopened.makeGenerationRequest(workerCount: 4), to: path)
            let lut = try CubeParser.parse(Data(contentsOf: path)), expected = (item["outputs"] as! [String]).map { Double($0)! }
            XCTAssertEqual(lut.samples.count, size*size*size)
            for i in 0..<lut.samples.count { for c in 0..<3 {
                check(lut.samples[i][c], expected[[i % size,(i/size) % size,i/(size*size)][c]])
            }}
        }
        for item in grids {
            try await exportCube(settings(item), item, "\(item["firmware"]!)-\(item["exposureIndex"]!)-\(item["direction"]!)-\(item["size"]!)")
        }
        for item in independent["mixedGrids"] as! [[String: Any]] {
            let a = try ARRILogCSceneSettings(algorithm: .sup2Published, exposureIndex: 800)
            let b = try ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: 1600)
            let s = TransformSettings(inputTransfer: a.algorithm.transferID, outputTransfer: b.algorithm.transferID,
                inputSpace: .rec2020, outputSpace: .rec2020, inputRange: .data, outputRange: .data,
                exposureStops: item["exposureStops"] as! Double, inputLogC: a, outputLogC: b)
            try await exportCube(s, item, "mixed-\(item["size"]!)")
        }
        for item in independent["axes1024"] as! [[String: Any]] {
            let lo = item["minimum"] as! Double, hi = item["maximum"] as! Double
            let domain = try LUTDomain(min: RGB64(lo,lo,lo), max: RGB64(hi,hi,hi))
            let doc = try LUTProjectDocument(new: ProjectManifest(settings: settings(item), cubeSize: 33, domain: domain))
            let path = folder.appendingPathComponent("\(item["firmware"]!)-\(item["direction"]!).spi1d")
            _ = try await NativeExportService().generate(doc.makeGenerationRequest(workerCount: 4), to: path)
            let lut = try SPI1DParser.parse(Data(contentsOf: path)).lut, expected = (item["outputs"] as! [String]).map { Double($0)! }
            XCTAssertEqual(lut.samples.count, 1024)
            for i in 0..<1024 { for c in 0..<3 { check(lut.samples[i][c], expected[i]) }}
        }
        let sorted = errors.sorted(), report: [String: Any] = ["channels":errors.count,"max":sorted.last!,
            "RMS":sqrt(errors.reduce(0){$0+$1*$1}/Double(errors.count)),"P99":sorted[Int(ceil(Double(errors.count)*0.99))-1],
            "cubeFiles":10,"spi1dFiles":4,"threshold":2e-12]
        try JSONSerialization.data(withJSONObject: report, options: .sortedKeys).write(to: folder.appendingPathComponent("numeric-results.json"))
        print("Log C scene actual files: \(report)"); try retain(folder)
    }
    func testBackendEIEditsBatchFingerprintGammaImportAndImmutableSnapshot() throws {
        let base = TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020, inputRange: .data, outputRange: .data, exposureStops: 0)
        var doc = try LUTProjectDocument(new: ProjectManifest(settings: base, cubeSize: 33, domain: .unit,
            exposureBatchPreset: ExposureBatchPreset(sequence: ExposureBatchSequence(minimumStops: 0, maximumStops: 1, subdivisions: 3), basename: "LogC", format: .cube)))
        let a = try ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: 800)
        try doc.applyLogCScene(a, slot: .input, expectedRevision: doc.revision)
        try doc.applyLogCScene(a, slot: .output, expectedRevision: doc.revision)
        let first = try doc.makeGenerationRequest(), batch = try doc.makeStoredExposureBatchRequest(directory: .init(fileURLWithPath: "/tmp"))
        let oldRevision = doc.revision
        try doc.applyLogCScene(ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: 1600), slot: .output, expectedRevision: doc.revision)
        XCTAssertThrowsError(try doc.applyLogCScene(a, slot: .output, expectedRevision: oldRevision))
        XCTAssertNotEqual(batch.fingerprint, try doc.makeStoredExposureBatchRequest(directory: .init(fileURLWithPath: "/tmp")).fingerprint)
        XCTAssertEqual(first.plan.settings.outputLogC?.exposureIndex, 800)
        XCTAssertTrue(doc.undo()); XCTAssertEqual(doc.manifest.settings.outputLogC?.exposureIndex, 800)
        XCTAssertTrue(doc.redo()); XCTAssertEqual(doc.manifest.settings.outputLogC?.exposureIndex, 1600)
        _ = try doc.storeImportedUserLUT(NativeUserLUTLoader.parse(Data("LUT_1D_SIZE 2\n0 0 0\n1 1 1\n".utf8), named: "user.cube"))
        XCTAssertEqual(doc.manifest.settings.inputLogC, a); XCTAssertEqual(doc.manifest.settings.outputLogC?.exposureIndex, 1600)
        let preset = doc.manifest.exposureBatchPreset
        try doc.applyParameterizedGamma(.init(exponent: "2", linearSlope: "1", offset: "0", linearCut: "0", encodedCut: ""), slot: .input, expectedRevision: doc.revision)
        XCTAssertNil(doc.manifest.settings.inputLogC); XCTAssertEqual(doc.manifest.settings.outputLogC?.exposureIndex, 1600)
        XCTAssertEqual(doc.manifest.exposureBatchPreset, preset)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("logc-backend-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let project = folder.appendingPathComponent("self-contained.lutcalc")
        try doc.makeFileWrapper().write(to: project, options: .atomic, originalContentsURL: nil)
        let editor = EditorSession(); try editor.openProject(at: project)
        XCTAssertEqual(try editor.makeSnapshot().plan.settings.outputLogC?.exposureIndex, 1600)
        XCTAssertNotNil(try editor.makeSnapshot().postLUT); try retain(folder)
    }
    func testWorkerDeterminismCancellationAndStage2FailureLocation() async throws {
        let payload = try ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: 1600)
        let settings = TransformSettings(inputTransfer: .arriLogCSUP3Scene, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020, inputRange: .data, outputRange: .data, exposureStops: 0, inputLogC: payload)
        let plan = try TransformPlan(settings: settings); var previous: [RGB64]?
        for workers in [1,4] {
            let sink = InMemoryCubeSink()
            _ = try await GenerationCoordinator().generate(LUTGenerationRequest(plan: plan, size: 33, domain: .unit, blockNodes: 17, workerCount: workers), sink: sink)
            let samples = await sink.samples
            if let previous { XCTAssertEqual(previous, samples) } else { previous = samples }
        }
        let cancelled = InMemoryCubeSink(cancelAtBlock: 1)
        do { _ = try await GenerationCoordinator().generate(LUTGenerationRequest(plan: plan, size: 33, domain: .unit, blockNodes: 17), sink: cancelled); XCTFail("Expected cancellation") }
        catch is CancellationError {}
        let cancelledState = await cancelled.state; XCTAssertEqual(cancelledState, .aborted)
        let badDomain = try LUTDomain(min: RGB64(100,100,100), max: RGB64(101,101,101)), sink = InMemoryCubeSink()
        do { _ = try await GenerationCoordinator().generate(LUTGenerationRequest(plan: plan, size: 17, domain: badDomain, workerCount: 1), sink: sink); XCTFail("Expected stage 2 failure") }
        catch { XCTAssertEqual(error as? PlanError, .numeric(stageID: 2, sampleIndex: 0)) }
        let failedState = await sink.state; XCTAssertEqual(failedState, .aborted)
    }
}

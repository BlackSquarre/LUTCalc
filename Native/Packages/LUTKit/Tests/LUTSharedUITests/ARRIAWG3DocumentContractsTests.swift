import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTCatalog
import LUTJobs
import LUTFormats
import LUTSharedUI

@MainActor final class ARRIAWG3DocumentContractsTests: XCTestCase {
    private func root() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private func retain(_ folder: URL) throws {
        if let target = ProcessInfo.processInfo.environment["LUTCALC_AWG3_ARTIFACT_DIR"] {
            let parent = URL(fileURLWithPath: target)
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: folder, to: parent.appendingPathComponent(folder.lastPathComponent))
        }
    }
    private func settings(ei: Int, cat: ChromaticAdaptation, decoding: Bool) throws -> TransformSettings {
        let payload = try ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: ei)
        return TransformSettings(inputTransfer: decoding ? .arriLogCSUP3Scene : .linearScene,
            outputTransfer: decoding ? .linearScene : .arriLogCSUP3Scene,
            inputSpace: decoding ? .arriWideGamut3 : .acesAP0, outputSpace: decoding ? .acesAP0 : .arriWideGamut3,
            inputRange: .data, outputRange: .data, exposureStops: 0, adaptation: cat,
            inputLogC: decoding ? payload : nil, outputLogC: decoding ? nil : payload)
    }
    func testAllEightFullCubeFilesAndDiskProjectsAgainstIndependentDecimal() async throws {
        let fixtures = root().appendingPathComponent("tests/fixtures/native-contracts")
        let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: fixtures.appendingPathComponent("arri-awg3-independent.json"))) as! [String: Any]
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("awg3-files-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var errors: [Double] = []
        let grids = raw["grids"] as! [[String: Any]]; XCTAssertEqual(grids.count, 8)
        for item in grids {
            let s = try settings(ei: item["exposureIndex"] as! Int,
                cat: ChromaticAdaptation(rawValue: item["adaptation"] as! String)!, decoding: item["direction"] as! String == "decode")
            let size = item["size"] as! Int, lo = item["minimum"] as! Double, hi = item["maximum"] as! Double
            let domain = try LUTDomain(min: RGB64(lo,lo,lo), max: RGB64(hi,hi,hi))
            let doc = try LUTProjectDocument(new: ProjectManifest(settings: s, cubeSize: size, domain: domain))
            let name = (item["file"] as! String).replacingOccurrences(of: ".f64", with: "")
            let project = folder.appendingPathComponent(name + ".lutcalc")
            try doc.makeFileWrapper().write(to: project, options: .atomic, originalContentsURL: nil)
            let reopened = try LUTProjectDocument(fileWrapper: FileWrapper(url: project))
            XCTAssertEqual(reopened.manifest, doc.manifest)
            let path = folder.appendingPathComponent(name + ".cube")
            _ = try await NativeExportService().generate(reopened.makeGenerationRequest(workerCount: 4), to: path)
            let lut = try CubeParser.parse(Data(contentsOf: path))
            let bytes = try Data(contentsOf: fixtures.appendingPathComponent(item["file"] as! String))
            XCTAssertEqual(lut.samples.count, size*size*size); XCTAssertEqual(bytes.count, size*size*size*3*8)
            for i in 0..<lut.samples.count { for c in 0..<3 {
                let word = bytes.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: (i*3+c)*8, as: UInt64.self) }
                let y = Double(bitPattern: UInt64(littleEndian: word)), error = abs(lut.samples[i][c]-y)/max(1,abs(y))
                errors.append(error); XCTAssertLessThanOrEqual(error, 2e-12)
            }}
        }
        let sorted = errors.sorted(), report: [String: Any] = ["channels":errors.count,"max":sorted.last!,
            "RMS":sqrt(errors.reduce(0){$0+$1*$1}/Double(errors.count)),"P99":sorted[Int(ceil(Double(errors.count)*0.99))-1],
            "cubeFiles":grids.count,"threshold":2e-12]
        try JSONSerialization.data(withJSONObject: report, options: .sortedKeys).write(to: folder.appendingPathComponent("numeric-results.json"))
        print("AWG3 actual files: \(report)"); try retain(folder)
    }
    func testEIBackendEditsAssetsBatchFingerprintsUndoRedoAndDiskSnapshot() throws {
        let s = try settings(ei: 800, cat: .cieCAT02, decoding: true)
        var doc = try LUTProjectDocument(new: ProjectManifest(settings: s, cubeSize: 33, domain: .unit,
            exposureBatchPreset: ExposureBatchPreset(sequence: ExposureBatchSequence(minimumStops: 0, maximumStops: 1, subdivisions: 3), basename: "AWG3", format: .cube)))
        _ = try doc.storeImportedUserLUT(NativeUserLUTLoader.parse(Data("LUT_1D_SIZE 2\n0 0 0\n1 1 1\n".utf8), named: "user.cube"))
        let first = try doc.makeGenerationRequest(), assets = doc.manifest.assetHashes, preset = doc.manifest.exposureBatchPreset
        let old = try doc.makeStoredExposureBatchRequest(directory: URL(fileURLWithPath: "/tmp")), revision = doc.revision
        try doc.applyLogCScene(ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: 1600), slot: .input, expectedRevision: revision)
        XCTAssertThrowsError(try doc.applyLogCScene(ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: 800), slot: .input, expectedRevision: revision))
        XCTAssertEqual(first.plan.settings.inputLogC?.exposureIndex, 800)
        XCTAssertNotEqual(old.fingerprint, try doc.makeStoredExposureBatchRequest(directory: URL(fileURLWithPath: "/tmp")).fingerprint)
        XCTAssertTrue(doc.undo()); XCTAssertEqual(doc.manifest.settings.inputLogC?.exposureIndex, 800)
        XCTAssertTrue(doc.redo()); XCTAssertEqual(doc.manifest.settings.inputLogC?.exposureIndex, 1600)
        XCTAssertEqual(doc.manifest.settings.inputSpace, .arriWideGamut3)
        XCTAssertEqual(doc.manifest.assetHashes, assets); XCTAssertEqual(doc.manifest.exposureBatchPreset, preset)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("awg3-backend-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let project = folder.appendingPathComponent("self-contained.lutcalc")
        try doc.makeFileWrapper().write(to: project, options: .atomic, originalContentsURL: nil)
        let editor = EditorSession(); try editor.openProject(at: project)
        XCTAssertEqual(try editor.makeSnapshot().plan.settings, doc.manifest.settings)
        XCTAssertNotNil(try editor.makeSnapshot().postLUT); try retain(folder)
    }
    func testCrossGamutOneDRejectsWorkersMatchCancellationAndFailureLocate() async throws {
        let plan = try TransformPlan(settings: settings(ei: 1600, cat: .bradford, decoding: true))
        var previous: [RGB64]?
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
        let badDomain = try LUTDomain(min: RGB64(100,100,100), max: RGB64(101,101,101)), failed = InMemoryCubeSink()
        do { _ = try await GenerationCoordinator().generate(LUTGenerationRequest(plan: plan, size: 17, domain: badDomain, workerCount: 1), sink: failed); XCTFail("Expected failure") }
        catch { XCTAssertEqual(error as? PlanError, .numeric(stageID: 2, sampleIndex: 0)) }
        let failedState = await failed.state; XCTAssertEqual(failedState, .aborted)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("cross-gamut.spi1d")
        let doc = try LUTProjectDocument(new: ProjectManifest(settings: plan.settings, cubeSize: 33, domain: .unit))
        do { _ = try await NativeExportService().generate(doc.makeGenerationRequest(), to: path); XCTFail("Expected 1D rejection") }
        catch {
            XCTAssertEqual(error as? SPI1DFailure, SPI1DFailure(.lossyRepresentation, line: 0))
            XCTAssertFalse(FileManager.default.fileExists(atPath: path.path))
        }
    }
}

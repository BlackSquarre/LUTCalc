import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTJobs
import LUTProject
import LUTCatalog
import LUTSharedUI

@MainActor final class ExposureBatchPresetDocumentContractsTests: XCTestCase {
    private func retainArtifact(_ root: URL, label: String) throws {
        guard let artifact = ProcessInfo.processInfo.environment["LUTCALC_BATCH_PRESET_ARTIFACT_DIR"] else { return }
        let parent = URL(fileURLWithPath: artifact)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: root, to: parent.appendingPathComponent(label + "-" + UUID().uuidString))
    }
    private func document() throws -> LUTProjectDocument {
        try LUTProjectDocument(new: ProjectManifest(settings: TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020, inputRange: .data, outputRange: .data,
            exposureStops: 7, finalOutput: FinalOutputSettings(enabled: false)), cubeSize: 33, domain: .unit))
    }
    private func preset(format: LUTExportFormat = .cube) throws -> ExposureBatchPreset {
        try ExposureBatchPreset(sequence: ExposureBatchSequence(minimumStops: -1, maximumStops: 0, subdivisions: 1),
            basename: "存储曝光", format: format, blockNodes: 17, workerCount: 4)
    }
    func testBackendEditsImportUndoAndImmutableStoredSnapshot() throws {
        var doc = try document(); try doc.applyExposureBatchPreset(preset())
        XCTAssertTrue(doc.undo()); XCTAssertNil(doc.manifest.exposureBatchPreset)
        XCTAssertTrue(doc.redo()); let saved = doc.manifest.exposureBatchPreset
        let bytes = Data("LUT_1D_SIZE 2\n0 0 0\n1 0.5 0.25\n".utf8)
        _ = try doc.storeImportedUserLUT(NativeUserLUTLoader.parse(bytes, named: "user.cube"))
        XCTAssertEqual(doc.manifest.exposureBatchPreset, saved)
        try doc.applyUserLUTPostStage(.init(interpolation: .trilinear, outside: .reject))
        XCTAssertEqual(doc.manifest.exposureBatchPreset, saved)
        let folder = FileManager.default.temporaryDirectory
        let request = try doc.makeStoredExposureBatchRequest(directory: folder)
        XCTAssertEqual(request.items.map(\.stop), [-1, 0]); XCTAssertFalse(request.allowOverwrite)
        XCTAssertEqual(request.items[0].request.workerCount, 4); XCTAssertEqual(request.items[0].request.blockNodes, 17)
        XCTAssertEqual(request.items[0].request.size, 33); XCTAssertNotNil(request.items[0].request.postLUT)
        XCTAssertEqual(request.items[0].request.plan.settings.finalOutput, doc.manifest.settings.finalOutput)
        try doc.applyParameterizedGamma(.init(exponent: "2", linearSlope: "1", offset: "0", linearCut: "0", encodedCut: ""),
            slot: .output, expectedRevision: doc.revision)
        XCTAssertEqual(doc.manifest.exposureBatchPreset, saved)
        try doc.applyPreset(try XCTUnwrap(AlgorithmCatalog.builtIn().preset(named: "dji.dlog2-to-dlog2-identity.v1")))
        XCTAssertEqual(doc.manifest.exposureBatchPreset, saved)
        XCTAssertEqual(request.items[0].request.plan.settings.outputTransfer, .linearScene)
        try doc.applyExposureBatchPreset(nil)
        XCTAssertThrowsError(try doc.makeStoredExposureBatchRequest(directory: folder))
    }
    func testSelfContainedDiskReopenRebuildsRequestFingerprintAndActualCubeBatch() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var doc = try document(); try doc.applyExposureBatchPreset(preset())
        let source = root.appendingPathComponent("original-user.cube")
        try Data("LUT_1D_SIZE 2\n0 0 0\n1 0.5 0.25\n".utf8).write(to: source)
        _ = try doc.storeImportedUserLUT(NativeUserLUTLoader.parse(Data(contentsOf: source), named: source.lastPathComponent))
        try doc.applyUserLUTPostStage(.init(interpolation: .trilinear, outside: .reject))
        let before = try doc.makeStoredExposureBatchRequest(directory: root)
        let project = root.appendingPathComponent("batch.lutcalc")
        try doc.makeFileWrapper().write(to: project, options: .atomic, originalContentsURL: nil)
        try FileManager.default.removeItem(at: source)
        let reopened = try LUTProjectDocument(fileWrapper: FileWrapper(url: project))
        let after = try reopened.makeStoredExposureBatchRequest(directory: root)
        XCTAssertEqual(before.fingerprint, after.fingerprint); XCTAssertEqual(reopened.assetContents, doc.assetContents)
        let checkpoint = root.appendingPathComponent("checkpoint")
        let complete = try await ExposureBatchCoordinator().generate(after, exporter: NativeExportService(),
            checkpoint: ExposureBatchCheckpointStore(directory: checkpoint))
        XCTAssertEqual(complete.state, .completed)
        let restored = try await ExposureBatchCoordinator().generate(reopened.makeStoredExposureBatchRequest(directory: root),
            exporter: NativeExportService(), checkpoint: ExposureBatchCheckpointStore(directory: checkpoint), resuming: true)
        XCTAssertEqual(restored.items, complete.items)
        let grid = try Grid3D(size: 33, domain: .unit)
        for item in after.items {
            let lut = try CubeParser.parse(Data(contentsOf: item.url)), gain = item.index == 0 ? 0.5 : 1.0
            for i in 0..<grid.nodeCount { let p = try grid.coordinate(at: i)
                for c in 0..<3 { XCTAssertEqual(lut.samples[i][c], p[c] * gain * [1.0, 0.5, 0.25][c]) }
            }
        }
        let editor = EditorSession(); try editor.openProject(at: project)
        editor.exposureDraft = "-0"; XCTAssertTrue(editor.commitExposure()); try editor.saveProject()
        XCTAssertEqual(try ProjectStore.open(at: project, catalog: AlgorithmCatalog.builtIn()).exposureBatchPreset, doc.manifest.exposureBatchPreset)
        try retainArtifact(root, label: "cube")
        print("Stored batch project independent disk: channels=215622, max=0, RMS=0, P99=0; self-contained source deletion and same checkpoint fingerprint")
    }
    func testSPI1DFixedSizeAndExplicitAuthorizationAreTaskInputs() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var doc = try document(); try doc.applyExposureBatchPreset(preset(format: .spi1d))
        let request = try doc.makeStoredExposureBatchRequest(directory: root)
        let serialized = try ProjectCodec.encode(doc.manifest, catalog: AlgorithmCatalog.builtIn())
        let raw = try JSONSerialization.jsonObject(with: serialized) as! [String: Any]
        let presetObject = raw["exposureBatchPreset"] as! [String: Any]
        XCTAssertNil(presetObject["directory"]); XCTAssertNil(presetObject["allowOverwrite"])
        let authorized = try doc.makeStoredExposureBatchRequest(directory: root, allowOverwrite: true)
        XCTAssertTrue(authorized.allowOverwrite); XCTAssertNotEqual(authorized.fingerprint, request.fingerprint)
        let final = try await ExposureBatchCoordinator().generate(request, exporter: NativeExportService())
        XCTAssertEqual(final.items.map(\.writtenNodes), [1024, 1024])
        for item in request.items {
            let lut = try SPI1DParser.parse(Data(contentsOf: item.url)).lut
            for i in 0..<1024 { for c in 0..<3 {
                XCTAssertEqual(lut.samples[i][c], Double(i) / 1023 * (item.index == 0 ? 0.5 : 1))
            }}
        }
        try doc.makeFileWrapper().write(to: root.appendingPathComponent("batch.lutcalc"), options: .atomic, originalContentsURL: nil)
        try retainArtifact(root, label: "spi1d")
    }
}

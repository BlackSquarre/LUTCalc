import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTJobs
import LUTProject
import LUTCatalog
import LUTSharedUI

@MainActor final class ExposureBatchThreeDLFlavorContractsTests: XCTestCase {
    private let flavors: [ThreeDLFlavor] = [.flame, .lustre, .kodak]
    private func settings() -> TransformSettings {
        TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020, inputRange: .data, outputRange: .data, exposureStops: 7)
    }
    private func sequence() throws -> ExposureBatchSequence {
        try ExposureBatchSequence(minimumStops: -1, maximumStops: 0, subdivisions: 1)
    }
    private func root(_ name: String) throws -> URL {
        let base = ProcessInfo.processInfo.environment["LUTCALC_BATCH_FLAVOR_ARTIFACT_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let folder = base.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
    private func clean(_ folder: URL) {
        if ProcessInfo.processInfo.environment["LUTCALC_BATCH_FLAVOR_ARTIFACT_DIR"] == nil {
            try? FileManager.default.removeItem(at: folder.deletingLastPathComponent())
        }
    }
    private func base(size: Int = 17, shaped: Bool = false) throws -> LUTGenerationRequest {
        let shaper: CubeShaper? = try shaped ? CubeShaper(size: size, domain: .unit,
            samples: (0..<size).map { i in
                let x = Double(i) / Double(size - 1)
                let value = (1023 * x * x).rounded(.toNearestOrAwayFromZero) / 1023
                return try RGB64(value, value, value)
            }) : nil
        return try LUTGenerationRequest(plan: TransformPlan(settings: settings()), size: size,
            domain: .unit, blockNodes: 127, workerCount: 4, inputShaper: shaper)
    }
    private func batch(_ folder: URL, flavor: ThreeDLFlavor, size: Int = 17,
                       shaped: Bool = false, format: FileLUTFormat = .threeDL,
                       allowOverwrite: Bool = false) throws -> ExposureBatchRequest {
        try ExposureBatchRequest(base: base(size: size, shaped: shaped), settings: sequence(),
            directory: folder, basename: "batch", format: format, allowOverwrite: allowOverwrite, threeDLFlavor: flavor)
    }
    private func check(_ request: ExposureBatchRequest, shaped: Bool) throws {
        for item in request.items {
            let data = try Data(contentsOf: item.url), text = try XCTUnwrap(String(data: data, encoding: .utf8))
            XCTAssertEqual(text.contains("3DMESH\n"), request.threeDLFlavor == .lustre)
            XCTAssertEqual(text.hasSuffix("LUT8\ngamma 1.0\n"), request.threeDLFlavor == .lustre)
            let lut = try ThreeDLParser.parse(data, flavor: request.threeDLFlavor)
            let size = item.request.size
            XCTAssertEqual(lut.size, size); XCTAssertEqual(lut.samples.count, size * size * size)
            XCTAssertEqual(lut.shaper, shaped ? item.request.inputShaper : nil)
            for i in lut.samples.indices {
                let axes = [i % size, i / size % size, i / (size * size)]
                for c in 0..<3 {
                    let input = shaped ? try XCTUnwrap(item.request.inputShaper).samples[axes[c]][c]
                        : Double(axes[c]) / Double(size - 1)
                    let expected = (input * pow(2, item.stop) * 4095).rounded(.toNearestOrAwayFromZero) / 4095
                    XCTAssertEqual(lut.samples[i][c], expected, accuracy: 2e-12)
                }
            }
        }
    }

    func testFlavorFingerprintsDefaultCompatibilityAndInvalidCombinations() throws {
        let folder = URL(fileURLWithPath: "/Users/lingru/claude/LUTCalc/docs/native-validation/artifacts/2026-10-03-batch-format-shaper/debug/format-3dl")
        let plain = try ExposureBatchRequest(base: base(), settings: sequence(), directory: folder,
            basename: "batch", format: .threeDL)
        let requests = try flavors.map { try batch(folder, flavor: $0) }
        XCTAssertEqual(plain.fingerprint, requests[0].fingerprint)
        // Frozen from the preceding accepted checkpoint; this is a read-only request.
        XCTAssertEqual(plain.fingerprint, "063239c1008d6e1b01e5ba88677bcded9d767b41611381a47376fe81d557254b")
        XCTAssertEqual(Set(requests.map(\.fingerprint)).count, 3)
        XCTAssertEqual(requests.map(\.threeDLFlavor), flavors)
        for format in FileLUTFormat.allCases where format != .threeDL {
            for flavor in [ThreeDLFlavor.lustre, .kodak] {
                XCTAssertThrowsError(try batch(folder, flavor: flavor, format: format))
            }
        }
    }

    func testAllThreeFlavorShapersKeepFull17And33And65Grids() async throws {
        for flavor in flavors { for size in [17, 33, 65] {
            let folder = try root("\(flavor.rawValue)-\(size)"); defer { clean(folder) }
            let request = try batch(folder, flavor: flavor, size: size, shaped: true)
            let report = try await ExposureBatchCoordinator().generate(request, exporter: NativeExportService())
            XCTAssertEqual(report.state, .completed)
            XCTAssertEqual(report.items.map(\.writtenNodes), [size * size * size, size * size * size])
            try check(request, shaped: true)
        }}
    }

    func testDurableResumePreservesFlavorAndRejectsChangedFlavor() async throws {
        let folder = try root("resume-lustre"); defer { clean(folder) }
        let request = try batch(folder, flavor: .lustre)
        let changed = try batch(folder, flavor: .kodak)
        let checkpoint = folder.appendingPathComponent("checkpoint")
        let report = try await ExposureBatchCoordinator().generate(request, exporter: FlavorInterruptExporter(),
            checkpoint: ExposureBatchCheckpointStore(directory: checkpoint))
        XCTAssertEqual(report.items.map(\.state), [.completed, .cancelled])
        let first = try Data(contentsOf: request.items[0].url)
        do {
            _ = try await ExposureBatchCoordinator().generate(changed, exporter: NativeExportService(), resumeFrom: report)
            XCTFail("Changed grammar must not resume a report")
        } catch { XCTAssertEqual(error as? ExposureBatchError, .checkpointMismatch) }
        do {
            _ = try await ExposureBatchCoordinator().generate(changed, exporter: NativeExportService(),
                checkpoint: ExposureBatchCheckpointStore(directory: checkpoint), resuming: true)
            XCTFail("Changed grammar must not resume a checkpoint")
        } catch { XCTAssertEqual(error as? ExposureBatchError, .checkpointMismatch) }
        XCTAssertEqual(try Data(contentsOf: request.items[0].url), first)
        let completed = try await ExposureBatchCoordinator().generate(request, exporter: NativeExportService(),
            checkpoint: ExposureBatchCheckpointStore(directory: checkpoint), resuming: true)
        XCTAssertEqual(completed.state, .completed); XCTAssertEqual(completed.items[0], report.items[0])
        XCTAssertEqual(try Data(contentsOf: request.items[0].url), first)
        try check(request, shaped: false)
    }

    func testLegacyExporterAdapterRejectsNonDefaultGrammarBeforeOutput() async throws {
        let folder = try root("legacy-exporter"); defer { clean(folder) }
        let adapter = LegacyFlavorExporter()
        let rejected = try await ExposureBatchCoordinator().generate(batch(folder, flavor: .lustre), exporter: adapter)
        XCTAssertEqual(rejected.state, .failed)
        let rejectedCallCount = await adapter.callCount()
        XCTAssertEqual(rejectedCallCount, 0)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
        let request = try batch(folder, flavor: .flame)
        let completed = try await ExposureBatchCoordinator().generate(request, exporter: adapter)
        XCTAssertEqual(completed.state, .completed)
        try check(request, shaped: false)
    }

    func testNonDefaultGrammarPreservesExplicitOverwriteAuthorization() async throws {
        let folder = try root("overwrite-lustre"); defer { clean(folder) }
        let original = try batch(folder, flavor: .lustre)
        let initial = try await ExposureBatchCoordinator().generate(original, exporter: NativeExportService())
        XCTAssertEqual(initial.state, .completed)
        let first = try Data(contentsOf: original.items[0].url)
        let denied = try await ExposureBatchCoordinator().generate(original, exporter: NativeExportService())
        XCTAssertEqual(denied.items.map(\.state), [.failed, .pending])
        XCTAssertEqual(try Data(contentsOf: original.items[0].url), first)
        let authorized = try batch(folder, flavor: .lustre, size: 33, allowOverwrite: true)
        let completed = try await ExposureBatchCoordinator().generate(authorized, exporter: NativeExportService())
        XCTAssertEqual(completed.state, .completed)
        XCTAssertNotEqual(try Data(contentsOf: original.items[0].url), first)
        try check(authorized, shaped: false)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: folder.path).contains { $0.hasPrefix(".lutcalc-") })
    }

    func testSchema24RoundtripMigrationPreservesOldDiskBytesAndUndoRedo() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(ProjectManifest.currentSchema, 27)
        for flavor in flavors {
            let preset = try ExposureBatchPreset(sequence: sequence(), basename: "batch", format: .threeDL,
                blockNodes: 127, workerCount: 4, threeDLFlavor: flavor)
            let manifest = ProjectManifest(settings: settings(), cubeSize: 17, domain: .unit, exposureBatchPreset: preset)
            XCTAssertEqual(manifest.algorithmVersions["exposureBatchFormat"], ThreeDLFlavor.batchAlgorithm)
            XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(manifest, catalog: catalog), catalog: catalog), manifest)
            let folder = try root("project-\(flavor.rawValue)"); defer { clean(folder) }
            var session = try ProjectEditingSession(new: manifest.withExposureBatchPreset(nil), catalog: catalog)
            try session.apply(manifest); XCTAssertTrue(session.undo()); XCTAssertTrue(session.redo())
            let url = folder.appendingPathComponent("current.lutcalc")
            try session.save(to: url)
            XCTAssertEqual(try ProjectStore.open(at: url, catalog: catalog), manifest)
            var raw = try JSONSerialization.jsonObject(with: ProjectCodec.encode(manifest, catalog: catalog)) as! [String: Any]
            raw["schemaVersion"] = 23
            var object = raw["exposureBatchPreset"] as! [String: Any]; object.removeValue(forKey: "threeDLFlavor")
            raw["exposureBatchPreset"] = object
            var versions = raw["algorithmVersions"] as! [String: String]; versions.removeValue(forKey: "exposureBatchFormat")
            raw["algorithmVersions"] = versions
            let original = try JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys])
            let old = folder.appendingPathComponent("schema23.lutcalc")
            try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
            let source = old.appendingPathComponent("manifest.json"); try original.write(to: source)
            let migrated = try ProjectStore.open(at: old, catalog: catalog)
            XCTAssertEqual(migrated.schemaVersion, ProjectManifest.currentSchema)
            XCTAssertEqual(migrated.exposureBatchPreset?.threeDLFlavor, .flame)
            XCTAssertEqual(migrated.algorithmVersions["exposureBatchFormat"], ThreeDLFlavor.batchAlgorithm)
            XCTAssertEqual(try Data(contentsOf: source), original)
        }
    }

    func testStrictFlavorSchemaAndAlgorithmFields() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let preset = try ExposureBatchPreset(sequence: sequence(), basename: "batch", format: .threeDL, threeDLFlavor: .lustre)
        let manifest = ProjectManifest(settings: settings(), cubeSize: 17, domain: .unit, exposureBatchPreset: preset)
        let bytes = try ProjectCodec.encode(manifest, catalog: catalog)
        let raw = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
        for value: Any in ["unknown", NSNull(), 1] {
            var root = raw, object = root["exposureBatchPreset"] as! [String: Any]
            object["threeDLFlavor"] = value; root["exposureBatchPreset"] = object
            XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: root), catalog: catalog))
        }
        var missing = raw, object = missing["exposureBatchPreset"] as! [String: Any]
        object.removeValue(forKey: "threeDLFlavor"); missing["exposureBatchPreset"] = object
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: missing), catalog: catalog))
        for schema in 16...23 {
            var old = raw; old["schemaVersion"] = schema
            let data = try JSONSerialization.data(withJSONObject: old)
            XCTAssertThrowsError(try ProjectCodec.decode(data, catalog: catalog))
            XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self, from: data))
        }
        var wrong = raw, versions = wrong["algorithmVersions"] as! [String: String]
        versions["exposureBatchFormat"] = "unknown"; wrong["algorithmVersions"] = versions
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject: wrong), catalog: catalog))
        let duplicate = try XCTUnwrap(String(data: bytes, encoding: .utf8))
            .replacingOccurrences(of: "\"threeDLFlavor\":\"lustre\"", with: "\"threeDLFlavor\":\"lustre\",\"threeDLFlavor\":\"flame\"")
        XCTAssertThrowsError(try ProjectCodec.decode(Data(duplicate.utf8), catalog: catalog))
        XCTAssertThrowsError(try ExposureBatchPreset(sequence: sequence(), basename: "batch", format: .cube, threeDLFlavor: .lustre))
    }

    func testDocumentDiskReopenCapturesPresetFlavorAndActualBatch() async throws {
        for flavor in flavors {
            let folder = try root("document-\(flavor.rawValue)"); defer { clean(folder) }
            var document = try LUTProjectDocument(new: ProjectManifest(settings: settings(), cubeSize: 17, domain: .unit))
            try document.applyExposureBatchPreset(ExposureBatchPreset(sequence: sequence(), basename: "batch", format: .threeDL,
                blockNodes: 127, workerCount: 4, threeDLFlavor: flavor))
            let before = try document.makeStoredExposureBatchRequest(directory: folder)
            let explicit = try document.makeExposureBatchRequest(settings: sequence(), directory: folder,
                basename: "batch", format: .threeDL, threeDLFlavor: flavor)
            XCTAssertEqual(explicit.threeDLFlavor, flavor)
            let project = folder.appendingPathComponent("batch.lutcalc")
            try document.makeFileWrapper().write(to: project, options: .atomic, originalContentsURL: nil)
            let reopened = try LUTProjectDocument(fileWrapper: FileWrapper(url: project))
            let request = try reopened.makeStoredExposureBatchRequest(directory: folder)
            XCTAssertEqual(before.fingerprint, request.fingerprint)
            XCTAssertEqual(request.threeDLFlavor, flavor)
            try document.applyExposureBatchPreset(nil)
            XCTAssertEqual(before.threeDLFlavor, flavor)
            let report = try await ExposureBatchCoordinator().generate(request, exporter: NativeExportService())
            XCTAssertEqual(report.state, .completed)
            try check(request, shaped: false)
        }
    }
}

private actor FlavorInterruptExporter: ExposureBatchExporter {
    private var count = 0
    func generate(_ request: LUTGenerationRequest, to output: URL, allowOverwrite: Bool) async throws -> Int {
        try await generate(request, to: output, allowOverwrite: allowOverwrite, threeDLFlavor: .flame)
    }
    func generate(_ request: LUTGenerationRequest, to output: URL, allowOverwrite: Bool,
                  threeDLFlavor: ThreeDLFlavor) async throws -> Int {
        count += 1
        if count == 2 { throw CancellationError() }
        return try await NativeExportService().generate(request, to: output, allowOverwrite: allowOverwrite,
            threeDLFlavor: threeDLFlavor)
    }
}

private actor LegacyFlavorExporter: ExposureBatchExporter {
    private var count = 0
    func callCount() -> Int { count }
    func generate(_ request: LUTGenerationRequest, to output: URL, allowOverwrite: Bool) async throws -> Int {
        count += 1
        return try await NativeExportService().generate(request, to: output, allowOverwrite: allowOverwrite)
    }
}

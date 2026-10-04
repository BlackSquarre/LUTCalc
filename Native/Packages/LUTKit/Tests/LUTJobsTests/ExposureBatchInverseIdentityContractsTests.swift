import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTAnalysis
import LUTJobs
import LUTSharedUI

final class ExposureBatchInverseIdentityContractsTests: XCTestCase {
    private func transfer(size: Int = 17, scale: RGB64 = try! RGB64(2, 2, 2),
                          domain: LUTDomain = .unit, title: String? = nil) throws -> CubeLUT {
        try CubeLUT(dimension: .one, size: size, domain: domain,
            samples: (0..<size).map { i in
                let x = Double(i) / Double(size - 1)
                return try RGB64(x * scale.r, x * scale.g, x * scale.b)
            }, title: title)
    }
    private func inverse(_ lut: CubeLUT, selected: CubeLUT? = nil) throws -> ImportedLUTInversePlan {
        let analysis = selected.map { LUTAnalysisFile(title: "metadata", transferLUT: $0,
            colourLUT: nil, transferMetadata: LUTAnalysisSectionMetadata(),
            colourMetadata: nil, sourceFormat: "synthetic-test") }
        return try ImportedLUTInversePlan(lut: lut, analysisFile: analysis, interpolation: .tricubicLegacyV1)
    }
    private func batch(_ inverse: ImportedLUTInversePlan, folder: URL,
                       post: CubeLUT? = nil) throws -> ExposureBatchRequest {
        let plan = try TransformPlan(settings: TransformSettings(inputTransfer: .linearScene,
            outputTransfer: .linearScene, inputSpace: .rec2020, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 0))
        return try ExposureBatchRequest(base: LUTGenerationRequest(plan: plan, size: 17,
            domain: .unit, blockNodes: 127, workerCount: 4, postLUT: post,
            inputTransferInverse: inverse),
            settings: ExposureBatchSettings(minimumStops: -1, maximumStops: 0, subdivisions: 1),
            directory: folder, basename: "inverse", format: .cube)
    }

    func testIdentityBindsActualInverseSamplesDomainsAndSize() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("inverse-identity")
        let lut = try transfer(), original = try batch(inverse(lut), folder: folder)
        for changed in [try transfer(scale: RGB64(1, 2, 2)),
                        try transfer(size: 33),
                        try transfer(domain: LUTDomain(min: RGB64(-1, -2, -3), max: RGB64(2, 3, 4)))] {
            XCTAssertNotEqual(original.fingerprint, try batch(inverse(changed), folder: folder).fingerprint)
        }
        let renamed = try transfer(title: "different provenance title")
        XCTAssertEqual(original.fingerprint, try batch(inverse(renamed), folder: folder).fingerprint)
        XCTAssertEqual(original.fingerprint, try batch(inverse(lut), folder: folder).fingerprint)
        if let artifact = ProcessInfo.processInfo.environment["LUTCALC_BATCH_INVERSE_ARTIFACT_DIR"] {
            let root = URL(fileURLWithPath: artifact, isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            try encoder.encode(["contentFingerprint": inverse(lut).contentFingerprint])
                .write(to: root.appendingPathComponent("inverse-content.json"))
        }
    }

    func testSelectedAnalysisTransferBindsIdentityEvenWithSamePostLUT() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("inverse-selected")
        let source = try transfer(scale: RGB64(1, 1, 1)), selected = try transfer()
        let direct = try batch(inverse(selected), folder: folder, post: source)
        let fromAnalysis = try batch(inverse(source, selected: selected), folder: folder, post: source)
        XCTAssertEqual(direct.fingerprint, fromAnalysis.fingerprint)
        XCTAssertNotEqual(fromAnalysis.fingerprint,
            try batch(inverse(source, selected: source), folder: folder, post: source).fingerprint)
    }

    func testChangedInverseCannotResumeReportOrDurableCheckpoint() async throws {
        let configured = ProcessInfo.processInfo.environment["LUTCALC_BATCH_INVERSE_ARTIFACT_DIR"]
        let folder = configured.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { if configured == nil { try? FileManager.default.removeItem(at: folder) } }
        let original = try batch(inverse(transfer()), folder: folder)
        let changed = try batch(inverse(transfer(scale: RGB64(1, 1, 1))), folder: folder)
        let checkpoint = folder.appendingPathComponent("checkpoint")
        let report = try await ExposureBatchCoordinator().generate(original,
            exporter: InverseIdentityInterruptExporter(), checkpoint: ExposureBatchCheckpointStore(directory: checkpoint))
        XCTAssertEqual(report.items.map(\.state), [.completed, .cancelled])
        let first = try Data(contentsOf: original.items[0].url)
        do {
            _ = try await ExposureBatchCoordinator().generate(changed, exporter: NativeExportService(), resumeFrom: report)
            XCTFail("A different inverse must not reuse completed files")
        } catch { XCTAssertEqual(error as? ExposureBatchError, .checkpointMismatch) }
        do {
            _ = try await ExposureBatchCoordinator().generate(changed, exporter: NativeExportService(),
                checkpoint: ExposureBatchCheckpointStore(directory: checkpoint), resuming: true)
            XCTFail("A different inverse must not reuse a durable checkpoint")
        } catch { XCTAssertEqual(error as? ExposureBatchError, .checkpointMismatch) }
        XCTAssertEqual(try Data(contentsOf: original.items[0].url), first)
        guard !FileManager.default.fileExists(atPath: original.items[1].url.path) else {
            XCTFail("Rejected recovery must not publish the second file"); return
        }
        let completed = try await ExposureBatchCoordinator().generate(original, exporter: NativeExportService(),
            checkpoint: ExposureBatchCheckpointStore(directory: checkpoint), resuming: true)
        XCTAssertEqual(completed.state, .completed)
        XCTAssertEqual(completed.items[0], report.items[0])
        XCTAssertEqual(try Data(contentsOf: original.items[0].url), first)
        for item in original.items {
            let lut = try CubeParser.parse(Data(contentsOf: item.url))
            XCTAssertEqual(lut.samples.count, 17 * 17 * 17)
            for i in lut.samples.indices {
                let axes = [i % 17, i / 17 % 17, i / (17 * 17)]
                for c in 0..<3 {
                    let expected = Double(axes[c]) / 32 * pow(2, item.stop)
                    XCTAssertEqual(lut.samples[i][c], expected, accuracy: 2e-12)
                }
            }
        }
    }
}

private actor InverseIdentityInterruptExporter: ExposureBatchExporter {
    private var count = 0
    func generate(_ request: LUTGenerationRequest, to output: URL, allowOverwrite: Bool) async throws -> Int {
        count += 1
        if count == 2 { throw CancellationError() }
        return try await NativeExportService().generate(request, to: output, allowOverwrite: allowOverwrite)
    }
}

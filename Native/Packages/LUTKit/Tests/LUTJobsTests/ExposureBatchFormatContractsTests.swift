import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTJobs
import LUTSharedUI

final class ExposureBatchFormatContractsTests: XCTestCase {
    private func folder(_ name: String) throws -> URL {
        let root = ProcessInfo.processInfo.environment["LUTCALC_BATCH_FORMAT_ARTIFACT_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func cleanup(_ url: URL) {
        if ProcessInfo.processInfo.environment["LUTCALC_BATCH_FORMAT_ARTIFACT_DIR"] == nil {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
    }
    private func base(size: Int = 17, shaper: CubeShaper? = nil) throws -> LUTGenerationRequest {
        try LUTGenerationRequest(plan: TransformPlan(settings: TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 7)),
            size: size, domain: .unit, blockNodes: 127, workerCount: 4, inputShaper: shaper)
    }
    private func shaper(size: Int = 17, delta: Int = 0) throws -> CubeShaper {
        let samples = try (0..<size).map { index in
            let x = Double(index) / Double(size - 1)
            let code = Int((1023 * x * x).rounded(.toNearestOrAwayFromZero))
                + (index == size / 2 ? delta : 0)
            let y = Double(code) / 1023
            return try RGB64(y, y, y)
        }
        return try CubeShaper(size: size, domain: .unit, samples: samples)
    }
    private func batch(_ base: LUTGenerationRequest, directory: URL,
                       format: LUTExportFormat = .threeDL) throws -> ExposureBatchRequest {
        try ExposureBatchRequest(base: base,
            settings: ExposureBatchSettings(minimumStops: -1, maximumStops: 0, subdivisions: 1),
            directory: directory, basename: "batch", format: format)
    }
    private func parse(_ data: Data, format: LUTExportFormat) throws -> CubeLUT {
        switch format {
        case .cube: try CubeParser.parse(data)
        case .spi3d: try SPI3DParser.parse(data)
        case .spi1d: try SPI1DParser.parse(data).lut
        case .threeDL: try ThreeDLParser.parse(data, flavor: .flame)
        case .vlt: try VLTParser.parse(data)
        case .ilut: try ILUTParser.parse(data)
        case .olut: try OLUTParser.parse(data)
        case .lut: try AssimilateLUTParser.parse(data)
        }
    }

    func testSnapshotAndFingerprintIncludeInputShaperContentAndDomain() throws {
        let url = try folder("snapshot"); defer { cleanup(url) }
        let original = try shaper(), changed = try shaper(delta: 1)
        let request = try batch(base(shaper: original), directory: url)
        XCTAssertTrue(request.items.allSatisfy { $0.request.inputShaper == original })
        XCTAssertTrue(request.items.allSatisfy { $0.request.inputShaperSampler != nil })
        XCTAssertNotEqual(request.fingerprint, try batch(base(shaper: changed), directory: url).fingerprint)
        XCTAssertNotEqual(request.fingerprint, try batch(base(), directory: url).fingerprint)
        let domain = try LUTDomain(min: RGB64(-1, -1, -1), max: RGB64(2, 2, 2))
        let shifted = try CubeShaper(size: original.size, domain: domain, samples: original.samples)
        XCTAssertNotEqual(request.fingerprint, try batch(base(shaper: shifted), directory: url).fingerprint)
        XCTAssertEqual(request.fingerprint, try batch(base(shaper: original), directory: url).fingerprint)
        XCTAssertEqual(request.items.map(\.request.plan.settings.exposureStops), [-1, 0])
    }

    func testNonlinearShaperBatchesKeepFull17And33And65Grids() async throws {
        for size in [17, 33, 65] {
            let url = try folder("shaper-\(size)"); defer { cleanup(url) }
            let curve = try shaper(size: size)
            let request = try batch(base(size: size, shaper: curve), directory: url)
            let report = try await ExposureBatchCoordinator().generate(request, exporter: NativeExportService())
            XCTAssertEqual(report.state, .completed)
            for item in request.items {
                let lut = try parse(Data(contentsOf: item.url), format: .threeDL)
                XCTAssertEqual(lut.shaper, curve)
                guard lut.shaper == curve else { continue }
                XCTAssertEqual(report.items[item.index].writtenNodes, size * size * size)
                for index in lut.samples.indices {
                    let axes = [index % size, index / size % size, index / (size * size)]
                    for channel in 0..<3 {
                        let expected = (curve.samples[axes[channel]][channel] * pow(2, item.stop) * 4095)
                            .rounded(.toNearestOrAwayFromZero) / 4095
                        XCTAssertEqual(lut.samples[index][channel], expected, accuracy: 2e-12)
                    }
                }
            }
            XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: url.path)
                .contains { $0.hasPrefix(".lutcalc-") })
        }
    }

    func testChangedShaperCannotResumeReportOrDurableCheckpoint() async throws {
        let url = try folder("shaper-resume"); defer { cleanup(url) }
        let original = try batch(base(shaper: shaper()), directory: url)
        let changed = try batch(base(shaper: shaper(delta: 1)), directory: url)
        let store = ExposureBatchCheckpointStore(directory: url.appendingPathComponent("checkpoint"))
        let interrupted = try await ExposureBatchCoordinator().generate(original,
            exporter: BatchFormatInterruptExporter(), checkpoint: store)
        XCTAssertEqual(interrupted.items.map(\.state), [.completed, .cancelled])
        let firstBytes = try Data(contentsOf: original.items[0].url)
        do {
            _ = try await ExposureBatchCoordinator().generate(changed, exporter: NativeExportService(),
                                                               resumeFrom: interrupted)
            XCTFail("Changed shaper must not reuse a completed report")
        } catch { XCTAssertEqual(error as? ExposureBatchError, .checkpointMismatch) }
        do {
            _ = try await ExposureBatchCoordinator().generate(changed, exporter: NativeExportService(),
                checkpoint: ExposureBatchCheckpointStore(directory: store.directory), resuming: true)
            XCTFail("Changed shaper must not reuse a durable checkpoint")
        } catch { XCTAssertEqual(error as? ExposureBatchError, .checkpointMismatch) }
        XCTAssertEqual(try Data(contentsOf: original.items[0].url), firstBytes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.items[1].url.path))
        let recovered = try await ExposureBatchCoordinator().generate(original, exporter: NativeExportService(),
            checkpoint: ExposureBatchCheckpointStore(directory: store.directory), resuming: true)
        XCTAssertEqual(recovered.state, .completed)
        XCTAssertEqual(recovered.items[0], interrupted.items[0])
        XCTAssertEqual(try Data(contentsOf: original.items[0].url), firstBytes)
    }

    func testAllEightSupportedFormatsBatchAndDurableResume() async throws {
        XCTAssertEqual(LUTExportFormat.allCases.count, 8)
        for format in LUTExportFormat.allCases {
            let url = try folder("format-\(format.rawValue)"); defer { cleanup(url) }
            let request = try batch(base(), directory: url, format: format)
            let checkpoint = url.appendingPathComponent("checkpoint")
            let interrupted = try await ExposureBatchCoordinator().generate(request,
                exporter: BatchFormatInterruptExporter(),
                checkpoint: ExposureBatchCheckpointStore(directory: checkpoint))
            XCTAssertEqual(interrupted.state, .cancelled)
            XCTAssertEqual(interrupted.items.map(\.state), [.completed, .cancelled])
            let firstBytes = try Data(contentsOf: request.items[0].url)
            let completed = try await ExposureBatchCoordinator().generate(request, exporter: NativeExportService(),
                checkpoint: ExposureBatchCheckpointStore(directory: checkpoint), resuming: true)
            XCTAssertEqual(completed.state, .completed)
            XCTAssertEqual(completed.items[0], interrupted.items[0])
            XCTAssertEqual(try Data(contentsOf: request.items[0].url), firstBytes)
            for item in request.items {
                let lut = try parse(Data(contentsOf: item.url), format: format)
                XCTAssertEqual(completed.items[item.index].writtenNodes, lut.samples.count)
                XCTAssertEqual(lut.samples.first, try RGB64(0, 0, 0))
                let gain = pow(2, item.stop)
                let tolerance = [.ilut, .olut, .lut, .threeDL, .vlt].contains(format) ? 1.0 / 4095 : 2e-12
                XCTAssertEqual(try XCTUnwrap(lut.samples.last).r, gain, accuracy: tolerance)
            }
            XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: url.path)
                .contains { $0.hasPrefix(".lutcalc-") })
        }
    }

    func testInputShaperCannotSilentlyDisappearForOtherBatchFormats() async throws {
        for format in LUTExportFormat.allCases where format != .threeDL {
            let url = try folder("reject-\(format.rawValue)"); defer { cleanup(url) }
            let request = try batch(base(shaper: shaper()), directory: url, format: format)
            let report = try await ExposureBatchCoordinator().generate(request, exporter: NativeExportService())
            XCTAssertEqual(report.state, .failed)
            XCTAssertEqual(report.items.map(\.state), [.failed, .pending])
            XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: url.path).isEmpty)
        }
    }
}

private actor BatchFormatInterruptExporter: ExposureBatchExporter {
    private var count = 0
    func generate(_ request: LUTGenerationRequest, to output: URL, allowOverwrite: Bool) async throws -> Int {
        count += 1
        if count == 2 { throw CancellationError() }
        return try await NativeExportService().generate(request, to: output, allowOverwrite: allowOverwrite)
    }
}

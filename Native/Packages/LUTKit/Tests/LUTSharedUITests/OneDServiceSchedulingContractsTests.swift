import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTJobs
@testable import LUTSharedUI

final class OneDServiceSchedulingContractsTests: XCTestCase {
    private let formats: [(FileLUTFormat, Int)] = [(.spi1d, 1024), (.ilut, 16384), (.olut, 4096), (.lut, 4096)]

    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func request(block: Int, workers: Int, exposure: Double = 0,
                         post: CubeLUT? = nil) throws -> LUTGenerationRequest {
        try LUTGenerationRequest(plan: TransformPlan(settings: TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: exposure)),
            size: 33, domain: .unit, blockNodes: block, workerCount: workers, postLUT: post)
    }

    private func parse(_ data: Data, format: FileLUTFormat) throws -> CubeLUT {
        switch format {
        case .spi1d: return try SPI1DParser.parse(data).lut
        case .ilut: return try ILUTParser.parse(data)
        case .olut: return try OLUTParser.parse(data)
        case .lut: return try AssimilateLUTParser.parse(data)
        default: throw NativeExportError.unsupportedFormat
        }
    }

    func testActualServiceBlocksFixedSizesIndependentIdentityAndByteDeterminism() async throws {
        let url = try folder(); defer { try? FileManager.default.removeItem(at: url) }
        var channels = 0
        for (format, size) in formats {
            var baseline: Data?
            for workers in [1, 4] {
                for block in [1, 17, 4096, Int.max] {
                    let probe = OneDServiceProbe()
                    let service = NativeExportService(allowOverwrite: false, oneDTestHooks: nil,
                        didGenerateOneD: { request, report in await probe.record(request, report) })
                    let target = url.appendingPathComponent("\(format.rawValue)-\(workers)-\(block).\(format.rawValue)")
                    let count = try await service.generate(request(block: block, workers: workers), to: target)
                    let snapshot = await probe.result
                    let (captured, report) = try XCTUnwrap(snapshot)
                    XCTAssertEqual(captured.workerCount, workers); XCTAssertEqual(captured.blockNodes, block)
                    XCTAssertEqual(captured.size, size); XCTAssertEqual(count, size)
                    XCTAssertEqual(report.blocks, size / block + (size % block == 0 ? 0 : 1))
                    XCTAssertEqual(report.state, .completed)
                    XCTAssertLessThanOrEqual(report.maxPendingBlocks, 2 * workers)
                    let bytes = try Data(contentsOf: target)
                    if let baseline { XCTAssertEqual(bytes, baseline) } else { baseline = bytes }
                    let lut = try parse(bytes, format: format)
                    XCTAssertEqual(lut.samples.count, size)
                    for i in 0..<size { for channel in 0..<3 {
                        // Independent identity: integer formats preserve the exact code i.
                        XCTAssertEqual(lut.samples[i][channel], Double(i) / Double(size - 1))
                        channels += 1
                    }}
                }
            }
        }
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: url.path).contains { $0.hasPrefix(".lutcalc-") })
        print("1D service identity: channels=\(channels), max=0, RMS=0, P99=0; 32 actual files, workers=1/4, blocks=1/17/4096/Int.max")
    }

    func testForcedOutOfOrderWindowAndActualFileOrderForEveryRoute() async throws {
        let url = try folder(); defer { try? FileManager.default.removeItem(at: url) }
        for (format, size) in formats {
            let gate = OneDServiceGate(releaseAt: 7), probe = OneDServiceProbe()
            let hooks = GenerationTestHooks(beforeComplete: { index in try await gate.beforeComplete(index) },
                                             didReceive: { index in await gate.received(index) })
            let service = NativeExportService(allowOverwrite: false, oneDTestHooks: hooks,
                didGenerateOneD: { request, report in await probe.record(request, report) })
            let target = url.appendingPathComponent("forced.\(format.rawValue)")
            _ = try await service.generate(request(block: 17, workers: 4), to: target)
            let snapshot = await probe.result
            let (_, report) = try XCTUnwrap(snapshot)
            XCTAssertEqual(report.maxPendingBlocks, 8)
            let order = await gate.order
            XCTAssertEqual(Set(order.prefix(7)), Set(1...7)); XCTAssertEqual(order[7], 0)
            let lut = try parse(Data(contentsOf: target), format: format)
            for i in 0..<size { for channel in 0..<3 {
                XCTAssertEqual(lut.samples[i][channel], Double(i) / Double(size - 1))
            }}
            print("1D forced route=\(format.rawValue), blocks=\(report.blocks), maxPending=\(report.maxPendingBlocks), firstReceipts=\(Array(order.prefix(8)))")
        }
    }

    func testRealCancellationWithBlockedFirstResultAbortsEveryRoute() async throws {
        let url = try folder(); defer { try? FileManager.default.removeItem(at: url) }
        for (format, _) in formats {
            let gate = OneDServiceGate(releaseAt: nil), probe = OneDServiceProbe()
            let hooks = GenerationTestHooks(beforeComplete: { index in try await gate.beforeComplete(index) },
                                             didReceive: { index in await gate.received(index) })
            let service = NativeExportService(allowOverwrite: false, oneDTestHooks: hooks,
                didGenerateOneD: { request, report in await probe.record(request, report) })
            let target = url.appendingPathComponent("cancel.\(format.rawValue)")
            let input = try request(block: 17, workers: 4)
            let task = Task { try await service.generate(input, to: target) }
            await gate.waitForReceipt(); task.cancel(); await gate.release()
            do { _ = try await task.value; XCTFail("Expected cancellation") } catch is CancellationError {}
            let result = await probe.result; XCTAssertNil(result)
            XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: url.path).isEmpty)
        }
    }

    func testUserLUTSnapshotAndBatchUseActualOneDScheduling() async throws {
        let url = try folder(); defer { try? FileManager.default.removeItem(at: url) }
        let post = try CubeLUT(dimension: .one, size: 2, domain: .unit,
                              samples: [RGB64(0, 0, 0), RGB64(1, 0.5, 0.25)])
        let probe = OneDServiceProbe()
        let service = NativeExportService(allowOverwrite: false, oneDTestHooks: nil,
            didGenerateOneD: { request, report in await probe.record(request, report) })
        let target = url.appendingPathComponent("user.spi1d")
        _ = try await service.generate(request(block: 17, workers: 4, post: post), to: target)
        let snapshot = await probe.result
        let (captured, report) = try XCTUnwrap(snapshot)
        XCTAssertEqual(captured.postLUT, post); XCTAssertEqual(report.blocks, 61)
        let lut = try parse(Data(contentsOf: target), format: .spi1d)
        for i in 0..<1024 { for c in 0..<3 {
            XCTAssertEqual(lut.samples[i][c], Double(i) / 1023 * [1.0, 0.5, 0.25][c])
        }}
        for (format, size) in formats {
            let batchProbe = OneDServiceProbe()
            let exporter = NativeExportService(allowOverwrite: false, oneDTestHooks: nil,
                didGenerateOneD: { request, report in await batchProbe.record(request, report) })
            let batch = try ExposureBatchRequest(base: request(block: 17, workers: 4),
                settings: ExposureBatchSettings(minimumStops: 0, maximumStops: 0, subdivisions: 1),
                directory: url, basename: "batch", format: format)
            let completed = try await ExposureBatchCoordinator().generate(batch, exporter: exporter)
            XCTAssertEqual(completed.state, .completed); XCTAssertEqual(completed.items[0].writtenNodes, size)
            let snapshot = await batchProbe.result
            let (r, actual) = try XCTUnwrap(snapshot)
            XCTAssertEqual(r.blockNodes, 17); XCTAssertEqual(r.workerCount, 4)
            XCTAssertEqual(actual.blocks, size / 17 + (size % 17 == 0 ? 0 : 1))
        }
    }
}

private actor OneDServiceProbe {
    var result: (LUT1DGenerationRequest, OneDGenerationReport)?
    func record(_ request: LUT1DGenerationRequest, _ report: OneDGenerationReport) { result = (request, report) }
}

private actor OneDServiceGate {
    let releaseAt: Int?
    var order: [Int] = []
    private var released = false
    private var first: CheckedContinuation<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    init(releaseAt: Int?) { self.releaseAt = releaseAt }
    func beforeComplete(_ index: Int) async throws {
        if index == 0 && !released { await withCheckedContinuation { first = $0 } }
        try Task.checkCancellation()
    }
    func received(_ index: Int) {
        order.append(index); waiter?.resume(); waiter = nil
        if let releaseAt, order.count == releaseAt { release() }
    }
    func waitForReceipt() async {
        if !order.isEmpty { return }
        await withCheckedContinuation { waiter = $0 }
    }
    func release() { released = true; first?.resume(); first = nil }
}

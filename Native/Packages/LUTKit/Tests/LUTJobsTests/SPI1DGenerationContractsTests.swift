import XCTest
@testable import LUTJobs
import LUTCore
import LUTFormats

final class SPI1DGenerationContractsTests: XCTestCase {
    func testOneDGenerationCancellationLeavesNoTargetOrTemporaryFile() async throws {
        let settings = TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .acesAP0, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )
        let request = try LUT1DGenerationRequest(
            plan: TransformPlan(settings: settings), size: 1024, domain: .unit,
            blockNodes: 16, workerCount: 2)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-spi1d-cancel-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("cancel.spi1d")
        let fileSink = FileSPI1DSink(target: target)
        let sink = OneDAppendGateSink(fileSink: fileSink)
        let coordinator = OneDGenerationCoordinator()
        let task = Task { try await coordinator.generate(request, sink: sink) }
        await sink.waitUntilAppend()
        task.cancel()
        await sink.releaseAppend()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
        let jobState = await coordinator.state
        let sinkState = await fileSink.state
        XCTAssertEqual(jobState, .cancelled)
        XCTAssertEqual(sinkState, .aborted)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    func testOneDSinkRejectsExistingTargetWithoutChangingBytes() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-spi1d-existing-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("existing.spi1d")
        let original = Data("keep existing output".utf8)
        try original.write(to: target)
        let sink = FileSPI1DSink(target: target)
        do {
            try await sink.prepare(size: 2, domain: .unit, title: "contract")
            XCTFail("Expected targetExists")
        } catch FileSinkError.targetExists {}
        XCTAssertEqual(try Data(contentsOf: target), original)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .allSatisfy { $0 == target.lastPathComponent })
    }

    func testOneDSinkRejectsExternalTargetChangeAtCommit() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-spi1d-change-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("changed.spi1d")
        let original = Data("original".utf8)
        let external = Data("external edit".utf8)
        try original.write(to: target)
        let sink = FileSPI1DSink(target: target, allowOverwrite: true)
        try await sink.prepare(size: 2, domain: .unit, title: "contract")
        try await sink.append(blockIndex: 0, samples: [RGB64(0, 0, 0), RGB64(1, 1, 1)])
        try await sink.validate(expectedNodes: 2)
        try external.write(to: target)
        do {
            try await sink.commit()
            XCTFail("Expected targetChanged")
        } catch FileSinkError.targetChanged {}
        await sink.abort()
        let sinkState = await sink.state
        XCTAssertEqual(try Data(contentsOf: target), external)
        XCTAssertEqual(sinkState, .aborted)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .allSatisfy { $0 == target.lastPathComponent })
    }

    func testOneDGenerationWritesIndependentChannelsAsThreeComponentSPI1D() async throws {
        let settings = TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .acesAP0, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )
        let request = try LUT1DGenerationRequest(
            plan: TransformPlan(settings: settings), size: 5,
            domain: try LUTDomain(min: RGB64(0, 0, 0), max: RGB64(1, 1, 1)),
            blockNodes: 2, workerCount: 2
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-spi1d-contract-\(UUID().uuidString).spi1d")
        defer { try? FileManager.default.removeItem(at: url) }

        let report = try await OneDGenerationCoordinator().generate(
            request, sink: FileSPI1DSink(target: url))
        XCTAssertEqual(report.writtenNodes, 5)
        let parsed = try SPI1DParser.parse(url: url)
        XCTAssertEqual(parsed.components, 3)
        XCTAssertEqual(parsed.lut.samples.count, 5)
        let expectedR = try request.plan.evaluate(RGB64(0.5, 0, 0), sampleIndex: 2).r
        let expectedG = try request.plan.evaluate(RGB64(0, 0.5, 0), sampleIndex: 2).g
        let expectedB = try request.plan.evaluate(RGB64(0, 0, 0.5), sampleIndex: 2).b
        XCTAssertEqual(parsed.lut.samples[2].r.bitPattern, expectedR.bitPattern)
        XCTAssertEqual(parsed.lut.samples[2].g.bitPattern, expectedG.bitPattern)
        XCTAssertEqual(parsed.lut.samples[2].b.bitPattern, expectedB.bitPattern)
    }

    func testOneDGenerationRejectsNonScalarDomain() throws {
        let settings = TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .acesAP0, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )
        XCTAssertThrowsError(try LUT1DGenerationRequest(
            plan: TransformPlan(settings: settings), size: 5,
            domain: try LUTDomain(min: RGB64(0, 0, 0), max: RGB64(1, 2, 1))))
    }

    func testOneDGenerationRejectsCrossGamutPlan() throws {
        let settings = TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )
        XCTAssertThrowsError(try LUT1DGenerationRequest(
            plan: TransformPlan(settings: settings), size: 17, domain: .unit)) { error in
            XCTAssertEqual(error as? SPI1DFailure, SPI1DFailure(.lossyRepresentation, line: 0))
        }
    }

    func testOneDGenerationRejectsHLGOOTFBecauseItIsRGBCoupled() throws {
        let settings = TransformSettings(
            inputTransfer: .rec2100HLG, outputTransfer: .rec2100HLG,
            inputSpace: .rec2020, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 0,
            hlgOOTF: HLGOOTFSettings())
        XCTAssertThrowsError(try LUT1DGenerationRequest(
            plan: TransformPlan(settings: settings), size: 17, domain: .unit)) { error in
            XCTAssertEqual(error as? SPI1DFailure, SPI1DFailure(.lossyRepresentation, line: 0))
        }
    }

    func testOneDGenerationRejectsOversizedRequest() throws {
        let settings = TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .acesAP0, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )
        XCTAssertThrowsError(try LUT1DGenerationRequest(
            plan: TransformPlan(settings: settings), size: Int.max, domain: .unit))
    }

    func testOneDGenerationLimitMatchesParserDecodedBudget() throws {
        let settings = TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .acesAP0, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )
        let largestReadable = CubeParser.maxDecodedBytes / MemoryLayout<RGB64>.stride
        XCTAssertNoThrow(try LUT1DGenerationRequest(
            plan: TransformPlan(settings: settings), size: largestReadable, domain: .unit))
        XCTAssertThrowsError(try LUT1DGenerationRequest(
            plan: TransformPlan(settings: settings), size: largestReadable + 1, domain: .unit)) { error in
            XCTAssertEqual(error as? SPI1DFailure, SPI1DFailure(.resourceLimit, line: 0))
        }
    }

    func testOneDSinkRejectsUnreadableSizeBeforeCreatingTemporaryFile() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-spi1d-limit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sink = FileSPI1DSink(target: directory.appendingPathComponent("large.spi1d"))
        let largestReadable = CubeParser.maxDecodedBytes / MemoryLayout<RGB64>.stride
        do {
            try await sink.prepare(size: largestReadable + 1, domain: .unit, title: "contract")
            XCTFail("Expected resourceLimit")
        } catch let error as SPI1DFailure {
            XCTAssertEqual(error, SPI1DFailure(.resourceLimit, line: 0))
        }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    func testOneDGenerationDecodesDLog2WithoutChangingChannels() async throws {
        let settings = TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .djiDGamut2,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )
        let request = try LUT1DGenerationRequest(
            plan: TransformPlan(settings: settings), size: 17, domain: .unit,
            blockNodes: 3, workerCount: 2)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-spi1d-dlog2-\(UUID().uuidString).spi1d")
        defer { try? FileManager.default.removeItem(at: url) }
        _ = try await OneDGenerationCoordinator().generate(request, sink: FileSPI1DSink(target: url))
        let parsed = try SPI1DParser.parse(url: url)
        for index in 0..<17 {
            let input = Double(index) / 16
            let reference = try DLog2.decodeDataToScene(input)
            let sample = parsed.lut.samples[index]
            for channel in 0..<3 {
                XCTAssertLessThanOrEqual(abs(sample[channel] - reference) / max(1, abs(reference)), 2e-12)
            }
        }
    }
}

private actor OneDAppendGateSink: OneDBlockSink {
    private let fileSink: FileSPI1DSink
    private var entered = false
    private var enteredWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    init(fileSink: FileSPI1DSink) { self.fileSink = fileSink }

    func prepare(size: Int, domain: LUTDomain, title: String) async throws {
        try await fileSink.prepare(size: size, domain: domain, title: title)
    }

    func append(blockIndex: Int, samples: [RGB64]) async throws {
        if blockIndex == 0 {
            entered = true
            enteredWaiter?.resume()
            enteredWaiter = nil
            await withCheckedContinuation { releaseWaiter = $0 }
        }
        try await fileSink.append(blockIndex: blockIndex, samples: samples)
    }

    func validate(expectedNodes: Int) async throws {
        try await fileSink.validate(expectedNodes: expectedNodes)
    }

    func commit() async throws { try await fileSink.commit() }
    func abort() async { await fileSink.abort() }

    func waitUntilAppend() async {
        if entered { return }
        await withCheckedContinuation { enteredWaiter = $0 }
    }

    func releaseAppend() {
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}

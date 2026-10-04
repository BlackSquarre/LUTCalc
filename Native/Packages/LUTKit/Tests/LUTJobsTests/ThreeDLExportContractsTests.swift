import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTJobs

final class ThreeDLExportContractsTests: XCTestCase {
    func testFlavoredStreamsWriteStrictLustreAndKodakGrammars() async throws {
        let lustreURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-3dl-lustre-stream-\(UUID().uuidString).3dl")
        let kodakURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-3dl-kodak-stream-\(UUID().uuidString).3dl")
        defer {
            try? FileManager.default.removeItem(at: lustreURL)
            try? FileManager.default.removeItem(at: kodakURL)
        }

        let lustre = FileCubeSink(target: lustreURL, format: .threeDL, threeDLFlavor: .lustre)
        try await lustre.prepare(size: 9, domain: .unit, title: "lustre")
        let lustreSamples = try (0..<729).map { index in
            let value = Double(index) / 728
            return try RGB64(value, 1 - value, 0.25)
        }
        try await lustre.append(blockIndex: 0, samples: Array(lustreSamples[0..<137]))
        try await lustre.append(blockIndex: 1, samples: Array(lustreSamples[137..<729]))
        try await lustre.validate(expectedNodes: 729)
        try await lustre.commit()
        let lustreData = try Data(contentsOf: lustreURL)
        XCTAssertTrue(String(decoding: lustreData, as: UTF8.self).contains("LUT8\ngamma 1.0"))
        let parsedLustre = try ThreeDLParser.parse(lustreData, flavor: .lustre)
        XCTAssertEqual(parsedLustre.samples.count, 729)
        XCTAssertEqual(parsedLustre.samples[0].r, 0, accuracy: 1e-12)
        XCTAssertEqual(parsedLustre.samples[728].r, 1, accuracy: 1e-12)

        let kodak = FileCubeSink(target: kodakURL, format: .threeDL, threeDLFlavor: .kodak)
        try await kodak.prepare(size: 2, domain: .unit, title: "kodak")
        try await kodak.append(blockIndex: 0, samples: Array(lustreSamples[0..<8]))
        try await kodak.validate(expectedNodes: 8)
        try await kodak.commit()
        let kodakData = try Data(contentsOf: kodakURL)
        XCTAssertFalse(String(decoding: kodakData, as: UTF8.self).contains("3DMESH"))
        XCTAssertEqual(try ThreeDLParser.parse(kodakData, flavor: .kodak).samples.count, 8)
    }

    func testStreamedThreeDLCarriesAndAppliesNonlinearShaper() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-3dl-shaper-stream-\(UUID().uuidString).3dl")
        defer { try? FileManager.default.removeItem(at: url) }

        let settings = TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
                                         inputSpace: .acesAP0, outputSpace: .acesAP0,
                                         inputRange: .data, outputRange: .data, exposureStops: 0)
        let shaper = try CubeShaper(size: 3, domain: .unit, samples: [
            try RGB64(0, 0, 0), try RGB64(256.0 / 1023.0, 256.0 / 1023.0, 256.0 / 1023.0), try RGB64(1, 1, 1)
        ])
        let request = try LUTGenerationRequest(plan: TransformPlan(settings: settings),
                                               size: 3, domain: .unit, blockNodes: 2,
                                               workerCount: 2)
        let shapedRequest = try LUTGenerationRequest(plan: request.plan, size: request.size,
                                                     domain: request.domain, blockNodes: request.blockNodes,
                                                     workerCount: request.workerCount,
                                                     inputShaper: shaper)
        let sink = FileCubeSink(target: url, format: .threeDL, threeDLShaper: shaper)
        let report = try await GenerationCoordinator().generate(shapedRequest, sink: sink)
        XCTAssertEqual(report.writtenNodes, 27)
        let parsed = try ThreeDLParser.parse(Data(contentsOf: url), flavor: .flame)
        XCTAssertEqual(parsed.shaper, shaper)
        XCTAssertEqual(parsed.samples[1].r, 256.0 / 1023.0, accuracy: 1.0 / 4095.0)
    }

    func testBlocksWriteFlameAxisOrderAndHalfUpCodes() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-3dl-axis-\(UUID().uuidString).3dl")
        defer { try? FileManager.default.removeItem(at: url) }
        let sink = FileCubeSink(target: url, format: .threeDL)
        try await sink.prepare(size: 2, domain: .unit, title: "axis")
        let samples = try (0..<8).map { index in
            try RGB64(Double(index) / 8, 0.5 / 4095, Double(index) / 8)
        }
        try await sink.append(blockIndex: 0, samples: Array(samples[0..<3]))
        try await sink.append(blockIndex: 1, samples: Array(samples[3..<8]))
        try await sink.validate(expectedNodes: 8)
        try await sink.commit()
        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
        XCTAssertTrue(lines.contains("0 1023"))
        XCTAssertEqual(lines.suffix(8).map { $0.split(separator: " ").first.map(String.init) },
                       ["0000", "2048", "1024", "3071", "0512", "2559", "1536", "3583"])
        let parsed = try ThreeDLParser.parse(Data(contentsOf: url), flavor: .flame)
        XCTAssertEqual(parsed.samples.count, 8)
        for index in 0..<8 {
            XCTAssertEqual(parsed.samples[index].r, Double((Double(index) / 8 * 4095).rounded()) / 4095)
        }
        XCTAssertEqual(parsed.samples[0].g, 1 / 4095)
    }

    func testExtendedDomainAndOutOfRangeSampleLeaveNoTarget() async throws {
        let domainURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-3dl-domain-\(UUID().uuidString).3dl")
        let extended = try LUTDomain(min: RGB64(-1, -1, -1), max: RGB64(1, 1, 1))
        let domainSink = FileCubeSink(target: domainURL, format: .threeDL)
        do {
            try await domainSink.prepare(size: 2, domain: extended, title: "domain")
            XCTFail("3DL cannot encode extended domains")
        } catch {
            XCTAssertEqual((error as? ThreeDLFailure)?.category, .lossyRepresentation)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: domainURL.path))

        let sampleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-3dl-value-\(UUID().uuidString).3dl")
        let sampleSink = FileCubeSink(target: sampleURL, format: .threeDL)
        try await sampleSink.prepare(size: 2, domain: .unit, title: "value")
        do {
            try await sampleSink.append(blockIndex: 0, samples: [try RGB64(-0.1, 0, 0)])
            XCTFail("3DL cannot silently clip")
        } catch {
            XCTAssertEqual((error as? ThreeDLFailure)?.category, .lossyRepresentation)
        }
        await sampleSink.abort()
        XCTAssertFalse(FileManager.default.fileExists(atPath: sampleURL.path))
    }

    func testCancelledWriteAndRejectedOverwritePreserveTarget() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-3dl-existing-\(UUID().uuidString).3dl")
        let original = Data("existing content".utf8)
        try original.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let rejected = FileCubeSink(target: url, format: .threeDL)
        do {
            try await rejected.prepare(size: 2, domain: .unit, title: "existing")
            XCTFail("Overwrite must require explicit authorization")
        } catch {
            XCTAssertEqual(error as? FileSinkError, .targetExists)
        }
        XCTAssertEqual(try Data(contentsOf: url), original)

        let cancelled = FileCubeSink(target: url, allowOverwrite: true, format: .threeDL)
        try await cancelled.prepare(size: 2, domain: .unit, title: "cancelled")
        try await cancelled.append(blockIndex: 0, samples: [try RGB64(0.5, 0.5, 0.5)])
        await cancelled.abort()
        XCTAssertEqual(try Data(contentsOf: url), original)
        let state = await cancelled.state
        XCTAssertEqual(state, .aborted)
    }
}

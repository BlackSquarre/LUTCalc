import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTJobs

final class SPI3DExportContractsTests: XCTestCase {
    func testStreamedBlocksKeepIndexedCoordinatesAndDoubleSamples() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-spi3d-stream-\(UUID().uuidString).spi3d")
        defer { try? FileManager.default.removeItem(at: url) }
        let settings = TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 1)
        let plan = try TransformPlan(settings: settings)
        let request = try LUTGenerationRequest(plan: plan, size: 3, domain: .unit,
                                               blockNodes: 5, workerCount: 2)
        let report = try await GenerationCoordinator().generate(
            request, sink: FileCubeSink(target: url, format: .spi3d))
        XCTAssertEqual(report.state, .completed)
        XCTAssertEqual(report.writtenNodes, 27)
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.hasPrefix("SPILUT 1.0\n3 3\n3 3 3\n"))
        let lines = text.split(separator: "\n")
        XCTAssertEqual(lines.count, 30)
        XCTAssertTrue(lines[3].hasPrefix("0 0 0 "))
        XCTAssertTrue(lines[4].hasPrefix("1 0 0 "))
        XCTAssertTrue(lines[5].hasPrefix("2 0 0 "))
        XCTAssertTrue(lines[8].hasPrefix("2 1 0 "))
        XCTAssertTrue(lines[29].hasPrefix("2 2 2 "))
        let parsed = try SPI3DParser.parse(url: url)
        let expected = try CubeGenerator.generate3D(plan: plan, size: 3, domain: .unit)
        for index in 0..<27 {
            for channel in 0..<3 {
                XCTAssertEqual(parsed.samples[index][channel].bitPattern,
                               expected.samples[index][channel].bitPattern)
            }
        }
    }

    func testExtendedDomainRejectsBeforeCreatingOutput() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-spi3d-domain-\(UUID().uuidString).spi3d")
        let domain = try LUTDomain(min: RGB64(-1, -1, -1), max: RGB64(1, 1, 1))
        let settings = TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 1)
        let request = try LUTGenerationRequest(plan: TransformPlan(settings: settings),
                                               size: 3, domain: domain)
        do {
            _ = try await GenerationCoordinator().generate(
                request, sink: FileCubeSink(target: url, format: .spi3d))
            XCTFail("Extended domain should be rejected")
        } catch {
            XCTAssertEqual((error as? SPI3DFailure)?.category, .lossyRepresentation)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testCancelledOverwritePreservesExistingSPI3DAndRemovesTemporaryFile() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-spi3d-cancel-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("existing.spi3d")
        let original = Data("existing SPI3D bytes".utf8)
        try original.write(to: target)

        let sink = FileCubeSink(target: target, allowOverwrite: true, format: .spi3d)
        try await sink.prepare(size: 2, domain: .unit, title: "unused")
        try await sink.append(blockIndex: 0, samples: [try RGB64(0.25, 0.5, 0.75)])
        await sink.abort()

        XCTAssertEqual(try Data(contentsOf: target), original)
        let state = await sink.state
        XCTAssertEqual(state, .aborted)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path),
                       [target.lastPathComponent])
    }

    func testExistingSPI3DRejectsDefaultOverwriteBeforeTemporaryCreation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-spi3d-protect-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("existing.spi3d")
        let original = Data("existing SPI3D bytes".utf8)
        try original.write(to: target)

        let sink = FileCubeSink(target: target, format: .spi3d)
        do {
            try await sink.prepare(size: 2, domain: .unit, title: "unused")
            XCTFail("Existing SPI3D must require explicit overwrite authorization")
        } catch {
            XCTAssertEqual(error as? FileSinkError, .targetExists)
        }
        XCTAssertEqual(try Data(contentsOf: target), original)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path),
                       [target.lastPathComponent])
    }
}

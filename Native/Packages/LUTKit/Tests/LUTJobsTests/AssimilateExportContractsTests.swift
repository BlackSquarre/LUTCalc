import Foundation
import XCTest
import LUTCore
import LUTFormats
@testable import LUTJobs

final class AssimilateExportContractsTests: XCTestCase {
    func testSinkRejectsNegativeZeroDomainBeforeCreatingTarget() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-assimilate-negative-zero-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("output.lut")
        let domain = try LUTDomain(min: RGB64(-0.0, 0, 0), max: RGB64(1, 1, 1))
        let sink = FileAssimilateLUTSink(target: target)
        do {
            try await sink.prepare(size: 4096, domain: domain, title: "contract")
            XCTFail("Expected bit-exact unit-domain rejection")
        } catch let error as AssimilateLUTFailure {
            XCTAssertEqual(error.category, .lossyRepresentation)
        }
        let state = await sink.state
        XCTAssertEqual(state, .idle)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    func testSinkWritesChannelBlocksWithJavaScriptHalfTieRounding() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-assimilate-blocks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("output.lut")
        let sink = FileAssimilateLUTSink(target: target)
        try await sink.prepare(size: 4096, domain: .unit, title: "ignored")
        let first = try RGB64(0.5 / 4095, 1.5 / 4095, -0.5 / 4095)
        try await sink.append(blockIndex: 0, samples: [first])
        try await sink.append(blockIndex: 1, samples: Array(repeating: try RGB64(0, 0, 0), count: 4095))
        try await sink.validate(expectedNodes: 4096)
        try await sink.commit()
        let lines = try String(contentsOf: target, encoding: .utf8).split(separator: "\n")
        XCTAssertEqual(lines[0], "LUT: 3 4096")
        XCTAssertEqual(lines[1], "1")
        XCTAssertEqual(lines[1 + 4096], "2")
        XCTAssertEqual(lines[1 + 2 * 4096], "0")
    }

    func testSinkRejectsNonUnitDomainAndExistingTarget() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-assimilate-sink-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("output.lut")
        let nonUnit = try LUTDomain(min: RGB64(0.1, 0.1, 0.1), max: RGB64(1, 1, 1))
        let invalid = FileAssimilateLUTSink(target: target)
        do {
            try await invalid.prepare(size: 4096, domain: nonUnit, title: "contract")
            XCTFail("Expected non-unit domain rejection")
        } catch let error as AssimilateLUTFailure {
            XCTAssertEqual(error.category, .lossyRepresentation)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))

        let original = Data("existing".utf8)
        try original.write(to: target)
        let protected = FileAssimilateLUTSink(target: target)
        do {
            try await protected.prepare(size: 4096, domain: .unit, title: "contract")
            XCTFail("Expected targetExists")
        } catch FileSinkError.targetExists {}
        XCTAssertEqual(try Data(contentsOf: target), original)
    }

    func testSinkAbortsOnUnrepresentableCodeAndCleansTemporaryFile() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-assimilate-abort-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("output.lut")
        let sink = FileAssimilateLUTSink(target: target)
        let settings = TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
                                         inputSpace: .acesAP0, outputSpace: .acesAP0,
                                         inputRange: .data, outputRange: .data, exposureStops: 24)
        let request = try LUT1DGenerationRequest(plan: TransformPlan(settings: settings),
                                                 size: 4096, domain: .unit)
        do {
            _ = try await OneDGenerationCoordinator().generate(request, sink: sink)
            XCTFail("Expected code overflow")
        } catch let error as AssimilateLUTFailure {
            XCTAssertEqual(error.category, .lossyRepresentation)
        }
        let state = await sink.state
        XCTAssertEqual(state, .aborted)
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }
}

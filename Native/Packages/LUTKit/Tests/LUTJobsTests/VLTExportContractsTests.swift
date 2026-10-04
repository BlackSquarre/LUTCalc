import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTJobs

final class VLTExportContractsTests: XCTestCase {
    func testDLog2IdentityPresetExportsVLT17Cube() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-vlt-\(UUID().uuidString).vlt")
        defer { try? FileManager.default.removeItem(at: url) }
        let settings = TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .djiDLog2,
            inputSpace: .djiDGamut2, outputSpace: .djiDGamut2,
            inputRange: .data, outputRange: .data, exposureStops: 0)
        let request = try LUTGenerationRequest(
            plan: TransformPlan(settings: settings), size: VLTParser.size,
            domain: .unit, blockNodes: 257, workerCount: 2)
        let report = try await GenerationCoordinator().generate(
            request, sink: FileCubeSink(target: url, format: .vlt))
        XCTAssertEqual(report.state, .completed)
        XCTAssertEqual(report.writtenNodes, VLTParser.size * VLTParser.size * VLTParser.size)
        let parsed = try VLTParser.parse(Data(contentsOf: url))
        XCTAssertEqual(parsed.size, VLTParser.size)
        XCTAssertEqual(parsed.samples.count, report.writtenNodes)
        for sample in parsed.samples {
            XCTAssertTrue((0...1).contains(sample.r))
            XCTAssertTrue((0...1).contains(sample.g))
            XCTAssertTrue((0...1).contains(sample.b))
        }
    }
}

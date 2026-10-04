import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTJobs
import LUTProject
@testable import LUTSharedUI

final class AssimilateServiceContractsTests: XCTestCase {
    func testServiceRejectsNegativeZeroDomainBeforeCreatingTarget() async throws {
        let domain = try LUTDomain(min: RGB64(0, -0.0, 0), max: RGB64(1, 1, 1))
        let settings = TransformSettings(inputTransfer: .djiDLog2, outputTransfer: .linearScene,
                                         inputSpace: .djiDGamut2, outputSpace: .djiDGamut2,
                                         inputRange: .data, outputRange: .data, exposureStops: 0)
        let request = try LUTGenerationRequest(plan: TransformPlan(settings: settings),
                                               size: 17, domain: domain)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-assimilate-service-negative-zero-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("output.lut")
        do {
            _ = try await NativeExportService().generate(request, to: target)
            XCTFail("Expected bit-exact unit-domain rejection")
        } catch let error as AssimilateLUTFailure {
            XCTAssertEqual(error.category, .lossyRepresentation)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    func testDocumentSessionExports4096ThreeChannelBlocks() async throws {
        let settings = TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .djiDGamut2,
            inputRange: .data, outputRange: .data, exposureStops: 0)
        let document = try LUTProjectDocument(new: ProjectManifest(
            settings: settings, cubeSize: 17, domain: .unit))
        let session = await ProjectExportSession()
        let started = await session.start(document: document, format: .lut)
        XCTAssertTrue(started)
        await session.waitForCurrentExport()
        let lastExport = await session.lastExport
        let record = try XCTUnwrap(lastExport)
        defer { try? FileManager.default.removeItem(at: record.url) }
        XCTAssertEqual(record.url.pathExtension, "lut")
        XCTAssertEqual(record.writtenNodes, 4096)
        let file = try Data(contentsOf: record.url)
        let lines = try XCTUnwrap(String(data: file, encoding: .utf8))
            .split(separator: "\n")
        XCTAssertEqual(lines.first, "LUT: 3 4096")
        XCTAssertEqual(lines.count, 1 + 3 * 4096)
        XCTAssertEqual(try AssimilateLUTParser.parse(file).samples.count, 4096)
    }

    func testServiceRejectsCrossGamutAndNonUnitDomain() async throws {
        for (space, domain) in [
            (ColorSpaceID.acesAP0, LUTDomain.unit),
            (ColorSpaceID.djiDGamut2,
             try LUTDomain(min: RGB64(0.1, 0.1, 0.1), max: RGB64(1, 1, 1))),
        ] {
            let settings = TransformSettings(
                inputTransfer: .djiDLog2, outputTransfer: .linearScene,
                inputSpace: .djiDGamut2, outputSpace: space,
                inputRange: .data, outputRange: .data, exposureStops: 0)
            let request = try LUTGenerationRequest(plan: TransformPlan(settings: settings),
                                                   size: 17, domain: domain)
            let target = FileManager.default.temporaryDirectory
                .appendingPathComponent("lutcalc-assimilate-reject-\(UUID().uuidString).lut")
            defer { try? FileManager.default.removeItem(at: target) }
            do {
                _ = try await NativeExportService().generate(request, to: target)
                XCTFail("Expected representability rejection")
            } catch let error as AssimilateLUTFailure {
                XCTAssertEqual(error.category, .lossyRepresentation)
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        }
    }
}

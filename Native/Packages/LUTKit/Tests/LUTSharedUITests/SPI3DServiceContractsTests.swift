import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTJobs
import LUTSharedUI

final class SPI3DServiceContractsTests: XCTestCase {
    @MainActor
    func testDocumentExportSessionCreatesSPI3DShareFile() async throws {
        let session = ProjectExportSession()
        XCTAssertTrue(session.start(document: LUTProjectDocument(), format: .spi3d))
        await session.waitForCurrentExport()
        XCTAssertEqual(session.exportStatus, .succeeded)
        let record = try XCTUnwrap(session.lastExport)
        defer { try? FileManager.default.removeItem(at: record.url) }
        XCTAssertEqual(record.url.pathExtension, "spi3d")
        XCTAssertEqual(record.writtenNodes, 4913)
        XCTAssertEqual(try SPI3DParser.parse(url: record.url).samples.count, 4913)
    }

    func testNativeExportServiceDispatchesSPI3DExtension() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-spi3d-service-\(UUID().uuidString).spi3d")
        defer { try? FileManager.default.removeItem(at: url) }
        let settings = TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 1)
        let plan = try TransformPlan(settings: settings)
        let request = try LUTGenerationRequest(plan: plan, size: 3, domain: .unit,
                                               blockNodes: 4, workerCount: 2)
        let nodes = try await NativeExportService().generate(request, to: url)
        XCTAssertEqual(nodes, 27)
        let parsed = try SPI3DParser.parse(url: url)
        let expected = try CubeGenerator.generate3D(plan: plan, size: 3, domain: .unit)
        XCTAssertEqual(parsed.samples, expected.samples)
    }

    func testUnsupportedOutputExtensionDoesNotCreateFile() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-unknown-export-\(UUID().uuidString).bin")
        let settings = TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 1)
        let request = try LUTGenerationRequest(plan: TransformPlan(settings: settings),
                                               size: 3, domain: .unit)
        do {
            _ = try await NativeExportService().generate(request, to: url)
            XCTFail("Unknown extension must be rejected")
        } catch {
            XCTAssertEqual(error as? NativeExportError, .unsupportedFormat)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}

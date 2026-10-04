import XCTest
import LUTCore
import LUTFormats
import LUTJobs
import LUTProject
@testable import LUTSharedUI

final class SPI1DServiceContractsTests: XCTestCase {
    func testNativeServiceAppliesUserOneDPostStageToSPI1D() async throws {
        let settings = TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .acesAP0, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 0)
        let plan = try TransformPlan(settings: settings)
        let lut = try CubeLUT(dimension: .one, size: 2, domain: .unit,
                              samples: [try RGB64(0, 0, 0), try RGB64(0.25, 0.5, 0.75)])
        let request = try LUTGenerationRequest(plan: plan, size: 17, domain: .unit,
                                                postLUT: lut)
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-post-spi1d-" + UUID().uuidString + ".spi1d")
        defer { try? FileManager.default.removeItem(at: output) }
        let written = try await NativeExportService().generate(request, to: output)
        XCTAssertEqual(written, 1024)
        let samples = try SPI1DParser.parse(url: output).lut.samples
        XCTAssertEqual(samples.first, try RGB64(0, 0, 0))
        XCTAssertEqual(samples.last, try RGB64(0.25, 0.5, 0.75))
    }

    func testServiceGeneratesSPI1DAndDocumentSessionSharesIt() async throws {
        let settings = TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .djiDGamut2,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )
        let document = try LUTProjectDocument(new: ProjectManifest(
            settings: settings, cubeSize: 17, domain: .unit))
        let session = await ProjectExportSession()
        let started = await session.start(document: document, format: .spi1d)
        XCTAssertTrue(started)
        await session.waitForCurrentExport()
        let lastExport = await session.lastExport
        let record = try XCTUnwrap(lastExport)
        defer { try? FileManager.default.removeItem(at: record.url) }
        XCTAssertEqual(record.url.pathExtension, "spi1d")
        XCTAssertEqual(record.writtenNodes, 1024)
        XCTAssertEqual(try SPI1DParser.parse(url: record.url).lut.samples.count, 1024)
    }
}

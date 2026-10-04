import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTJobs
import LUTProject
import LUTSharedUI

final class VLTServiceContractsTests: XCTestCase {
    private let identitySettings = TransformSettings(
        inputTransfer: .srgbW3CExtended, outputTransfer: .srgbW3CExtended,
        inputSpace: .srgb, outputSpace: .srgb,
        inputRange: .data, outputRange: .data, exposureStops: 0)

    @MainActor
    func testDocumentSessionCreatesVLTShareFile() async throws {
        let document = try LUTProjectDocument(new: ProjectManifest(
            settings: identitySettings, cubeSize: 17, domain: .unit))
        let session = ProjectExportSession()
        XCTAssertTrue(session.start(document: document, format: .vlt))
        await session.waitForCurrentExport()
        XCTAssertEqual(session.exportStatus, .succeeded)
        let record = try XCTUnwrap(session.lastExport)
        defer { try? FileManager.default.removeItem(at: record.url) }
        XCTAssertEqual(record.url.pathExtension, "vlt")
        XCTAssertEqual(record.writtenNodes, 4913)
        let lut = try VLTParser.parse(Data(contentsOf: record.url))
        XCTAssertEqual(lut.samples.count, 4913)
        let plan = try TransformPlan(settings: identitySettings)
        let unquantized = try plan.evaluate(RGB64(1.0 / 16.0, 0, 0))
        for channel in 0..<3 {
            let code = Int((unquantized[channel] * 4095).rounded(.toNearestOrAwayFromZero))
            XCTAssertEqual(lut.samples[1][channel], Double(code) / 4095)
        }
    }

    func testServiceRejectsUnsupportedSizeAndDomainBeforeCreatingTarget() async throws {
        let domain = try LUTDomain(min: RGB64(-1, -1, -1), max: RGB64(1, 1, 1))
        for (size, candidateDomain) in [(33, LUTDomain.unit), (17, domain)] {
            let request = try LUTGenerationRequest(
                plan: TransformPlan(settings: identitySettings), size: size, domain: candidateDomain)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("lutcalc-vlt-reject-\(UUID().uuidString).vlt")
            defer { try? FileManager.default.removeItem(at: url) }
            do {
                _ = try await NativeExportService().generate(request, to: url)
                XCTFail("Expected unsupported VLT export to fail")
            } catch let error as VLTFailure {
                XCTAssertEqual(error.category, .lossyRepresentation)
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        }
    }
}

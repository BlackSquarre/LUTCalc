import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTJobs
import LUTProject
import LUTSharedUI

final class ILUTServiceContractsTests: XCTestCase {
    private func settings(outputSpace: ColorSpaceID = .djiDGamut2,
                          outputTransfer: TransferID = .djiDLog2,
                          exposure: Double = 0) -> TransformSettings {
        TransformSettings(inputTransfer: .linearScene, outputTransfer: outputTransfer,
                          inputSpace: .djiDGamut2, outputSpace: outputSpace,
                          inputRange: .data, outputRange: .data, exposureStops: exposure)
    }

    @MainActor
    func testDocumentSessionExportsFixed14BitOneDFile() async throws {
        let document = try LUTProjectDocument(new: ProjectManifest(
            settings: settings(), cubeSize: 17, domain: .unit))
        let session = ProjectExportSession()
        XCTAssertTrue(session.start(document: document, format: .ilut))
        await session.waitForCurrentExport()
        XCTAssertEqual(session.exportStatus, .succeeded)
        let record = try XCTUnwrap(session.lastExport)
        defer { try? FileManager.default.removeItem(at: record.url) }
        XCTAssertEqual(record.url.pathExtension, "ilut")
        XCTAssertEqual(record.writtenNodes, 16_384)
        let data = try Data(contentsOf: record.url)
        let lut = try ILUTParser.parse(data)
        XCTAssertEqual(lut.samples.count, 16_384)
        XCTAssertEqual(String(decoding: data, as: UTF8.self).split(separator: "\n").count, 16_384)
        XCTAssertEqual(lut.samples.first?.r, lut.samples.first?.g)
        XCTAssertEqual(lut.samples.last?.r, lut.samples.last?.g)
    }

    func testServiceRejectsUnrepresentablePlanAndDomainWithoutOutput() async throws {
        for (settings, domain) in [
            (settings(outputSpace: .acesAP0), LUTDomain.unit),
            (settings(), try LUTDomain(min: RGB64(-1, -1, -1), max: RGB64(1, 1, 1))),
            (settings(outputTransfer: .linearScene, exposure: 1), LUTDomain.unit),
        ] {
            let request = try LUTGenerationRequest(plan: TransformPlan(settings: settings),
                                                   size: 17, domain: domain)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("lutcalc-ilut-reject-\(UUID().uuidString).ilut")
            defer { try? FileManager.default.removeItem(at: url) }
            do {
                _ = try await NativeExportService().generate(request, to: url)
                XCTFail("Expected an unrepresentable ILUT export to fail")
            } catch {}
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        }
    }

    func testServiceRejectsNegativeZeroUnitDomain() async throws {
        let signedZero = try LUTDomain(min: RGB64(-0.0, 0, 0), max: RGB64(1, 1, 1))
        let request = try LUTGenerationRequest(plan: TransformPlan(settings: settings()),
                                               size: 17, domain: signedZero)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-ilut-signed-zero-\(UUID().uuidString).ilut")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            _ = try await NativeExportService().generate(request, to: url)
            XCTFail("Signed zero changes an unrepresentable input domain")
        } catch let error as ILUTFailure {
            XCTAssertEqual(error.category, .lossyRepresentation)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}

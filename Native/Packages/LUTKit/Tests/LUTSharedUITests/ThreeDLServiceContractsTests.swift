import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTJobs
import LUTProject
import LUTSharedUI

final class ThreeDLServiceContractsTests: XCTestCase {
    func testNativeServiceDispatches3DLExtension() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-3dl-service-\(UUID().uuidString).3dl")
        defer { try? FileManager.default.removeItem(at: url) }
        let settings = TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
                                         inputSpace: .acesAP0, outputSpace: .acesAP0,
                                         inputRange: .video, outputRange: .data, exposureStops: 0)
        let request = try LUTGenerationRequest(plan: TransformPlan(settings: settings),
                                               size: 3, domain: .unit, blockNodes: 4, workerCount: 2)
        let written = try await NativeExportService().generate(request, to: url)
        XCTAssertEqual(written, 27)
        XCTAssertEqual(try ThreeDLParser.parse(Data(contentsOf: url), flavor: .flame).samples.count, 27)
    }

    func testNativeServiceSelectsLustreGrammarWithoutUI() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-3dl-lustre-service-\(UUID().uuidString).3dl")
        defer { try? FileManager.default.removeItem(at: url) }
        let settings = TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
                                         inputSpace: .acesAP0, outputSpace: .acesAP0,
                                         inputRange: .video, outputRange: .data, exposureStops: 0)
        let request = try LUTGenerationRequest(plan: TransformPlan(settings: settings),
                                               size: 9, domain: .unit, blockNodes: 19, workerCount: 2)
        let written = try await NativeExportService().generate(request, to: url,
                                                                threeDLFlavor: .lustre)
        XCTAssertEqual(written, 729)
        let data = try Data(contentsOf: url)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("3DMESH"))
        XCTAssertEqual(try ThreeDLParser.parse(data, flavor: .lustre).samples.count, 729)
    }

    func testNativeServiceStreamsNonlinearThreeDLShaper() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-3dl-shaper-service-\(UUID().uuidString).3dl")
        defer { try? FileManager.default.removeItem(at: url) }
        let settings = TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
                                         inputSpace: .acesAP0, outputSpace: .acesAP0,
                                         inputRange: .data, outputRange: .data, exposureStops: 0)
        let request = try LUTGenerationRequest(plan: TransformPlan(settings: settings),
                                               size: 3, domain: .unit, blockNodes: 2,
                                               workerCount: 2)
        let shaper = try CubeShaper(size: 3, domain: .unit, samples: [
            try RGB64(0, 0, 0), try RGB64(256.0 / 1023.0, 256.0 / 1023.0, 256.0 / 1023.0), try RGB64(1, 1, 1)
        ])
        let written = try await NativeExportService().generate(request, to: url,
                                                                threeDLFlavor: .flame,
                                                                threeDLShaper: shaper)
        XCTAssertEqual(written, 27)
        let parsed = try ThreeDLParser.parse(Data(contentsOf: url), flavor: .flame)
        XCTAssertEqual(parsed.shaper, shaper)
        XCTAssertEqual(parsed.samples[1].r, 256.0 / 1023.0, accuracy: 1.0 / 4095.0)
    }

    func testNativeServiceRejectsShaperForNonThreeDLOutput() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-shaper-reject-\(UUID().uuidString).cube")
        defer { try? FileManager.default.removeItem(at: url) }
        let settings = TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
                                         inputSpace: .acesAP0, outputSpace: .acesAP0,
                                         inputRange: .video, outputRange: .data, exposureStops: 0)
        let request = try LUTGenerationRequest(plan: TransformPlan(settings: settings),
                                               size: 2, domain: .unit, blockNodes: 2,
                                               workerCount: 1)
        let shaper = try CubeShaper(size: 2, domain: .unit,
                                    samples: [try RGB64(0, 0, 0), try RGB64(1, 1, 1)])
        do {
            _ = try await NativeExportService().generate(request, to: url,
                                                         threeDLFlavor: .flame,
                                                         threeDLShaper: shaper)
            XCTFail("Only 3DL supports a streamed shaper parameter")
        } catch {
            XCTAssertEqual(error as? NativeExportError, .threeDLShaperRequiresThreeDL)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testNativeServiceRejectsConflictingRequestAndExplicitShapers() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-shaper-conflict-\(UUID().uuidString).3dl")
        defer { try? FileManager.default.removeItem(at: url) }
        let settings = TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
                                         inputSpace: .acesAP0, outputSpace: .acesAP0,
                                         inputRange: .data, outputRange: .data, exposureStops: 0)
        let requestShaper = try CubeShaper(size: 2, domain: .unit,
                                           samples: [try RGB64(0, 0, 0), try RGB64(1, 1, 1)])
        let explicitShaper = try CubeShaper(size: 2, domain: .unit,
                                            samples: [try RGB64(0, 0, 0), try RGB64(512.0 / 1023.0,
                                                                                    512.0 / 1023.0,
                                                                                    512.0 / 1023.0)])
        let request = try LUTGenerationRequest(plan: TransformPlan(settings: settings),
                                               size: 2, domain: .unit, blockNodes: 2,
                                               workerCount: 1, inputShaper: requestShaper)
        do {
            _ = try await NativeExportService().generate(request, to: url,
                                                         threeDLFlavor: .flame,
                                                         threeDLShaper: explicitShaper)
            XCTFail("Conflicting shaper sources must be rejected")
        } catch {
            XCTAssertEqual(error as? NativeExportError, .conflictingThreeDLShaper)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    @MainActor
    func testDocumentSessionCreates3DLShareFile() async throws {
        let settings = TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
                                         inputSpace: .acesAP0, outputSpace: .acesAP0,
                                         inputRange: .video, outputRange: .data, exposureStops: 0)
        let document = try LUTProjectDocument(new: ProjectManifest(settings: settings,
                                                                    cubeSize: 17, domain: .unit))
        let session = ProjectExportSession()
        XCTAssertTrue(session.start(document: document, format: .threeDL))
        await session.waitForCurrentExport()
        XCTAssertEqual(session.exportStatus, .succeeded)
        let record = try XCTUnwrap(session.lastExport)
        defer { try? FileManager.default.removeItem(at: record.url) }
        XCTAssertEqual(record.url.pathExtension, "3dl")
        XCTAssertEqual(record.writtenNodes, 4913)
        XCTAssertEqual(try ThreeDLParser.parse(Data(contentsOf: record.url), flavor: .flame).samples.count,
                       4913)
    }

}

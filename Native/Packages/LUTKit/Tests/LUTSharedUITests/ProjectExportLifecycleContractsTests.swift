import Foundation
import XCTest
import LUTCore
import LUTJobs
import LUTProject
@testable import LUTSharedUI

@MainActor
final class ProjectExportLifecycleContractsTests: XCTestCase {
    func testSuccessfulTemporaryOutputRemainsAvailableAfterSessionCloses() async throws {
        let document = LUTProjectDocument()
        let session = ProjectExportSession(exportService: ImmediateExportService())

        XCTAssertTrue(session.start(document: document, format: .cube))
        await session.waitForCurrentExport()
        let output = try XCTUnwrap(session.lastExport?.url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))

        session.close()
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        try? FileManager.default.removeItem(at: output)
    }

    func testStartingNextExportCleansPreviousOwnedOutput() async throws {
        let document = LUTProjectDocument()
        let session = ProjectExportSession(exportService: ImmediateExportService())

        XCTAssertTrue(session.start(document: document, format: .cube))
        await session.waitForCurrentExport()
        let first = try XCTUnwrap(session.lastExport?.url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path))

        XCTAssertTrue(session.start(document: document, format: .spi3d))
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        await session.waitForCurrentExport()
        session.close()
    }

    func testStartingExportRecoversOldSiblingTemporaryFiles() async throws {
        let stale = FileManager.default.temporaryDirectory
            .appendingPathComponent(".lutcalc-\(UUID().uuidString).tmp")
        try Data("stale export".utf8).write(to: stale)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -7200)], ofItemAtPath: stale.path)
        defer { try? FileManager.default.removeItem(at: stale) }

        let session = ProjectExportSession(exportService: ImmediateExportService())
        XCTAssertTrue(session.start(document: LUTProjectDocument(), format: .cube))
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        await session.waitForCurrentExport()
        if let output = session.lastExport?.url {
            try? FileManager.default.removeItem(at: output)
        }
        session.close()
    }

    func testReopenAllowsARequestAfterViewLifecycleClose() async throws {
        let document = LUTProjectDocument()
        let session = ProjectExportSession(exportService: ImmediateExportService())

        session.close()
        XCTAssertFalse(session.start(document: document, format: .cube))

        session.reopen()
        XCTAssertTrue(session.start(document: document, format: .cube))
        await session.waitForCurrentExport()
        XCTAssertEqual(session.exportStatus, .succeeded)
        session.close()
    }

    func testBackgroundSuspensionCancelsInFlightExportAndAllowsRecovery() async throws {
        let document = LUTProjectDocument()
        let session = ProjectExportSession(exportService: DelayedExportService())

        XCTAssertTrue(session.start(document: document, format: .cube))
        XCTAssertEqual(session.exportStatus, .running)
        session.suspendForBackground()
        await session.waitForCurrentExport()

        XCTAssertEqual(session.exportStatus, .cancelled)
        XCTAssertNil(session.lastExport)

        session.reopen()
        XCTAssertTrue(session.start(document: document, format: .cube))
        await session.waitForCurrentExport()
        XCTAssertEqual(session.exportStatus, .succeeded)
        let output = try XCTUnwrap(session.lastExport?.url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        session.close()
    }

    func testBackgroundSuspensionDoesNotAllowLateCompletionToSucceed() async throws {
        let document = LUTProjectDocument()
        let session = ProjectExportSession(exportService: CancellationIgnoringExportService())

        XCTAssertTrue(session.start(document: document, format: .cube))
        XCTAssertEqual(session.exportStatus, .running)
        session.suspendForBackground()
        XCTAssertEqual(session.exportStatus, .cancelled)

        // The service deliberately writes after cancellation. The request
        // identity guard must keep the cancelled state and discard the output.
        await session.waitForCurrentExport()
        XCTAssertEqual(session.exportStatus, .cancelled)
        XCTAssertNil(session.lastExport)
    }

    func testBackgroundSuspensionWhenIdleIsNoOpAndReopenStillStarts() async throws {
        let document = LUTProjectDocument()
        let session = ProjectExportSession(exportService: ImmediateExportService())

        session.suspendForBackground()
        XCTAssertEqual(session.exportStatus, .idle)
        session.reopen()
        XCTAssertTrue(session.start(document: document, format: .cube))
        await session.waitForCurrentExport()
        XCTAssertEqual(session.exportStatus, .succeeded)
        session.close()
    }
}

private struct ImmediateExportService: ExportService, Sendable {
    func generate(_ request: LUTGenerationRequest, to output: URL) async throws -> Int {
        try Data("generated snapshot".utf8).write(to: output, options: .atomic)
        return 1
    }
}

private struct DelayedExportService: ExportService, Sendable {
    func generate(_ request: LUTGenerationRequest, to output: URL) async throws -> Int {
        try await Task.sleep(for: .milliseconds(150))
        try Task.checkCancellation()
        try Data("generated after recovery".utf8).write(to: output, options: .atomic)
        return 1
    }
}

private struct CancellationIgnoringExportService: ExportService, Sendable {
    func generate(_ request: LUTGenerationRequest, to output: URL) async throws -> Int {
        try? await Task.sleep(for: .milliseconds(150))
        try Data("late completion".utf8).write(to: output, options: .atomic)
        return 1
    }
}

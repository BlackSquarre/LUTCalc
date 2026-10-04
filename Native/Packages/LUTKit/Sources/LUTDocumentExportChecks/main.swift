import Foundation
import LUTCore
import LUTFormats
import LUTJobs
import LUTProject
import LUTSharedUI

private enum Failure: Error { case mismatch(String) }

@main
struct LUTDocumentExportChecks {
    static func main() async {
        do {
            try await run()
            print("H09 文档导出会话契约通过：不可变设置、取消后新请求、过期成功/失败清理、关闭窗口与用户一维 LUT 阶段")
        } catch {
            fputs("LUTDocumentExportChecks: \(error)\n", stderr)
            exit(1)
        }
    }

    @MainActor
    private static func run() async throws {
        let held = HeldExportService()
        let session = ProjectExportSession(exportService: held)
        var document = LUTProjectDocument()
        let firstRevision = document.revision
        let firstSettings = document.manifest.settings
        guard session.start(document: document) else { throw Failure.mismatch("first start") }
        let first = await held.nextCall()
        guard first.request.plan.settings == firstSettings,
              first.request.size == document.manifest.cubeSize else {
            throw Failure.mismatch("first snapshot")
        }
        try document.apply(changed(document, exposure: 2))
        try Data("first result".utf8).write(to: first.output)
        await held.finish(first.output, nodes: 17 * 17 * 17)
        await session.waitForCurrentExport()
        guard session.exportStatus == .succeeded,
              session.lastExport?.settings == firstSettings,
              session.lastExport?.revision == firstRevision,
              document.manifest.settings.exposureStops == 2 else {
            throw Failure.mismatch("edit changed in-flight snapshot")
        }
        try? FileManager.default.removeItem(at: first.output)

        guard session.start(document: document) else { throw Failure.mismatch("second start") }
        let stale = await held.nextCall()
        try Data("stale result".utf8).write(to: stale.output)
        session.cancel()
        guard session.exportStatus == .cancelled else { throw Failure.mismatch("cancel state") }
        guard session.start(document: document) else { throw Failure.mismatch("restart after cancel") }
        let fresh = await held.nextCall()
        try Data("fresh result".utf8).write(to: fresh.output)
        await held.finish(fresh.output, nodes: 17 * 17 * 17)
        await session.waitForCurrentExport()
        await held.finish(stale.output, nodes: 17 * 17 * 17)
        await session.waitForPendingExports()
        guard session.exportStatus == .succeeded,
              session.lastExport?.url == fresh.output,
              !FileManager.default.fileExists(atPath: stale.output.path),
              FileManager.default.fileExists(atPath: fresh.output.path) else {
            throw Failure.mismatch("late cancelled success replaced new result")
        }
        try? FileManager.default.removeItem(at: fresh.output)

        guard session.start(document: document) else { throw Failure.mismatch("failure start") }
        let failed = await held.nextCall()
        try Data("partial failure".utf8).write(to: failed.output)
        await held.fail(failed.output)
        await session.waitForCurrentExport()
        guard case .failed = session.exportStatus,
              !FileManager.default.fileExists(atPath: failed.output.path) else {
            throw Failure.mismatch("failed output leaked")
        }

        guard session.start(document: document) else { throw Failure.mismatch("close start") }
        let closing = await held.nextCall()
        try Data("late closed result".utf8).write(to: closing.output)
        session.close()
        await held.finish(closing.output, nodes: 17 * 17 * 17)
        await session.waitForPendingExports()
        guard !session.start(document: document),
              session.lastExport?.url == fresh.output,
              !FileManager.default.fileExists(atPath: closing.output.path) else {
            throw Failure.mismatch("closed session accepted result")
        }

        let asset = Data("LUT_1D_SIZE 2\n0 0 0\n1 1 1\n".utf8)
        let path = "Resources/user.cube"
        let withAsset = try LUTProjectDocument(new: ProjectManifest(
            settings: firstSettings, cubeSize: 17, domain: .unit,
            assetHashes: [path: ProjectAssets.sha256(of: asset)],
            assetRoles: [path: .userLUT]), assetContents: [path: asset])
        let assetHeld = HeldExportService()
        let withAssetSession = ProjectExportSession(exportService: assetHeld)
        guard withAssetSession.start(document: withAsset) else {
            throw Failure.mismatch("unit 1D user LUT was omitted")
        }
        let assetRequest = await assetHeld.nextCall()
        guard assetRequest.request.postLUT?.dimension == .one else {
            throw Failure.mismatch("unit 1D user LUT missing from export request")
        }
        withAssetSession.cancel()

        let native = ProjectExportSession()
        guard native.start(document: document) else { throw Failure.mismatch("native start") }
        await native.waitForCurrentExport()
        guard native.exportStatus == .succeeded, let result = native.lastExport,
              result.settings == document.manifest.settings,
              result.revision == document.revision,
              result.writtenNodes == 17 * 17 * 17 else {
            throw Failure.mismatch("native export report")
        }
        defer { try? FileManager.default.removeItem(at: result.url) }
        let parsed = try CubeParser.parse(url: result.url)
        guard parsed.samples.count == result.writtenNodes else {
            throw Failure.mismatch("native CUBE readback")
        }
    }

    private static func changed(_ document: LUTProjectDocument, exposure: Double) -> ProjectManifest {
        let old = document.manifest
        // Preserve every optional transform stage when changing exposure. This
        // keeps the check aligned with the production copy semantics as new
        // settings (for example HLG OOTF) are added.
        let settings = old.settings.withExposureStops(exposure)
        return ProjectManifest(id: old.id, settings: settings, cubeSize: old.cubeSize,
                               domain: old.domain, assetHashes: old.assetHashes,
                               assetRoles: old.assetRoles)
    }
}

private actor HeldExportService: ExportService {
    struct Call: Sendable {
        let request: LUTGenerationRequest
        let output: URL
    }

    private var calls: [Call] = []
    private var waiter: CheckedContinuation<Call, Never>?
    private var pending: [URL: CheckedContinuation<Int, Error>] = [:]

    func generate(_ request: LUTGenerationRequest, to output: URL) async throws -> Int {
        let call = Call(request: request, output: output)
        calls.append(call)
        waiter?.resume(returning: calls.removeFirst())
        waiter = nil
        return try await withCheckedThrowingContinuation { pending[output] = $0 }
    }

    func nextCall() async -> Call {
        if !calls.isEmpty { return calls.removeFirst() }
        return await withCheckedContinuation { waiter = $0 }
    }

    func finish(_ output: URL, nodes: Int) {
        pending.removeValue(forKey: output)?.resume(returning: nodes)
    }

    func fail(_ output: URL) {
        pending.removeValue(forKey: output)?.resume(throwing: Failure.mismatch("injected failure"))
    }
}

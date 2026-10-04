import Foundation
import LUTCore
import LUTFormats
import LUTSharedUI
import LUTCatalog
import LUTProject
import LUTJobs

@main
struct LUTSessionChecks {
    static func main() async {
        do {
            let session = await MainActor.run { EditorSession() }
            try await MainActor.run {
                let snapshot = try session.makeSnapshot()
                session.exposureDraft = "-"
                guard !session.commitExposure(), session.revision == 0 else { throw CheckFailure.incompleteDraftCommitted }
                session.exposureDraft = "2"
                guard session.commitExposure(), session.revision == 1,
                      session.exposureStops == 2,
                      snapshot.plan.settings.exposureStops == 1 else {
                    throw CheckFailure.snapshotChanged
                }
            }
            await session.export()
            guard let record = session.lastExport,
                  session.exportStatus == .succeeded,
                  record.settings.exposureStops == 2,
                  record.writtenNodes == 17 * 17 * 17 else {
                throw CheckFailure.exportFailed
            }
            let parsed = try CubeParser.parse(url: record.url)
            guard parsed.samples.count == record.writtenNodes else { throw CheckFailure.exportFailed }
            try FileManager.default.removeItem(at: record.url)
            let catalog = try AlgorithmCatalog.builtIn()
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("lutcalc-ui-project-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: folder) }
            let projectURL = folder.appendingPathComponent("session.lutcalc", isDirectory: true)
            let projectSettings = TransformSettings(
                inputTransfer: .srgbW3CExtended, outputTransfer: .srgbW3CExtended,
                inputSpace: .srgb, outputSpace: .srgb,
                inputRange: .video, outputRange: .video,
                exposureStops: 0.18000000000000002, rangeBitDepth: 12
            )
            let projectDomain = try LUTDomain(min: RGB64(-0.1, -0.1, -0.1),
                                               max: RGB64(1.5, 1.5, 1.5))
            let project = ProjectManifest(settings: projectSettings, cubeSize: 33, domain: projectDomain)
            try ProjectStore.saveNew(project, at: projectURL, catalog: catalog)
            try await MainActor.run {
                do {
                    try session.openProject(at: projectURL)
                    throw CheckFailure.unsavedEditsLost
                } catch EditorSessionError.unsavedChanges {}
                guard session.exposureStops == 2, session.projectURL == nil else {
                    throw CheckFailure.unsavedEditsLost
                }
                try session.openProject(at: projectURL, discardUnsavedChanges: true)
                let snapshot = try session.makeSnapshot()
                guard snapshot.plan.settings == projectSettings,
                      snapshot.size == 33, snapshot.domain == projectDomain,
                      session.outputMode == .custom,
                      session.documentID == project.id else { throw CheckFailure.projectStateLost }
                session.exposureDraft = "0.18000000000000005"
                guard session.commitExposure(), session.isProjectDirty else {
                    throw CheckFailure.projectStateLost
                }
                do {
                    try session.openProject(at: projectURL)
                    throw CheckFailure.unsavedEditsLost
                } catch EditorSessionError.unsavedChanges {}
                guard session.isProjectDirty,
                      session.exposureStops.bitPattern == (0.18000000000000005 as Double).bitPattern else {
                    throw CheckFailure.unsavedEditsLost
                }
                try session.saveProject()
                session.exposureDraft = "-"
                do {
                    try session.openProject(at: projectURL)
                    throw CheckFailure.unsavedEditsLost
                } catch EditorSessionError.unsavedChanges {}
                session.exposureDraft = String(session.exposureStops)
            }
            let saved = try ProjectStore.open(at: projectURL, catalog: catalog)
            guard saved.settings.inputTransfer == .srgbW3CExtended,
                  saved.settings.outputRange == .video,
                  saved.settings.rangeBitDepth == 12,
                  saved.domain == projectDomain,
                  saved.settings.exposureStops.bitPattern == (0.18000000000000005 as Double).bitPattern else {
                throw CheckFailure.projectStateLost
            }
            let assetFile = folder.appendingPathComponent("user.cube")
            try Data("LUT_1D_SIZE 2\n0 0 0\n1 1 1\n".utf8).write(to: assetFile)
            let assetPath = "Resources/user.cube"
            let assetSettings = TransformSettings(
                inputTransfer: .linearScene, outputTransfer: .linearScene,
                inputSpace: .acesAP0, outputSpace: .acesAP0,
                inputRange: .data, outputRange: .data, exposureStops: 0)
            let assetProject = ProjectManifest(settings: assetSettings, cubeSize: 17,
                domain: .unit, assetHashes: [assetPath: try ProjectAssets.sha256(of: assetFile)],
                assetRoles: [assetPath: .userLUT])
            let assetURL = folder.appendingPathComponent("asset.lutcalc", isDirectory: true)
            try ProjectStore.saveNew(assetProject, at: assetURL, catalog: catalog,
                                     assetSources: [assetPath: assetFile])
            try await MainActor.run {
                try session.openProject(at: assetURL)
                let request = try session.makeSnapshot()
                guard request.postLUT?.dimension == .one else {
                    throw CheckFailure.projectStateLost
                }
            }
            await session.export()
            let assetExport = await MainActor.run { session.lastExport }
            guard await MainActor.run(body: { session.exportStatus == .succeeded }),
                  let assetExport else { throw CheckFailure.projectStateLost }
            try FileManager.default.removeItem(at: assetExport.url)
            let held = HeldExportService()
            let switching = await MainActor.run { EditorSession(exportService: held) }
            let oldTask = Task { await switching.export() }
            let oldOutput = await held.nextOutput()
            try Data("stale result".utf8).write(to: oldOutput)
            try await MainActor.run { try switching.openProject(at: projectURL) }
            await held.finishNext()
            await oldTask.value
            let staleDidNotCommit = await MainActor.run {
                switching.exportStatus == .idle && switching.lastExport == nil &&
                switching.documentID == project.id
            }
            guard staleDidNotCommit, !FileManager.default.fileExists(atPath: oldOutput.path) else {
                throw CheckFailure.staleExportCommitted
            }
            let failing = HeldExportService()
            let switchingAfterFailure = await MainActor.run { EditorSession(exportService: failing) }
            let failedTask = Task { await switchingAfterFailure.export() }
            let failedOutput = await failing.nextOutput()
            try Data("stale failure".utf8).write(to: failedOutput)
            try await MainActor.run { try switchingAfterFailure.openProject(at: projectURL) }
            await failing.failNext()
            await failedTask.value
            let staleFailureDidNotCommit = await MainActor.run {
                switchingAfterFailure.exportStatus == .idle && switchingAfterFailure.lastExport == nil
            }
            guard staleFailureDidNotCommit,
                  !FileManager.default.fileExists(atPath: failedOutput.path) else {
                throw CheckFailure.staleExportCommitted
            }
            let fresh = await MainActor.run { EditorSession() }
            let freshURL = folder.appendingPathComponent("fresh.lutcalc", isDirectory: true)
            try await MainActor.run {
                try fresh.newProject()
                guard fresh.hasUnsavedChanges, !fresh.canUndo else {
                    throw CheckFailure.newProjectHistory
                }
                fresh.exposureDraft = "2"
                guard fresh.commitExposure(), fresh.canUndo,
                      fresh.undo(), fresh.exposureStops == 1,
                      fresh.redo(), fresh.exposureStops == 2 else {
                    throw CheckFailure.newProjectHistory
                }
                try fresh.saveProject(to: freshURL)
                guard !fresh.hasUnsavedChanges else { throw CheckFailure.newProjectHistory }
            }
            guard try ProjectStore.open(at: freshURL, catalog: catalog).settings.exposureStops == 2 else {
                throw CheckFailure.newProjectHistory
            }
            print("H09 会话契约通过：不完整数值草稿未提交，已创建的导出请求不受后续编辑影响")
            print("H09 共享会话导出通过：17³ CUBE 写出、读回与请求快照一致")
            print("H09/H12 项目草稿接线通过：完整设置与域保留、精确曝光保存、单位域一维用户 LUT 生成后阶段")
            print("H09 导出身份契约通过：切换项目后旧成功/失败结果均不提交且任务输出已清理")
            print("H12 未保存编辑保护通过：默认拒绝项目切换，显式丢弃后才能打开")
            print("H12 新项目会话通过：首次保存前可撤销/重做，保存后恢复干净状态")
        } catch {
            fputs("LUTSessionChecks: \(error)\n", stderr)
            exit(1)
        }
    }
}

private enum CheckFailure: Error {
    case incompleteDraftCommitted
    case snapshotChanged
    case exportFailed
    case projectStateLost
    case staleExportCommitted
    case unsavedEditsLost
    case newProjectHistory
}

private actor HeldExportService: ExportService {
    private var outputWaiter: CheckedContinuation<URL, Never>?
    private var finishWaiter: CheckedContinuation<Int, Error>?
    private var pendingURL: URL?

    func generate(_ request: LUTGenerationRequest, to output: URL) async throws -> Int {
        pendingURL = output
        outputWaiter?.resume(returning: output)
        outputWaiter = nil
        return try await withCheckedThrowingContinuation { continuation in finishWaiter = continuation }
    }

    func nextOutput() async -> URL {
        if let pendingURL { return pendingURL }
        return await withCheckedContinuation { continuation in outputWaiter = continuation }
    }

    func finishNext() {
        finishWaiter?.resume(returning: 17 * 17 * 17)
        finishWaiter = nil
    }

    func failNext() {
        finishWaiter?.resume(throwing: CheckFailure.exportFailed)
        finishWaiter = nil
    }
}

import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers
import LUTJobs
import LUTFormats
import LUTProject

public enum GeneratedLUTExportDocumentError: Error, Equatable, Sendable {
    case emptyFilename
    case resourceLimit
}

/// LUTCalc 生成文件使用的稳定导出类型。
/// 不依赖系统对 `.cube` 等扩展名的动态猜测，避免系统把 CUBE 误识别为厂商专用类型。
public enum LUTExportContentTypes {
    public static let cube = UTType(exportedAs: "com.lutcalc.cube", conformingTo: .data)
    public static let spi3d = UTType(exportedAs: "com.lutcalc.spi3d", conformingTo: .data)
    public static let spi1d = UTType(exportedAs: "com.lutcalc.spi1d", conformingTo: .data)
    public static let threeDL = UTType(exportedAs: "com.lutcalc.3dl", conformingTo: .data)
    public static let ilut = UTType(exportedAs: "com.lutcalc.ilut", conformingTo: .data)
    public static let olut = UTType(exportedAs: "com.lutcalc.olut", conformingTo: .data)
    public static let lut = UTType(exportedAs: "com.lutcalc.lut", conformingTo: .data)
    public static let vlt = UTType(exportedAs: "com.lutcalc.vlt", conformingTo: .data)
}

/// 已生成 LUT 的独立文件文稿。它在生成任务成功后捕获字节，
/// 因此系统文件面板打开、取消或延迟写出不会读取正在变化的临时文件。
public struct GeneratedLUTExportDocument: FileDocument, Sendable {
    public static let readableContentTypes: [UTType] = [LUTExportContentTypes.cube,
                                                         LUTExportContentTypes.spi3d,
                                                         LUTExportContentTypes.spi1d,
                                                         LUTExportContentTypes.threeDL,
                                                         LUTExportContentTypes.ilut,
                                                         LUTExportContentTypes.olut,
                                                         LUTExportContentTypes.lut,
                                                         LUTExportContentTypes.vlt,
                                                         .data]
    public static let writableContentTypes: [UTType] = [LUTExportContentTypes.cube,
                                                         LUTExportContentTypes.spi3d,
                                                         LUTExportContentTypes.spi1d,
                                                         LUTExportContentTypes.threeDL,
                                                         LUTExportContentTypes.ilut,
                                                         LUTExportContentTypes.olut,
                                                         LUTExportContentTypes.lut,
                                                         LUTExportContentTypes.vlt,
                                                         .data]
    public static let maxBytes = 256 * 1024 * 1024

    public let suggestedFilename: String
    public let bytes: Data

    public var contentType: UTType {
        switch URL(fileURLWithPath: suggestedFilename).pathExtension.lowercased() {
        case "cube": return LUTExportContentTypes.cube
        case "spi3d": return LUTExportContentTypes.spi3d
        case "spi1d": return LUTExportContentTypes.spi1d
        case "3dl": return LUTExportContentTypes.threeDL
        case "ilut": return LUTExportContentTypes.ilut
        case "olut": return LUTExportContentTypes.olut
        case "lut": return LUTExportContentTypes.lut
        case "vlt": return LUTExportContentTypes.vlt
        default: return .data
        }
    }

    public static let emptyPlaceholder = GeneratedLUTExportDocument(
        uncheckedBytes: Data(), uncheckedFilename: "exported-lut.cube")

    private init(uncheckedBytes: Data, uncheckedFilename: String) {
        self.bytes = uncheckedBytes
        self.suggestedFilename = uncheckedFilename
    }

    public init(bytes: Data, suggestedFilename: String) throws {
        let normalizedFilename = URL(fileURLWithPath: suggestedFilename).lastPathComponent
        guard !suggestedFilename.isEmpty,
              normalizedFilename == suggestedFilename,
              suggestedFilename != ".", suggestedFilename != ".." else {
            throw GeneratedLUTExportDocumentError.emptyFilename
        }
        guard bytes.count <= Self.maxBytes else {
            throw GeneratedLUTExportDocumentError.resourceLimit
        }
        self.bytes = bytes
        self.suggestedFilename = suggestedFilename
    }

    public init(sourceURL: URL, suggestedFilename: String) throws {
        try self.init(bytes: Data(contentsOf: sourceURL, options: .mappedIfSafe),
                      suggestedFilename: suggestedFilename)
    }

    public init(configuration: ReadConfiguration) throws {
        try self.init(bytes: configuration.file.regularFileContents ?? Data(),
                      suggestedFilename: "exported-lut")
    }

    public func makeFileWrapper() -> FileWrapper {
        FileWrapper(regularFileWithContents: bytes)
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        makeFileWrapper()
    }
}

@MainActor
@Observable
public final class ProjectExportSession {
    public private(set) var exportStatus: ExportStatus = .idle
    public private(set) var lastExport: ExportRecord?

    private let exportService: any ExportService
    private var activeRequestID: UUID?
    private var latestRequestID: UUID?
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var ownedOutputs: Set<URL> = []
    private var isClosed = false

    public init(exportService: any ExportService = NativeExportService()) {
        self.exportService = exportService
    }

    @discardableResult
    public func start(document: LUTProjectDocument, format: FileLUTFormat = .cube) -> Bool {
        guard !isClosed, exportStatus != .running else { return false }
        _ = try? ProjectStore.recoverOrphanedTemporaryEntries(
            in: FileManager.default.temporaryDirectory,
            olderThan: ProjectStore.defaultOrphanRecoveryAge)
        cleanupOwnedOutputs()
        let request: LUTGenerationRequest
        do {
            request = try document.makeGenerationRequest()
        } catch {
            exportStatus = .failed(String(describing: error))
            return false
        }
        let requestID = UUID()
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("LUTCalc-\(document.manifest.id.uuidString)-\(requestID.uuidString).\(format.rawValue)")
        let revision = document.revision
        activeRequestID = requestID
        latestRequestID = requestID
        exportStatus = .running
        tasks[requestID] = Task { [weak self] in
            await self?.run(request, revision: revision, requestID: requestID, output: output)
        }
        return true
    }

    public func cancel() {
        guard exportStatus == .running, let requestID = activeRequestID else { return }
        activeRequestID = nil
        exportStatus = .cancelled
        tasks[requestID]?.cancel()
    }

    /// 应用进入后台时停止尚未提交的导出。后台挂起或终止不能把未完成任务
    /// 当作成功；已完成的 lastExport 保持可供返回前台后的分享/保存流程使用。
    public func suspendForBackground() {
        cancel()
    }

    public func close() {
        isClosed = true
        if exportStatus == .running { exportStatus = .cancelled }
        activeRequestID = nil
        for task in tasks.values { task.cancel() }
        let completedURL = lastExport?.url
        cleanupOwnedOutputs(keeping: completedURL)
    }

    /// DocumentGroup 可能暂时销毁视图；视图返回后允许创建新的导出请求。
    /// 已完成的输出仍按既有生命周期保留。
    public func reopen() {
        isClosed = false
    }

    public func waitForCurrentExport() async {
        guard let latestRequestID, let task = tasks[latestRequestID] else { return }
        await task.value
    }

    public func waitForPendingExports() async {
        for task in Array(tasks.values) { await task.value }
    }

    private func run(_ request: LUTGenerationRequest, revision: UInt64,
                     requestID: UUID, output: URL) async {
        defer { tasks[requestID] = nil }
        do {
            try Task.checkCancellation()
            let writtenNodes = try await exportService.generate(request, to: output)
            guard !isClosed, activeRequestID == requestID else {
                removeOwnedOutput(output)
                return
            }
            ownedOutputs.insert(output)
            activeRequestID = nil
            lastExport = ExportRecord(url: output, settings: request.plan.settings,
                                      revision: revision, writtenNodes: writtenNodes)
            exportStatus = .succeeded
        } catch is CancellationError {
            removeOwnedOutput(output)
            guard !isClosed, activeRequestID == requestID else { return }
            activeRequestID = nil
            exportStatus = .cancelled
        } catch {
            removeOwnedOutput(output)
            guard !isClosed, activeRequestID == requestID else { return }
            activeRequestID = nil
            exportStatus = .failed(String(describing: error))
        }
    }

    private func removeOwnedOutput(_ output: URL) {
        ownedOutputs.remove(output)
        try? FileManager.default.removeItem(at: output)
    }

    private func cleanupOwnedOutputs(keeping completedURL: URL? = nil) {
        for output in ownedOutputs {
            if output == completedURL { continue }
            try? FileManager.default.removeItem(at: output)
        }
        if let completedURL {
            ownedOutputs = ownedOutputs.filter { $0 == completedURL }
        } else {
            ownedOutputs.removeAll()
        }
    }
}

import Foundation
import Observation
import LUTCore
import LUTCatalog
import LUTFormats
import LUTJobs
import LUTProject

public enum OutputMode: String, CaseIterable, Sendable {
    case linearAP0
    case dlog2DGamut2
    case custom
}

public enum EditorSessionError: Error, Equatable, Sendable {
    case userLUTNotInPlan
    case userLUTRequiresUnitOneDimensional
    case invalidDraft
    case unsavedChanges
}

public enum ExportStatus: Equatable, Sendable {
    case idle
    case running
    case succeeded
    case cancelled
    case failed(String)
}

public struct ExportRecord: Sendable {
    public let url: URL
    public let settings: TransformSettings
    public let revision: UInt64
    public let writtenNodes: Int
}

public protocol ExportService: Sendable {
    func generate(_ request: LUTGenerationRequest, to output: URL) async throws -> Int
}

public enum NativeExportError: Error, Equatable, Sendable {
    case unsupportedFormat
    case threeDLShaperRequiresThreeDL
    case conflictingThreeDLShaper
}

public struct NativeExportService: ExportService, ExposureBatchExporter {
    private let allowOverwrite:Bool
    private let oneDTestHooks: GenerationTestHooks?
    private let didGenerateOneD: (@Sendable (LUT1DGenerationRequest, OneDGenerationReport) async -> Void)?

    public init(allowOverwrite:Bool = false) {
        self.allowOverwrite = allowOverwrite
        oneDTestHooks = nil
        didGenerateOneD = nil
    }

    package init(allowOverwrite: Bool, oneDTestHooks: GenerationTestHooks?,
                 didGenerateOneD: (@Sendable (LUT1DGenerationRequest, OneDGenerationReport) async -> Void)?) {
        self.allowOverwrite = allowOverwrite
        self.oneDTestHooks = oneDTestHooks
        self.didGenerateOneD = didGenerateOneD
    }

    public func generate(_ request:LUTGenerationRequest,to output:URL,allowOverwrite:Bool) async throws->Int {
        try await NativeExportService(allowOverwrite: allowOverwrite, oneDTestHooks: oneDTestHooks,
            didGenerateOneD: didGenerateOneD).generate(request, to: output)
    }

    public func generate(_ request:LUTGenerationRequest,to output:URL,allowOverwrite:Bool,
                         threeDLFlavor:ThreeDLFlavor) async throws->Int {
        try await NativeExportService(allowOverwrite: allowOverwrite, oneDTestHooks: oneDTestHooks,
            didGenerateOneD: didGenerateOneD).generate(request, to: output, threeDLFlavor: threeDLFlavor)
    }

    public func generate(_ request: LUTGenerationRequest, to output: URL) async throws -> Int {
        try await generate(request, to: output, threeDLFlavor: .flame)
    }

    /// Generates a `.3dl` using an explicit vendor grammar. Other file
    /// extensions retain their existing format-specific writers.
    public func generate(_ request: LUTGenerationRequest, to output: URL,
                         threeDLFlavor: ThreeDLFlavor,
                         threeDLShaper: CubeShaper? = nil) async throws -> Int {
        guard let format = FileLUTFormat(rawValue: output.pathExtension.lowercased()) else {
            throw NativeExportError.unsupportedFormat
        }
        if let threeDLShaper, let requestShaper = request.inputShaper,
           threeDLShaper != requestShaper {
            throw NativeExportError.conflictingThreeDLShaper
        }
        let effectiveThreeDLShaper = threeDLShaper ?? request.inputShaper
        guard effectiveThreeDLShaper == nil || format == .threeDL else {
            throw NativeExportError.threeDLShaperRequiresThreeDL
        }
#if DEBUG
        // UI automation only: keep the task observable long enough to exercise the
        // real cancellation control. This branch is enabled solely by an explicit
        // launch argument and is absent from Release builds.
        if ProcessInfo.processInfo.arguments.contains("-LUTCalcTestSlowExport") {
            try await Task.sleep(nanoseconds: 15_000_000_000)
        }
#endif
        if format == .ilut {
            guard AssimilateLUTWriter.isExactUnitDomain(request.domain),
                  request.plan.settings.inputSpace == request.plan.settings.outputSpace else {
                throw ILUTFailure(.lossyRepresentation)
            }
            return try await generateOneD(request, size: ILUTParser.size,
                sink: FileILUTSink(target: output, allowOverwrite: allowOverwrite))
        }
        if format == .olut {
            guard AssimilateLUTWriter.isExactUnitDomain(request.domain),
                  request.plan.settings.inputSpace == request.plan.settings.outputSpace else {
                throw OLUTFailure(.lossyRepresentation)
            }
            return try await generateOneD(request, size: OLUTParser.size,
                sink: FileOLUTSink(target: output, allowOverwrite: allowOverwrite))
        }
        if format == .lut {
            guard AssimilateLUTWriter.isExactUnitDomain(request.domain),
                  request.plan.settings.inputSpace == request.plan.settings.outputSpace else {
                throw AssimilateLUTFailure(.lossyRepresentation)
            }
            return try await generateOneD(request, size: 4096,
                sink: FileAssimilateLUTSink(target: output, allowOverwrite: allowOverwrite))
        }
        if format == .spi1d {
            return try await generateOneD(request, size: 1024,
                sink: FileSPI1DSink(target: output, allowOverwrite: allowOverwrite))
        }
        let generationRequest: LUTGenerationRequest
        if let effectiveThreeDLShaper {
            generationRequest = try LUTGenerationRequest(plan: request.plan, size: request.size,
                                                         domain: request.domain,
                                                         blockNodes: request.blockNodes,
                                                         workerCount: request.workerCount,
                                                         postLUT: request.postLUT,
                                                         postLUTSettings: request.postLUTSettings,
                                                         inputShaper: effectiveThreeDLShaper,
                                                         inputTransferInverse: request.inputTransferInverse)
        } else {
            generationRequest = request
        }
        let report = try await GenerationCoordinator().generate(
            generationRequest, sink: FileCubeSink(target: output, allowOverwrite: allowOverwrite,
                                                  format: format, threeDLFlavor: threeDLFlavor,
                                                  threeDLShaper: effectiveThreeDLShaper))
        return report.writtenNodes
    }

    private func generateOneD<S: OneDBlockSink>(_ request: LUTGenerationRequest, size: Int,
                                               sink: S) async throws -> Int {
        let oneD = try LUT1DGenerationRequest(plan: request.plan, size: size, domain: request.domain,
            blockNodes: request.blockNodes, workerCount: request.workerCount,
            postLUT: request.postLUT, postLUTSettings: request.postLUTSettings,
            inputTransferInverse: request.inputTransferInverse)
        let coordinator = if let oneDTestHooks {
            OneDGenerationCoordinator(testHooks: oneDTestHooks)
        } else { OneDGenerationCoordinator() }
        let report = try await coordinator.generate(oneD, sink: sink)
        await didGenerateOneD?(oneD, report)
        return report.writtenNodes
    }
}

@MainActor
@Observable
public final class EditorSession {
    public private(set) var documentID = UUID()
    public private(set) var revision: UInt64 = 0
    public private(set) var exposureStops: Double = 1
    public var exposureDraft = "1"
    public private(set) var inputRange: SignalNormalization = .data
    public private(set) var outputMode: OutputMode = .linearAP0
    public private(set) var cubeSize = 17
    public private(set) var exportStatus: ExportStatus = .idle
    public private(set) var lastExport: ExportRecord?
    public private(set) var inputError: String?
    private var project: ProjectEditingSession?
    private let exportService: any ExportService
    private var activeExportID: UUID?

    public var projectURL: URL? { project?.url }
    public var isProjectDirty: Bool { project?.isDirty ?? false }
    public var hasUnsavedChanges: Bool {
        let draftValue = Double(exposureDraft)
        let draftDirty = draftValue == nil || draftValue?.isFinite != true ||
            draftValue?.bitPattern != exposureStops.bitPattern
        return (project?.isDirty ?? (revision > 0)) || draftDirty
    }
    public var canUndo: Bool { project?.canUndo ?? false }
    public var canRedo: Bool { project?.canRedo ?? false }
    public var currentSettings: TransformSettings? { project?.current.settings }
    public var currentDomain: LUTDomain { project?.current.domain ?? .unit }

    public init(exportService: any ExportService = NativeExportService()) {
        self.exportService = exportService
    }

    public func commitExposure() -> Bool {
        guard let value = Double(exposureDraft), value.isFinite else {
            inputError = "请输入有限的曝光档数。"
            return false
        }
        if value.bitPattern != exposureStops.bitPattern {
            do {
                if let current = project?.current {
                    let old = current.settings
                    let settings = old.withExposureStops(value)
                    try applyProject(settings: settings)
                }
            } catch {
                inputError = "曝光设置无效：\(error)"
                return false
            }
            exposureStops = value
            revision &+= 1
        }
        inputError = nil
        return true
    }

    public func setInputRange(_ range: SignalNormalization) {
        guard inputRange != range else { return }
        if let old = project?.current.settings {
            do {
                try applyProject(settings: old.withInputRange(range))
            } catch { inputError = String(describing: error); return }
        }
        inputRange = range
        revision &+= 1
    }

    public func setOutputMode(_ mode: OutputMode) {
        guard mode != .custom, outputMode != mode else { return }
        if let old = project?.current.settings {
            do {
                try applyProject(settings: old.withOutput(
                    transfer: mode == .linearAP0 ? .linearScene : .djiDLog2,
                    space: mode == .linearAP0 ? .acesAP0 : .djiDGamut2))
            } catch { inputError = String(describing: error); return }
        }
        outputMode = mode
        revision &+= 1
    }

    public func setCubeSize(_ size: Int) {
        guard [17, 33, 65].contains(size) else { return }
        guard cubeSize != size else { return }
        if project != nil {
            do { try applyProject(cubeSize: size) }
            catch { inputError = String(describing: error); return }
        }
        cubeSize = size
        revision &+= 1
    }

    public func makeSnapshot() throws -> LUTGenerationRequest {
        if let manifest = project?.current {
            let assets: [String: Data]
            if manifest.assetHashes.isEmpty {
                assets = [:]
            } else {
                guard let projectURL = project?.url else {
                    throw ProjectError.missingAsset(manifest.assetHashes.keys.sorted().first!)
                }
                assets = try LUTProjectDocument(fileWrapper: FileWrapper(url: projectURL, options: .immediate)).assetContents
            }
            return try LUTProjectDocument(new: manifest, assetContents: assets).makeGenerationRequest()
        }
        let outputTransfer: TransferID = outputMode == .linearAP0 ? .linearScene : .djiDLog2
        let outputSpace: ColorSpaceID = outputMode == .linearAP0 ? .acesAP0 : .djiDGamut2
        let settings = TransformSettings(
            inputTransfer: .djiDLog2,
            outputTransfer: outputTransfer,
            inputSpace: .djiDGamut2,
            outputSpace: outputSpace,
            inputRange: inputRange,
            outputRange: .data,
            exposureStops: exposureStops
        )
        return try LUTGenerationRequest(plan: TransformPlan(settings: settings), size: cubeSize, domain: .unit)
    }

    public func openProject(at url: URL, discardUnsavedChanges: Bool = false) throws {
        guard discardUnsavedChanges || !hasUnsavedChanges else {
            throw EditorSessionError.unsavedChanges
        }
        let opened = try ProjectEditingSession(opening: url, catalog: AlgorithmCatalog.builtIn())
        project = opened
        activeExportID = nil
        documentID = opened.documentID
        revision = 0
        synchronizeFromProject()
        lastExport = nil
        exportStatus = .idle
        inputError = nil
    }

    public func newProject(discardUnsavedChanges: Bool = false) throws {
        guard discardUnsavedChanges || !hasUnsavedChanges else {
            throw EditorSessionError.unsavedChanges
        }
        let settings = TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 1
        )
        let created = try ProjectEditingSession(
            new: ProjectManifest(settings: settings, cubeSize: 17, domain: .unit),
            catalog: AlgorithmCatalog.builtIn()
        )
        project = created
        activeExportID = nil
        documentID = created.documentID
        revision = 0
        synchronizeFromProject()
        lastExport = nil
        exportStatus = .idle
        inputError = nil
    }

    public func saveProject() throws {
        guard commitExposure() else { throw EditorSessionError.invalidDraft }
        guard var editing = project else { throw ProjectSessionError.unboundDocument }
        try editing.save()
        project = editing
    }

    public func saveProject(to url: URL) throws {
        guard commitExposure() else { throw EditorSessionError.invalidDraft }
        var editing: ProjectEditingSession
        if let project {
            editing = project
        } else {
            let request = try makeSnapshot()
            editing = try ProjectEditingSession(
                new: ProjectManifest(id: documentID, settings: request.plan.settings,
                                     cubeSize: request.size, domain: request.domain),
                catalog: AlgorithmCatalog.builtIn())
        }
        try editing.save(to: url)
        project = editing
    }

    @discardableResult
    public func undo() -> Bool {
        guard var editing = project, editing.undo() else { return false }
        project = editing
        synchronizeFromProject()
        revision &+= 1
        return true
    }

    @discardableResult
    public func redo() -> Bool {
        guard var editing = project, editing.redo() else { return false }
        project = editing
        synchronizeFromProject()
        revision &+= 1
        return true
    }

    private func applyProject(settings: TransformSettings? = nil, cubeSize: Int? = nil) throws {
        guard var editing = project else { return }
        let current = editing.current
        try editing.apply(ProjectManifest(
            id: current.id, settings: settings ?? current.settings,
            cubeSize: cubeSize ?? current.cubeSize, domain: current.domain,
            assetHashes: current.assetHashes, assetRoles: current.assetRoles,
            userLUTPostStage: current.userLUTPostStage,
            userLUTInputInverse: current.userLUTInputInverse,
            exposureBatchPreset: current.exposureBatchPreset, inputShaper: current.inputShaper))
        project = editing
    }

    private func synchronizeFromProject() {
        guard let manifest = project?.current else { return }
        let settings = manifest.settings
        exposureStops = settings.exposureStops
        exposureDraft = String(settings.exposureStops)
        inputRange = settings.inputRange
        cubeSize = manifest.cubeSize
        switch (settings.outputTransfer, settings.outputSpace) {
        case (.linearScene, .acesAP0): outputMode = .linearAP0
        case (.djiDLog2, .djiDGamut2): outputMode = .dlog2DGamut2
        default: outputMode = .custom
        }
    }

    public func export() async {
        guard exportStatus != .running else { return }
        var output: URL?
        var requestID: UUID?
        var capturedDocumentID: UUID?
        do {
            guard commitExposure() else { return }
            let capturedRevision = revision
            let request = try makeSnapshot()
            let currentRequestID = UUID()
            requestID = currentRequestID
            capturedDocumentID = documentID
            activeExportID = currentRequestID
            exportStatus = .running
            let target = FileManager.default.temporaryDirectory
                .appendingPathComponent("LUTCalc-\(documentID.uuidString)-\(UUID().uuidString).cube")
            output = target
            let writtenNodes = try await exportService.generate(request, to: target)
            guard activeExportID == currentRequestID, documentID == capturedDocumentID else {
                try? FileManager.default.removeItem(at: target)
                return
            }
            activeExportID = nil
            lastExport = ExportRecord(
                url: target,
                settings: request.plan.settings,
                revision: capturedRevision,
                writtenNodes: writtenNodes
            )
            exportStatus = .succeeded
        } catch is CancellationError {
            if let requestID, let capturedDocumentID {
                guard activeExportID == requestID, documentID == capturedDocumentID else {
                    if let output { try? FileManager.default.removeItem(at: output) }
                    return
                }
            }
            activeExportID = nil
            exportStatus = .cancelled
        } catch {
            if let requestID, let capturedDocumentID {
                guard activeExportID == requestID, documentID == capturedDocumentID else {
                    if let output { try? FileManager.default.removeItem(at: output) }
                    return
                }
            }
            activeExportID = nil
            exportStatus = .failed(String(describing: error))
        }
    }
}

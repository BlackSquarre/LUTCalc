import Foundation
import Observation
import LUTCore
import LUTPreview

public protocol PreviewImageLoading: Sendable {
    func load(_ url: URL) async throws -> PreviewImage
}

public protocol CoordinatedPreviewImageDecoding: Sendable {
    func decode(_ url: URL) throws -> PreviewImage
}

public struct NativeCoordinatedPreviewImageDecoder: CoordinatedPreviewImageDecoding, Sendable {
    public init() {}

    public func decode(_ url: URL) throws -> PreviewImage {
        try Task<Never, Never>.checkCancellation()
        var result: Result<PreviewImage, Error>?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            do {
                try Task<Never, Never>.checkCancellation()
                // Keep ImageIO decoding and source ICC inspection inside the
                // same coordinated read, using the URL supplied by the provider.
                let image = try PreviewImageDecoder.decode(url: coordinatedURL)
                try Task<Never, Never>.checkCancellation()
                result = .success(image)
            } catch {
                result = .failure(error)
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CoordinatedFileReadError.accessorNotCalled }
        return try result.get()
    }
}

public struct NativePreviewImageLoader: PreviewImageLoading {
    private let access: any SecurityScopedResourceAccessing
    private let decoder: any CoordinatedPreviewImageDecoding

    public init(access: any SecurityScopedResourceAccessing = NativeSecurityScopedResourceAccess(),
                decoder: any CoordinatedPreviewImageDecoding = NativeCoordinatedPreviewImageDecoder()) {
        self.access = access
        self.decoder = decoder
    }

    public func load(_ url: URL) async throws -> PreviewImage {
        let decodeTask = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let didStartAccess = self.access.startAccessing(url)
            defer { if didStartAccess { self.access.stopAccessing(url) } }
            let image = try self.decoder.decode(url)
            try Task.checkCancellation()
            return image
        }
        return try await withTaskCancellationHandler {
            try await decodeTask.value
        } onCancel: {
            decodeTask.cancel()
        }
    }
}

public enum ProjectSampleError: Error, Equatable, Sendable {
    case noImage
    case invalidCoordinate
    case sourceConfirmationRequired
    case closed
}

public enum ImageLoadStatus: Equatable, Sendable {
    case idle
    case running
    case loaded
    case failed(String)
    case closed
}

public struct ProjectSampleRecord: Sendable {
    public let sourceURL: URL
    public let x: Int
    public let y: Int
    public let revision: UInt64
    public let settings: TransformSettings
    public let pixel: PreviewSample
}

@MainActor
@Observable
public final class ProjectSampleSession {
    public private(set) var image: PreviewImage?
    public private(set) var imageURL: URL?
    public private(set) var loadStatus: ImageLoadStatus = .idle
    public private(set) var sampleRecord: ProjectSampleRecord?
    public private(set) var displayBitmap: DisplayPreviewBitmap?
    public private(set) var displayStatus: ImageLoadStatus = .idle

    private let loader: any PreviewImageLoading
    private var activeLoadID: UUID?
    private var latestLoadID: UUID?
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var displayTask: Task<Void, Never>?
    private var isClosed = false

    public init(loader: any PreviewImageLoading = NativePreviewImageLoader()) {
        self.loader = loader
    }

    @discardableResult
    public func startLoading(_ url: URL) -> Bool {
        guard !isClosed else { return false }
        if let activeLoadID { tasks[activeLoadID]?.cancel() }
        displayTask?.cancel()
        displayTask = nil
        latestDisplayIdentity = nil
        let loadID = UUID()
        activeLoadID = loadID
        latestLoadID = loadID
        image = nil
        imageURL = nil
        sampleRecord = nil
        displayBitmap = nil
        displayStatus = .idle
        loadStatus = .running
        tasks[loadID] = Task { [weak self] in
            await self?.run(url, loadID: loadID)
        }
        return true
    }

    public func clearSample() { sampleRecord = nil }

    public func clearDisplayPreview() {
        displayTask?.cancel()
        displayTask = nil
        latestDisplayIdentity = nil
        displayBitmap = nil
        displayStatus = .idle
    }

    /// Runs the full image through the CPU Double reference path and then the
    /// independent display-only transform. Results are accepted only for the
    /// document revision and identity that started this request.
    public func startDisplayPreview(document: LUTProjectDocument,
                                    confirmedSource: Bool,
                                    outputAlpha: AlphaMode = .straight) {
        guard confirmedSource else {
            displayStatus = .failed("请先确认按当前项目输入曲线和色域解释图像")
            return
        }
        guard !isClosed, loadStatus == .loaded, let image else {
            displayStatus = .failed("没有已加载图像")
            return
        }
        displayTask?.cancel()
        displayBitmap = nil
        displayStatus = .running
        do {
            let generation = try document.makeGenerationRequest()
            let plan = generation.plan
            let identity = PreviewIdentity(documentID: document.manifest.id,
                                           revision: document.revision,
                                           requestID: UUID(), planVersion: plan.planVersion)
            let request = try image.previewRequest(plan: plan, outputAlpha: outputAlpha,
                                                   identity: identity, postLUT: generation.postLUT,
                                                   postLUTSettings: generation.postLUTSettings)
            let renderTask = Task.detached(priority: .userInitiated) {
                try Task.checkCancellation()
                let result = try CPUPreview.renderDisplay(request)
                try Task.checkCancellation()
                let bitmap = try result.makeBitmap()
                try Task.checkCancellation()
                return bitmap
            }
            latestDisplayIdentity = identity
            displayTask = Task { [weak self] in
                do {
                    let bitmap = try await withTaskCancellationHandler {
                        try await renderTask.value
                    } onCancel: {
                        renderTask.cancel()
                    }
                    guard let self else { return }
                    guard !self.isClosed, self.displayStatus == .running,
                          self.image != nil,
                          self.latestDisplayIdentity == identity else { return }
                    self.displayBitmap = bitmap
                    self.displayStatus = .loaded
                } catch is CancellationError {
                    guard let self, !self.isClosed,
                          self.latestDisplayIdentity == identity else { return }
                    self.displayStatus = .idle
                } catch {
                    guard let self, !self.isClosed,
                          self.latestDisplayIdentity == identity else { return }
                    self.displayStatus = .failed(String(describing: error))
                }
            }
        } catch {
            displayStatus = .failed(String(describing: error))
        }
    }

    public func resetForDocumentSwitch() {
        guard !isClosed else { return }
        if let activeLoadID { tasks[activeLoadID]?.cancel() }
        activeLoadID = nil
        latestLoadID = nil
        displayTask?.cancel()
        displayTask = nil
        latestDisplayIdentity = nil
        image = nil
        imageURL = nil
        sampleRecord = nil
        displayBitmap = nil
        displayStatus = .idle
        loadStatus = .idle
    }

    public func close() {
        isClosed = true
        activeLoadID = nil
        displayTask?.cancel()
        displayTask = nil
        latestDisplayIdentity = nil
        image = nil
        imageURL = nil
        sampleRecord = nil
        displayBitmap = nil
        displayStatus = .closed
        loadStatus = .closed
        for task in tasks.values { task.cancel() }
    }

    public func waitForCurrentLoad() async {
        guard let latestLoadID, let task = tasks[latestLoadID] else { return }
        await task.value
    }

    public func waitForPendingLoads() async {
        for task in Array(tasks.values) { await task.value }
    }

    @discardableResult
    public func sample(document: LUTProjectDocument, x: Int, y: Int,
                       confirmedSource: Bool) throws -> ProjectSampleRecord {
        guard !isClosed else { throw ProjectSampleError.closed }
        guard loadStatus == .loaded, let image, let imageURL else {
            throw ProjectSampleError.noImage
        }
        guard confirmedSource else { throw ProjectSampleError.sourceConfirmationRequired }
        guard (0..<image.width).contains(x), (0..<image.height).contains(y) else {
            throw ProjectSampleError.invalidCoordinate
        }
        let generation = try document.makeGenerationRequest()
        let plan = generation.plan
        let identity = PreviewIdentity(documentID: document.manifest.id,
                                       revision: document.revision, requestID: UUID(),
                                       planVersion: plan.planVersion)
        let request = try PreviewRequest(plan: plan, width: 1, height: 1,
                                         pixels: [image.pixels[x + image.width * y]],
                                         inputAlpha: image.alphaMode,
                                         outputAlpha: .straight, identity: identity,
                                         postLUT: generation.postLUT,
                                         postLUTSettings: generation.postLUTSettings)
        let pixel = try CPUPreview.render(request).sample(x: 0, y: 0)
        let record = ProjectSampleRecord(sourceURL: imageURL, x: x, y: y,
                                         revision: document.revision,
                                         settings: plan.settings, pixel: pixel)
        sampleRecord = record
        return record
    }

    private func run(_ url: URL, loadID: UUID) async {
        defer { tasks[loadID] = nil }
        do {
            try Task.checkCancellation()
            let decoded = try await loader.load(url)
            guard !isClosed, activeLoadID == loadID else { return }
            activeLoadID = nil
            image = decoded
            imageURL = url
            loadStatus = .loaded
        } catch is CancellationError {
            guard !isClosed, activeLoadID == loadID else { return }
            activeLoadID = nil
            loadStatus = .idle
        } catch {
            guard !isClosed, activeLoadID == loadID else { return }
            activeLoadID = nil
            loadStatus = .failed(String(describing: error))
        }
    }

    private var latestDisplayIdentity: PreviewIdentity?
}

import Foundation
import Observation
import LUTCore
import LUTFormats
import LUTAnalysis
import LUTProject

public enum UserLUTFormat: String, Equatable, Sendable {
    case cube
    case spi1d
    case spi3d
    case threeDL = "3dl"
    case ilut
    case olut
    case assimilate
    case vlt
    case lacube
    case labin
}

public enum UserLUTImportError: Error, Equatable, Sendable {
    case unsupportedExtension
    case noImportedLUT
    case closed
    case missingOriginalBytes
    case projectAlreadyHasAsset
    case sourceContentMismatch
    case notStoredUserLUT
    case noColourSection
}

public enum UserLUTSampleSection: String, Equatable, Sendable {
    case primary
    case colour
}

public struct ImportedUserLUT: Sendable {
    public let url: URL
    public let format: UserLUTFormat
    public let lut: CubeLUT
    public let analysis: LUTAnalysisFile?
    public let originalBytes: Data?

    public init(url: URL, format: UserLUTFormat, lut: CubeLUT, analysis: LUTAnalysisFile? = nil,
                originalBytes: Data? = nil) {
        self.url = url
        self.format = format
        self.lut = lut
        self.analysis = analysis
        self.originalBytes = originalBytes
    }

    public func sample(_ input: RGB64, interpolation: LUTInterpolation,
                       outside: LUTOutsidePolicy,
                       section: UserLUTSampleSection = .primary) throws -> RGB64 {
        try preparedSampler(interpolation: interpolation, section: section).sample(input, outside: outside)
    }

    public func preparedSampler(interpolation: LUTInterpolation,
                                section: UserLUTSampleSection = .primary) throws -> PreparedCubeSampler {
        switch section {
        case .primary:
            return try lut.preparedSampler(interpolation: interpolation)
        case .colour:
            guard let colourLUT = analysis?.colourLUT else { throw UserLUTImportError.noColourSection }
            return try colourLUT.preparedSampler(interpolation: interpolation)
        }
    }

    public func analyzeStructure() throws -> ImportedLUTAnalysisReport {
        try ImportedLUTAnalyzer.analyze(lut: lut, analysisFile: analysis)
    }
}

public protocol UserLUTLoading: Sendable {
    func load(_ url: URL) async throws -> ImportedUserLUT
}

public protocol CoordinatedFileReading: Sendable {
    func read(_ url: URL, maxBytes: Int) throws -> Data
}

public enum CoordinatedFileReadError: Error, Equatable, Sendable {
    case accessorNotCalled
}

public struct NativeCoordinatedFileReader: CoordinatedFileReading, Sendable {
    public init() {}

    public func read(_ url: URL, maxBytes: Int) throws -> Data {
        var result: Result<Data, Error>?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            do {
                let handle = try FileHandle(forReadingFrom: coordinatedURL)
                defer { try? handle.close() }
                var bytes = Data()
                while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
                    try Task<Never, Never>.checkCancellation()
                    let (count, overflow) = bytes.count.addingReportingOverflow(chunk.count)
                    guard !overflow, count <= maxBytes else {
                        throw ProjectError.assetSizeLimit
                    }
                    bytes.append(chunk)
                }
                result = .success(bytes)
            } catch {
                result = .failure(error)
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CoordinatedFileReadError.accessorNotCalled }
        return try result.get()
    }
}

public struct NativeUserLUTLoader: UserLUTLoading {
    private let access: any SecurityScopedResourceAccessing
    private let reader: any CoordinatedFileReading

    public init(access: any SecurityScopedResourceAccessing = NativeSecurityScopedResourceAccess(),
                reader: any CoordinatedFileReading = NativeCoordinatedFileReader()) {
        self.access = access
        self.reader = reader
    }

    public func load(_ url: URL) async throws -> ImportedUserLUT {
        let readTask = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let didStartAccess = self.access.startAccessing(url)
            defer { if didStartAccess { self.access.stopAccessing(url) } }
            let bytes = try self.reader.read(url, maxBytes: ProjectAssets.maxAssetBytes)
            try Task.checkCancellation()
            let imported = try Self.parse(bytes, named: url.lastPathComponent)
            try Task.checkCancellation()
            return ImportedUserLUT(url: url, format: imported.format, lut: imported.lut,
                                   analysis: imported.analysis, originalBytes: bytes)
        }
        return try await withTaskCancellationHandler {
            try await readTask.value
        } onCancel: {
            readTask.cancel()
        }
    }

    public static func parse(_ bytes: Data, named filename: String) throws -> ImportedUserLUT {
        guard bytes.count <= ProjectAssets.maxAssetBytes else { throw ProjectError.assetSizeLimit }
        let format: UserLUTFormat
        let lut: CubeLUT
        var analysis: LUTAnalysisFile? = nil
        switch URL(fileURLWithPath: filename).pathExtension.lowercased() {
            case "cube":
                format = .cube
                lut = try CubeParser.parse(bytes)
            case "spi1d":
                format = .spi1d
                lut = try SPI1DParser.parse(bytes).lut
            case "spi3d":
                format = .spi3d
                lut = try SPI3DParser.parse(bytes)
            case "3dl":
                format = .threeDL
                lut = try ThreeDLParser.parseAuto(bytes)
            case "ilut":
                format = .ilut
                lut = try ILUTParser.parse(bytes)
            case "olut":
                format = .olut
                lut = try OLUTParser.parse(bytes)
            case "lut":
                format = .assimilate
                lut = try AssimilateLUTParser.parse(bytes)
            case "vlt":
                format = .vlt
                lut = try VLTParser.parse(bytes)
                analysis = nil
            case "lacube":
                format = .lacube
                let parsed = try LACubeParser.parse(bytes)
                lut = parsed.transferLUT
                analysis = parsed
            case "labin":
                format = .labin
                let parsed = try LABinParser.parse(bytes)
                lut = parsed.transferLUT
                analysis = parsed
            default:
                throw UserLUTImportError.unsupportedExtension
        }
        return ImportedUserLUT(url: URL(fileURLWithPath: filename), format: format, lut: lut,
                               analysis: analysis, originalBytes: bytes)
    }
}

public enum UserLUTLoadStatus: Equatable, Sendable {
    case idle
    case running
    case loaded
    case failed(String)
    case closed
}

@MainActor
@Observable
public final class UserLUTImportSession {
    public private(set) var imported: ImportedUserLUT?
    public private(set) var sampleInput: RGB64?
    public private(set) var sampleOutput: RGB64?
    public private(set) var sampleSection: UserLUTSampleSection?
    public private(set) var cubicEndpointSlopes: [LegacyCubicEndpointSlopes] = []
    public private(set) var analysisReport: ImportedLUTAnalysisReport?
    public private(set) var inverseOutput: RGB64?
    public private(set) var inverseInput: RGB64?
    public private(set) var loadStatus: UserLUTLoadStatus = .idle

    private let loader: any UserLUTLoading
    private var activeLoadID: UUID?
    private var latestLoadID: UUID?
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var isClosed = false

    public init(loader: any UserLUTLoading = NativeUserLUTLoader()) {
        self.loader = loader
    }

    @discardableResult
    public func startLoading(_ url: URL) -> Bool {
        guard !isClosed else { return false }
        if let activeLoadID { tasks[activeLoadID]?.cancel() }
        let loadID = UUID()
        activeLoadID = loadID
        latestLoadID = loadID
        imported = nil
        sampleInput = nil
        sampleOutput = nil
        sampleSection = nil
        cubicEndpointSlopes = []
        analysisReport = nil
        inverseOutput = nil
        inverseInput = nil
        loadStatus = .running
        tasks[loadID] = Task { [weak self] in
            await self?.run(url, loadID: loadID)
        }
        return true
    }

    public func clear() {
        if let activeLoadID { tasks[activeLoadID]?.cancel() }
        activeLoadID = nil
        imported = nil
        sampleInput = nil
        sampleOutput = nil
        sampleSection = nil
        cubicEndpointSlopes = []
        analysisReport = nil
        inverseOutput = nil
        inverseInput = nil
        loadStatus = .idle
    }

    public func showStored(_ imported: ImportedUserLUT) {
        guard !isClosed else { return }
        if let activeLoadID { tasks[activeLoadID]?.cancel() }
        activeLoadID = nil
        self.imported = imported
        sampleInput = nil
        sampleOutput = nil
        sampleSection = nil
        cubicEndpointSlopes = []
        analysisReport = nil
        inverseOutput = nil
        inverseInput = nil
        loadStatus = .loaded
    }

    public func close() {
        isClosed = true
        activeLoadID = nil
        imported = nil
        sampleInput = nil
        sampleOutput = nil
        sampleSection = nil
        cubicEndpointSlopes = []
        analysisReport = nil
        inverseOutput = nil
        inverseInput = nil
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
    public func sample(_ input: RGB64, interpolation: LUTInterpolation,
                       outside: LUTOutsidePolicy,
                       section: UserLUTSampleSection = .primary) throws -> RGB64 {
        guard !isClosed else { throw UserLUTImportError.closed }
        guard let imported else { throw UserLUTImportError.noImportedLUT }
        sampleInput = nil
        sampleOutput = nil
        sampleSection = nil
        cubicEndpointSlopes = []
        let sampler = try imported.preparedSampler(interpolation: interpolation, section: section)
        let output = try sampler.sample(input, outside: outside)
        sampleInput = input
        sampleOutput = output
        sampleSection = section
        cubicEndpointSlopes = sampler.cubicEndpointSlopes
        return output
    }

    @discardableResult
    public func inspectStructure() throws -> ImportedLUTAnalysisReport {
        guard !isClosed else { throw UserLUTImportError.closed }
        guard let imported else { throw UserLUTImportError.noImportedLUT }
        let report = try imported.analyzeStructure()
        analysisReport = report
        return report
    }

    @discardableResult
    public func inverseTransfer(_ output: RGB64,
                                interpolation: LUTInterpolation = .trilinear) throws -> RGB64 {
        guard !isClosed else { throw UserLUTImportError.closed }
        guard let imported else { throw UserLUTImportError.noImportedLUT }
        inverseOutput = nil
        inverseInput = nil
        let input = try ImportedLUTAnalyzer.inverseTransfer(lut: imported.lut,
                                                            analysisFile: imported.analysis,
                                                            output: output,
                                                            interpolation: interpolation)
        inverseOutput = output
        inverseInput = input
        return input
    }

    private func run(_ url: URL, loadID: UUID) async {
        defer { tasks[loadID] = nil }
        do {
            try Task.checkCancellation()
            let value = try await loader.load(url)
            guard !isClosed, activeLoadID == loadID else { return }
            activeLoadID = nil
            imported = value
            analysisReport = nil
            sampleSection = nil
            inverseOutput = nil
            inverseInput = nil
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
}

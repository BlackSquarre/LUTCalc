import Foundation
import LUTCore
import LUTFormats

public enum FileSinkError: Error, Equatable, Sendable {
    case targetExists
    case destinationUnavailable
    case destinationPermissionDenied
    case temporaryCreationFailed
    case byteCountMismatch
    case targetChanged
    case unsafeTarget
}

public typealias FileLUTFormat = LUTExportFormat

public actor FileCubeSink: CubeBlockSink {
    public private(set) var state: SinkState = .idle
    public let target: URL
    public let format: FileLUTFormat
    /// The vendor grammar used when `format` is `.threeDL`. Other formats ignore it.
    public let threeDLFlavor: ThreeDLFlavor
    /// Optional input shaper written into a `.3dl` header and applied by the
    /// generation coordinator before evaluating the transform plan.
    public let threeDLShaper: CubeShaper?
    private let allowOverwrite: Bool
    private var originalFingerprint: String?
    private var temporary: URL?
    private var handle: FileHandle?
    private var writtenNodes = 0
    private var writtenBytes = 0
    private var nextBlock = 0
    private var gridSize = 0
    private var expectedGridNodes = 0
    private var threeDLHeaderBytes = 0
    private var threeDLRowBytes = 0

    public init(target: URL, allowOverwrite: Bool = false, format: FileLUTFormat = .cube,
                threeDLFlavor: ThreeDLFlavor = .flame,
                threeDLShaper: CubeShaper? = nil) {
        self.target = target.standardizedFileURL
        self.allowOverwrite = allowOverwrite
        self.format = format
        self.threeDLFlavor = threeDLFlavor
        self.threeDLShaper = threeDLShaper
    }

    public func prepare(size: Int, domain: LUTDomain, title: String) throws {
        guard state == .idle else { throw JobFailure.sinkState }
        try LocalFileCommit.preflightDestination(target)
        let grid = try Grid3D(size: size, domain: domain)
        if format == .spi3d || format == .threeDL || format == .vlt {
            if format == .vlt {
                guard size == VLTParser.size else { throw VLTFailure(.lossyRepresentation) }
            }
            let lower = domain.min
            let upper = domain.max
            guard lower.r.bitPattern == 0, lower.g.bitPattern == 0, lower.b.bitPattern == 0,
                  upper.r.bitPattern == 1.0.bitPattern,
                  upper.g.bitPattern == 1.0.bitPattern,
                  upper.b.bitPattern == 1.0.bitPattern else {
                if format == .threeDL { throw ThreeDLFailure(.lossyRepresentation) }
                if format == .vlt { throw VLTFailure(.lossyRepresentation) }
                throw SPI3DFailure(.lossyRepresentation, line: 0)
            }
        }
        gridSize = size
        expectedGridNodes = grid.nodeCount
        let values = try? target.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        if values?.isSymbolicLink == true { throw FileSinkError.unsafeTarget }
        if FileManager.default.fileExists(atPath: target.path) {
            guard allowOverwrite else { throw FileSinkError.targetExists }
            originalFingerprint = try LocalFileCommit.fingerprint(target)
        }
        let parent = target.deletingLastPathComponent()
        let temporary = parent.appendingPathComponent(".lutcalc-\(UUID().uuidString).tmp")
        guard FileManager.default.createFile(atPath: temporary.path, contents: nil) else {
            throw FileSinkError.temporaryCreationFailed
        }
        self.temporary = temporary
        do {
            handle = try FileHandle(forWritingTo: temporary)
            state = .writing
            switch format {
            case .cube:
                try write(try CubeWriter.header(dimension: .three, size: size, domain: domain, title: title))
            case .spi3d:
                try write(SPI3DWriter.header(size: size))
            case .spi1d:
                throw SPI1DFailure(.unsupported, line: 0)
            case .threeDL:
                let header = try ThreeDLWriter.header(size: size, inputBits: 10,
                                                      outputBits: 12, title: title,
                                                      flavor: threeDLFlavor,
                                                      shaper: threeDLShaper)
                threeDLHeaderBytes = header.utf8.count
                threeDLRowBytes = try ThreeDLWriter.fixedWidthRow(RGB64(0, 0, 0), outputBits: 12).utf8.count
                try write(header)
            case .ilut:
                throw ILUTFailure(.unsupported)
            case .olut:
                throw OLUTFailure(.unsupported)
            case .lut:
                throw AssimilateLUTFailure(.unsupported)
            case .vlt:
                try write(VLTWriter.header())
            }
        } catch {
            abort()
            throw error
        }
    }

    public func append(blockIndex: Int, samples: [RGB64]) throws {
        guard state == .writing else { throw JobFailure.sinkState }
        guard blockIndex == nextBlock else { throw JobFailure.outOfOrderBlock }
        let (total, overflow) = writtenNodes.addingReportingOverflow(samples.count)
        guard !overflow, total <= expectedGridNodes else { throw JobFailure.rowCountMismatch }
        if format == .threeDL {
            guard let handle else { throw JobFailure.sinkState }
            for (offset, sample) in samples.enumerated() {
                let index = writtenNodes + offset
                let red = index % gridSize
                let green = (index / gridSize) % gridSize
                let blue = index / (gridSize * gridSize)
                let fileIndex = (red * gridSize + green) * gridSize + blue
                let row = try ThreeDLWriter.fixedWidthRow(sample, outputBits: 12)
                try handle.seek(toOffset: UInt64(threeDLHeaderBytes + fileIndex * threeDLRowBytes))
                let bytes = Data(row.utf8)
                try handle.write(contentsOf: bytes)
                writtenBytes += bytes.count
            }
            writtenNodes += samples.count
            nextBlock += 1
            return
        }
        var text = String()
        text.reserveCapacity(samples.count * 64)
        for (offset, sample) in samples.enumerated() {
            switch format {
            case .cube:
                text += CubeWriter.sampleLine(sample)
            case .spi3d:
                let index = writtenNodes + offset
                let red = index % gridSize
                let green = (index / gridSize) % gridSize
                let blue = index / (gridSize * gridSize)
                text += SPI3DWriter.row(red: red, green: green, blue: blue, sample: sample)
            case .spi1d:
                throw SPI1DFailure(.unsupported, line: 0)
            case .threeDL:
                throw JobFailure.sinkState
            case .ilut:
                throw ILUTFailure(.unsupported)
            case .olut:
                throw OLUTFailure(.unsupported)
            case .lut:
                throw AssimilateLUTFailure(.unsupported)
            case .vlt:
                text += try VLTWriter.row(sample)
            }
        }
        try write(text)
        writtenNodes += samples.count
        nextBlock += 1
    }

    public func validate(expectedNodes: Int) throws {
        guard state == .writing, let temporary, let handle else { throw JobFailure.sinkState }
        guard writtenNodes == expectedNodes else { throw JobFailure.rowCountMismatch }
        if format == .threeDL, threeDLFlavor == .lustre {
            try handle.seek(toOffset: UInt64(threeDLHeaderBytes + expectedGridNodes * threeDLRowBytes))
            let suffix = Data("LUT8\ngamma 1.0\n".utf8)
            try handle.write(contentsOf: suffix)
            writtenBytes += suffix.count
        }
        handle.synchronizeFile()
        try handle.close()
        self.handle = nil
        let attributes = try FileManager.default.attributesOfItem(atPath: temporary.path)
        guard let size = attributes[.size] as? NSNumber, size.intValue == writtenBytes else {
            throw FileSinkError.byteCountMismatch
        }
        state = .validated
    }

    public func commit() throws {
        guard state == .validated, let temporary else { throw JobFailure.sinkState }
        if let originalFingerprint {
            try LocalFileCommit.replaceIfUnchanged(temporary: temporary, target: target,
                                                   originalFingerprint: originalFingerprint)
        } else {
            let values = try? target.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard values?.isSymbolicLink != true,
                  !FileManager.default.fileExists(atPath: target.path) else {
                throw FileSinkError.targetExists
            }
            try LocalFileCommit.publishNoOverwrite(temporary: temporary, target: target)
        }
        self.temporary = nil
        state = .committed
    }

    public func abort() {
        if state == .committed { return }
        try? handle?.close()
        handle = nil
        if let temporary { try? FileManager.default.removeItem(at: temporary) }
        temporary = nil
        state = .aborted
    }

    private func write(_ text: String) throws {
        guard let handle else { throw JobFailure.sinkState }
        let data = Data(text.utf8)
        try handle.write(contentsOf: data)
        writtenBytes += data.count
    }

}

import Foundation
import LUTCore
import LUTFormats

public actor FileSPI1DSink: OneDBlockSink {
    public private(set) var state: SinkState = .idle
    public let target: URL
    private let allowOverwrite: Bool
    private var originalFingerprint: String?
    private var temporary: URL?
    private var handle: FileHandle?
    private var writtenNodes = 0
    private var writtenBytes = 0
    private var nextBlock = 0
    private var expectedNodes = 0

    public init(target: URL, allowOverwrite: Bool = false) {
        self.target = target.standardizedFileURL
        self.allowOverwrite = allowOverwrite
    }

    public func prepare(size: Int, domain: LUTDomain, title: String) throws {
        guard state == .idle else { throw JobFailure.sinkState }
        try LocalFileCommit.preflightDestination(target)
        guard size >= 2 else { throw SPI1DFailure(.invalidDimension, line: 0) }
        guard size <= CubeParser.maxDecodedBytes / MemoryLayout<RGB64>.stride else {
            throw SPI1DFailure(.resourceLimit, line: 0)
        }
        guard domain.min.r.bitPattern == domain.min.g.bitPattern,
              domain.min.r.bitPattern == domain.min.b.bitPattern,
              domain.max.r.bitPattern == domain.max.g.bitPattern,
              domain.max.r.bitPattern == domain.max.b.bitPattern else {
            throw SPI1DFailure(.lossyRepresentation, line: 0)
        }
        expectedNodes = size
        let values = try? target.resourceValues(forKeys: [.isSymbolicLinkKey])
        if values?.isSymbolicLink == true { throw FileSinkError.unsafeTarget }
        if FileManager.default.fileExists(atPath: target.path) {
            guard allowOverwrite else { throw FileSinkError.targetExists }
            originalFingerprint = try LocalFileCommit.fingerprint(target)
        }
        let temporary = target.deletingLastPathComponent()
            .appendingPathComponent(".lutcalc-\(UUID().uuidString).tmp")
        guard FileManager.default.createFile(atPath: temporary.path, contents: nil) else {
            throw FileSinkError.temporaryCreationFailed
        }
        self.temporary = temporary
        do {
            handle = try FileHandle(forWritingTo: temporary)
            state = .writing
            try write(SPI1DWriter.header(size: size, domain: domain, components: 3))
        } catch {
            abort()
            throw error
        }
    }

    public func append(blockIndex: Int, samples: [RGB64]) throws {
        guard state == .writing, blockIndex == nextBlock else { throw JobFailure.outOfOrderBlock }
        let (total, overflow) = writtenNodes.addingReportingOverflow(samples.count)
        guard !overflow, total <= expectedNodes else { throw JobFailure.rowCountMismatch }
        var text = String()
        text.reserveCapacity(samples.count * 64)
        for sample in samples { text += SPI1DWriter.row(sample: sample, components: 3) }
        try write(text)
        writtenNodes = total
        nextBlock += 1
    }

    public func validate(expectedNodes: Int) throws {
        guard state == .writing, let temporary, let handle,
              writtenNodes == expectedNodes, expectedNodes == self.expectedNodes else {
            throw JobFailure.rowCountMismatch
        }
        try write("}\n")
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
            guard !FileManager.default.fileExists(atPath: target.path) else { throw FileSinkError.targetExists }
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

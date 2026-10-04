import Foundation
import LUTCore
import LUTFormats

public actor FileILUTSink: OneDBlockSink {
    public private(set) var state: SinkState = .idle
    public let target: URL
    private let allowOverwrite: Bool
    private var originalFingerprint: String?
    private var temporary: URL?
    private var nextBlock = 0
    private var samples: [RGB64] = []

    public init(target: URL, allowOverwrite: Bool = false) {
        self.target = target.standardizedFileURL
        self.allowOverwrite = allowOverwrite
    }

    public func prepare(size: Int, domain: LUTDomain, title: String) throws {
        guard state == .idle else { throw JobFailure.sinkState }
        try LocalFileCommit.preflightDestination(target)
        guard size == ILUTParser.size, AssimilateLUTWriter.isExactUnitDomain(domain) else {
            throw ILUTFailure(.lossyRepresentation)
        }
        let values = try? target.resourceValues(forKeys: [.isSymbolicLinkKey])
        if values?.isSymbolicLink == true { throw FileSinkError.unsafeTarget }
        if FileManager.default.fileExists(atPath: target.path) {
            guard allowOverwrite else { throw FileSinkError.targetExists }
            originalFingerprint = try LocalFileCommit.fingerprint(target)
        }
        samples.reserveCapacity(size)
        state = .writing
    }

    public func append(blockIndex: Int, samples newSamples: [RGB64]) throws {
        guard state == .writing else { throw JobFailure.sinkState }
        guard blockIndex == nextBlock else { throw JobFailure.outOfOrderBlock }
        guard newSamples.count <= ILUTParser.size - samples.count else { throw JobFailure.rowCountMismatch }
        samples.append(contentsOf: newSamples)
        nextBlock += 1
    }

    public func validate(expectedNodes: Int) throws {
        guard state == .writing, expectedNodes == ILUTParser.size,
              samples.count == expectedNodes else { throw JobFailure.rowCountMismatch }
        let lut = try CubeLUT(dimension: .one, size: expectedNodes,
                              domain: .unit, samples: samples)
        let text = try ILUTWriter.serialize(lut)
        let url = target.deletingLastPathComponent()
            .appendingPathComponent(".lutcalc-\(UUID().uuidString).tmp")
        temporary = url
        try Data(text.utf8).write(to: url, options: [.atomic])
        let handle = try FileHandle(forWritingTo: url)
        handle.synchronizeFile()
        try handle.close()
        guard (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue
                == text.utf8.count else { throw FileSinkError.byteCountMismatch }
        samples.removeAll()
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
        if let temporary { try? FileManager.default.removeItem(at: temporary) }
        temporary = nil
        samples.removeAll()
        state = .aborted
    }

}

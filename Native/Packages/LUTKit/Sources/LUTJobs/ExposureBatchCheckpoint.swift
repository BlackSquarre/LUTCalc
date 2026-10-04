import Foundation
import Darwin
import CryptoKit
import LUTCore

public enum ExposureBatchCheckpointError: Error, Equatable, Sendable {
    case busy, invalidCheckpoint, unsafeLocation, changedCheckpoint, missingPreparedOutput
}

public enum ExposureBatchCheckpointPhase: String, Codable, Sendable { case generating, prepared }

public struct ExposureBatchCheckpointIntent: Codable, Sendable {
    public let index: Int
    public let phase: ExposureBatchCheckpointPhase
    public let stagingFilename: String
    public let originalFingerprint: String?
    public let stagedFingerprint: String?
    public let writtenNodes: Int?
}

public struct ExposureBatchCheckpointSnapshot: Codable, Sendable {
    public let schemaVersion: Int
    public let ownerID: UUID
    public let revision: UInt64
    public let report: ExposureBatchReport
    public let active: ExposureBatchCheckpointIntent?
    public let abandonedStagingFiles: [String]
}

package enum ExposureBatchCheckpointEvent: String, Sendable {
    case beforeSave, generatingSaved, staged, preparedSaved, published, completedSaved
}
package struct ExposureBatchCheckpointTestHooks: Sendable {
    package let boundary: @Sendable (ExposureBatchCheckpointEvent, Int) async throws -> Void
    package init(_ boundary: @escaping @Sendable (ExposureBatchCheckpointEvent, Int) async throws -> Void) {
        self.boundary = boundary
    }
}

/// Local process-crash recovery. A durable intent precedes publication and
/// identifies the staged inode, original destination and immutable request.
/// Checksums detect corruption, not hostile forgery or authorization.
public actor ExposureBatchCheckpointStore {
    public let directory: URL
    private let testHooks: ExposureBatchCheckpointTestHooks?
    private var running = false
    private var directoryIdentity: String?
    private var ownerFingerprint: String?
    private var checkpointFingerprint: String?
    private var ownerID: UUID?
    private let maximumBytes = 4 * 1024 * 1024

    public init(directory: URL) { self.directory = directory.standardizedFileURL; testHooks = nil }
    package init(directory: URL, testHooks: ExposureBatchCheckpointTestHooks?) {
        self.directory = directory.standardizedFileURL; self.testHooks = testHooks
    }
    private struct Envelope: Codable { let payload: Data; let sha256: String }
    private var document: URL { directory.appendingPathComponent("checkpoint.json") }
    private var marker: URL { directory.appendingPathComponent("owner") }

    private static func directoryID(_ url: URL) throws -> String {
        var info = stat()
        guard url.isFileURL, lstat(url.path, &info) == 0,
              info.st_mode & S_IFMT == S_IFDIR else { throw ExposureBatchCheckpointError.unsafeLocation }
        return "\(info.st_dev):\(info.st_ino)"
    }
    private func verifyDirectory() throws {
        let current = try Self.directoryID(directory)
        if let directoryIdentity, current != directoryIdentity { throw ExposureBatchCheckpointError.unsafeLocation }
        if let ownerFingerprint, (try? LocalFileCommit.fingerprint(marker)) != ownerFingerprint {
            throw ExposureBatchCheckpointError.unsafeLocation
        }
        directoryIdentity = current
    }
    private static func syncDirectory(_ url: URL) throws {
        let fd = open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { close(fd) }
        guard fsync(fd) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    }
    private static func writeExclusive(_ data: Data, to url: URL) throws {
        let fd = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        try handle.write(contentsOf: data); try handle.synchronize()
    }
    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private func encoder() -> JSONEncoder {
        let value = JSONEncoder(); value.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]; return value
    }
    private func decodeStrict<T: Codable>(_ type: T.Type, data: Data) throws -> T {
        guard data.count <= maximumBytes else { throw ExposureBatchCheckpointError.invalidCheckpoint }
        do {
            try StrictJSONKeyScanner.validate(data)
            let value = try JSONDecoder().decode(type, from: data)
            let original = try JSONSerialization.jsonObject(with: data) as? NSDictionary
            let canonical = try JSONSerialization.jsonObject(with: encoder().encode(value))
            guard original?.isEqual(canonical) == true else { throw ExposureBatchCheckpointError.invalidCheckpoint }
            return value
        } catch { throw ExposureBatchCheckpointError.invalidCheckpoint }
    }
    public func loadSnapshot() throws -> ExposureBatchCheckpointSnapshot {
        try verifyDirectory()
        let ownerAttributes = try FileManager.default.attributesOfItem(atPath: marker.path)
        guard (ownerAttributes[.size] as? NSNumber)?.intValue == 36 else {
            throw ExposureBatchCheckpointError.invalidCheckpoint
        }
        let markerIdentity = try LocalFileCommit.fingerprint(marker)
        guard let owner = UUID(uuidString: String(decoding: try Data(contentsOf: marker), as: UTF8.self)) else {
            throw ExposureBatchCheckpointError.invalidCheckpoint
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: document.path)
        guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= maximumBytes else {
            throw ExposureBatchCheckpointError.invalidCheckpoint
        }
        let identity = try LocalFileCommit.fingerprint(document)
        if let checkpointFingerprint, identity != checkpointFingerprint { throw ExposureBatchCheckpointError.changedCheckpoint }
        let envelope = try decodeStrict(Envelope.self, data: Data(contentsOf: document))
        guard Self.digest(envelope.payload) == envelope.sha256 else { throw ExposureBatchCheckpointError.invalidCheckpoint }
        let snapshot = try decodeStrict(ExposureBatchCheckpointSnapshot.self, data: envelope.payload)
        guard snapshot.schemaVersion == 1, snapshot.ownerID == owner, snapshot.revision > 0 else {
            throw ExposureBatchCheckpointError.invalidCheckpoint
        }
        ownerID = owner; ownerFingerprint = markerIdentity; checkpointFingerprint = identity
        return snapshot
    }

    private func persist(_ snapshot: ExposureBatchCheckpointSnapshot) async throws {
        try await testHooks?.boundary(.beforeSave, snapshot.active?.index ?? -1)
        try verifyDirectory()
        let payload = try encoder().encode(snapshot)
        let bytes = try encoder().encode(Envelope(payload: payload, sha256: Self.digest(payload)))
        guard bytes.count <= maximumBytes else { throw ExposureBatchCheckpointError.invalidCheckpoint }
        let temporary = directory.appendingPathComponent(".journal-\(UUID().uuidString).tmp")
        try Self.writeExclusive(bytes, to: temporary)
        defer { try? FileManager.default.removeItem(at: temporary) }
        if let checkpointFingerprint {
            try LocalFileCommit.replaceIfUnchanged(temporary: temporary, target: document,
                                                   originalFingerprint: checkpointFingerprint)
        } else { try LocalFileCommit.publishNoOverwrite(temporary: temporary, target: document) }
        try Self.syncDirectory(directory)
        self.checkpointFingerprint = try LocalFileCommit.fingerprint(document)
    }

    private func saveProgress(_ revision: UInt64, report: ExposureBatchReport,
                              active: ExposureBatchCheckpointIntent?, abandoned: [String]) async throws -> UInt64 {
        let (next, overflow) = revision.addingReportingOverflow(1)
        guard !overflow, let ownerID else { throw ExposureBatchCheckpointError.invalidCheckpoint }
        try await persist(ExposureBatchCheckpointSnapshot(schemaVersion: 1, ownerID: ownerID,
            revision: next, report: report, active: active, abandonedStagingFiles: abandoned))
        return next
    }

    private func validate(_ snapshot: ExposureBatchCheckpointSnapshot, request: ExposureBatchRequest) throws {
        let previous = snapshot.report
        guard previous.schemaVersion == 1, previous.algorithm == ExposureBatchSettings.algorithm,
              previous.requestFingerprint == request.fingerprint, previous.items.count == request.items.count,
              snapshot.abandonedStagingFiles.count <= 1024 else { throw ExposureBatchError.checkpointMismatch }
        var foundIncomplete = false
        for i in request.items.indices {
            let old = previous.items[i], item = request.items[i]
            guard old.index == i, old.stop.bitPattern == item.stop.bitPattern, old.filename == item.filename else {
                throw ExposureBatchError.checkpointMismatch
            }
            if old.state == .completed {
                guard !foundIncomplete, old.writtenNodes == ExposureBatchCoordinator.expectedNodes(item, format: request.format),
                      old.fileFingerprint != nil else { throw ExposureBatchError.checkpointMismatch }
                guard (try? LocalFileCommit.fingerprint(item.url)) == old.fileFingerprint else {
                    throw ExposureBatchError.completedOutputChanged(i)
                }
            } else { foundIncomplete = true }
        }
        if let active = snapshot.active {
            guard request.items.indices.contains(active.index), previous.items[active.index].state != .completed,
                  active.index == previous.items.firstIndex(where: { $0.state != .completed }),
                  validStageName(active.stagingFilename, request: request) else { throw ExposureBatchError.checkpointMismatch }
            switch active.phase {
            case .generating:
                guard active.stagedFingerprint == nil, active.writtenNodes == nil else { throw ExposureBatchError.checkpointMismatch }
            case .prepared:
                guard active.stagedFingerprint != nil,
                      active.writtenNodes == ExposureBatchCoordinator.expectedNodes(request.items[active.index], format: request.format) else {
                    throw ExposureBatchError.checkpointMismatch
                }
            }
        }
        guard Set(snapshot.abandonedStagingFiles).count == snapshot.abandonedStagingFiles.count,
              snapshot.abandonedStagingFiles.allSatisfy({ validStageName($0, request: request) }) else {
            throw ExposureBatchError.checkpointMismatch
        }
        if previous.state == .completed {
            guard !foundIncomplete, snapshot.active == nil else { throw ExposureBatchError.checkpointMismatch }
        }
    }
    private func validStageName(_ name: String, request: ExposureBatchRequest) -> Bool {
        let suffix = "." + request.format.rawValue
        guard name.hasSuffix(suffix) else { return false }
        return UUID(uuidString: String(name.dropLast(suffix.count))) != nil
    }
    private func checkOriginal(_ url: URL, identity: String?) throws {
        if let identity {
            guard (try? LocalFileCommit.fingerprint(url)) == identity else { throw FileSinkError.targetChanged }
        } else {
            var info = stat()
            if lstat(url.path, &info) == 0 { throw FileSinkError.targetExists }
            guard errno == ENOENT else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        }
    }
    private func publish(_ intent: ExposureBatchCheckpointIntent, target: URL) throws -> String {
        try verifyDirectory()
        guard let expected = intent.stagedFingerprint else { throw ExposureBatchCheckpointError.invalidCheckpoint }
        // The destination may already have been committed before the process died.
        if (try? LocalFileCommit.fingerprint(target)) == expected { return expected }
        try checkOriginal(target, identity: intent.originalFingerprint)
        let staged = directory.appendingPathComponent(intent.stagingFilename)
        guard (try? LocalFileCommit.fingerprint(staged)) == expected else {
            throw ExposureBatchCheckpointError.missingPreparedOutput
        }
        let dir = directory, dirID = directoryIdentity
        let guardStage = {
            guard try Self.directoryID(dir) == dirID,
                  try LocalFileCommit.fingerprint(staged) == expected else { throw ExposureBatchCheckpointError.unsafeLocation }
        }
        if let original = intent.originalFingerprint {
            try LocalFileCommit.replaceIfUnchanged(temporary: staged, target: target,
                originalFingerprint: original, beforePublish: guardStage)
        } else { try LocalFileCommit.publishNoOverwrite(temporary: staged, target: target, beforePublish: guardStage) }
        try Self.syncDirectory(target.deletingLastPathComponent()); try Self.syncDirectory(directory)
        guard try LocalFileCommit.fingerprint(target) == expected else { throw FileSinkError.targetChanged }
        return expected
    }

    func generate(_ request: ExposureBatchRequest, exporter: any ExposureBatchExporter,
                  resuming: Bool) async throws -> ExposureBatchReport {
        guard !running else { throw ExposureBatchCheckpointError.busy }
        guard directory.isFileURL, let first = request.items.first,
              directory.deletingLastPathComponent() == first.url.deletingLastPathComponent() else {
            throw ExposureBatchCheckpointError.unsafeLocation
        }
        running = true; defer { running = false }
        if !resuming {
            guard mkdir(directory.path, 0o700) == 0 else {
                if errno == EEXIST { throw FileSinkError.targetExists }
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
            ownerID = UUID(); try Self.writeExclusive(Data(ownerID!.uuidString.utf8), to: marker)
            try Self.syncDirectory(directory); try Self.syncDirectory(directory.deletingLastPathComponent())
            checkpointFingerprint = nil; ownerFingerprint = try LocalFileCommit.fingerprint(marker)
        }
        try verifyDirectory()
        let lease = directory.appendingPathComponent("lease")
        let fd = open(lease.path, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw ExposureBatchCheckpointError.unsafeLocation }
        defer { flock(fd, LOCK_UN); close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_nlink == 1 else {
            throw ExposureBatchCheckpointError.unsafeLocation
        }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw ExposureBatchCheckpointError.busy }
        var revision: UInt64 = 0
        var results = request.items.map { ExposureBatchItemReport(index: $0.index, stop: $0.stop,
            filename: $0.filename, state: .pending, writtenNodes: nil, fileFingerprint: nil, failureDescription: nil) }
        var active: ExposureBatchCheckpointIntent?
        var abandoned: [String] = []
        if resuming {
            let old = try loadSnapshot(); try validate(old, request: request)
            revision = old.revision; results = old.report.items; active = old.active; abandoned = old.abandonedStagingFiles
        }
        func report(_ state: JobState) -> ExposureBatchReport {
            ExposureBatchReport(schemaVersion: 1, algorithm: ExposureBatchSettings.algorithm,
                requestFingerprint: request.fingerprint, state: state, items: results)
        }
        if !resuming { revision = try await saveProgress(revision, report: report(.running), active: active, abandoned: abandoned) }
        for i in results.indices where results[i].state != .completed {
            let item = request.items[i]
            if let intent = active, intent.phase == .prepared {
                if Task.isCancelled, (try? LocalFileCommit.fingerprint(item.url)) != intent.stagedFingerprint {
                    results[i] = ExposureBatchItemReport(index: i, stop: item.stop, filename: item.filename,
                        state: .cancelled, writtenNodes: nil, fileFingerprint: nil, failureDescription: "CancellationError()")
                    revision = try await saveProgress(revision, report: report(.cancelled), active: active, abandoned: abandoned)
                    return report(.cancelled)
                }
                let identity = try publish(intent, target: item.url)
                try await testHooks?.boundary(.published, i)
                results[i] = ExposureBatchItemReport(index: i, stop: item.stop, filename: item.filename,
                    state: .completed, writtenNodes: intent.writtenNodes, fileFingerprint: identity, failureDescription: nil)
                active = nil; revision = try await saveProgress(revision, report: report(.running), active: active, abandoned: abandoned); try await testHooks?.boundary(.completedSaved, i)
                continue
            }
            let original: String?
            if let intent = active {
                try checkOriginal(item.url, identity: intent.originalFingerprint)
                original = intent.originalFingerprint
                guard abandoned.count < 1024 else { throw ExposureBatchError.resourceLimit }
                abandoned.append(intent.stagingFilename)
            } else {
                var targetInfo = stat()
                if lstat(item.url.path, &targetInfo) == 0 {
                    guard request.allowOverwrite else { throw FileSinkError.targetExists }
                    original = try LocalFileCommit.fingerprint(item.url)
                } else {
                    guard errno == ENOENT else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
                    original = nil
                }
            }
            let name = UUID().uuidString + "." + request.format.rawValue
            active = ExposureBatchCheckpointIntent(index: i, phase: .generating, stagingFilename: name,
                originalFingerprint: original, stagedFingerprint: nil, writtenNodes: nil)
            results[i] = ExposureBatchItemReport(index: i, stop: item.stop, filename: item.filename,
                state: .running, writtenNodes: nil, fileFingerprint: nil, failureDescription: nil)
            revision = try await saveProgress(revision, report: report(.running), active: active, abandoned: abandoned); try await testHooks?.boundary(.generatingSaved, i)
            let staged = directory.appendingPathComponent(name)
            let nodes: Int
            do {
                try verifyDirectory()
                try Task.checkCancellation()
                nodes = try await exporter.generate(item.request, to: staged, allowOverwrite: false,
                    threeDLFlavor: request.threeDLFlavor)
                guard nodes == ExposureBatchCoordinator.expectedNodes(item, format: request.format) else { throw JobFailure.rowCountMismatch }
            } catch {
                let cancelled = error is CancellationError
                results[i] = ExposureBatchItemReport(index: i, stop: item.stop, filename: item.filename,
                    state: cancelled ? .cancelled : .failed, writtenNodes: nil, fileFingerprint: nil,
                    failureDescription: String(String(describing: error).prefix(4096)))
                revision = try await saveProgress(revision, report: report(cancelled ? .cancelled : .failed), active: active, abandoned: abandoned)
                return report(cancelled ? .cancelled : .failed)
            }
            try await testHooks?.boundary(.staged, i)
            let fingerprint = try LocalFileCommit.fingerprint(staged)
            active = ExposureBatchCheckpointIntent(index: i, phase: .prepared, stagingFilename: name,
                originalFingerprint: original, stagedFingerprint: fingerprint, writtenNodes: nodes)
            revision = try await saveProgress(revision, report: report(.running), active: active, abandoned: abandoned); try await testHooks?.boundary(.preparedSaved, i)
            if Task.isCancelled {
                results[i] = ExposureBatchItemReport(index: i, stop: item.stop, filename: item.filename,
                    state: .cancelled, writtenNodes: nil, fileFingerprint: nil, failureDescription: "CancellationError()")
                revision = try await saveProgress(revision, report: report(.cancelled), active: active, abandoned: abandoned)
                return report(.cancelled)
            }
            let identity = try publish(active!, target: item.url)
            try await testHooks?.boundary(.published, i)
            results[i] = ExposureBatchItemReport(index: i, stop: item.stop, filename: item.filename,
                state: .completed, writtenNodes: nodes, fileFingerprint: identity, failureDescription: nil)
            active = nil; revision = try await saveProgress(revision, report: report(.running), active: active, abandoned: abandoned); try await testHooks?.boundary(.completedSaved, i)
        }
        revision = try await saveProgress(revision, report: report(.completed), active: active, abandoned: abandoned); return report(.completed)
    }
}

import Foundation
import Darwin
import CryptoKit

/// Publishes a sibling temporary file on a local filesystem without replacing a late owner.
/// File Provider support requires separate platform evidence.
enum LocalFileCommit {
    enum FingerprintBoundary: Equatable {
        case identified, opened(Int32), chunkRead(Int), finishedRead
    }
    /// Checks the local destination boundary before creating a sibling
    /// temporary file. File Provider URLs still require platform evidence;
    /// this only reports deterministic path and write-access failures.
    static func preflightDestination(_ target: URL) throws {
        let parent = target.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw FileSinkError.destinationUnavailable
        }
        guard FileManager.default.isWritableFile(atPath: parent.path) else {
            throw FileSinkError.destinationPermissionDenied
        }
    }

    /// Captures identity and bytes from the same open regular file, then checks
    /// that its metadata and namespace entry stayed stable during the read.
    static func fingerprint(_ url: URL,
                            boundary: ((FingerprintBoundary) throws -> Void)? = nil) throws -> String {
        guard url.isFileURL, !url.path.utf8.contains(0) else { throw FileSinkError.unsafeTarget }
        var identified = stat()
        guard lstat(url.path, &identified) == 0,
              identified.st_mode & S_IFMT == S_IFREG else {
            throw FileSinkError.unsafeTarget
        }
        try boundary?(.identified)
        // NONBLOCK prevents a late FIFO substitution from blocking open before
        // fstat can reject it. Regular-file reads retain their existing behavior.
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard fd >= 0 else {
            let code = errno
            if code == ELOOP || code == ENOENT || code == ENOTDIR { throw FileSinkError.unsafeTarget }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(code))
        }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        var opened = stat()
        guard fstat(fd, &opened) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        guard opened.st_mode & S_IFMT == S_IFREG else { throw FileSinkError.unsafeTarget }
        guard sameVersion(identified, opened) else { throw FileSinkError.targetChanged }
        try boundary?(.opened(fd))
        var hasher = SHA256()
        var index = 0
        var bytes: Int64 = 0
        while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            hasher.update(data: chunk)
            let (next, overflow) = bytes.addingReportingOverflow(Int64(chunk.count))
            guard !overflow else { throw FileSinkError.targetChanged }
            bytes = next
            try boundary?(.chunkRead(index)); index += 1
        }
        try boundary?(.finishedRead)
        var finished = stat(), named = stat()
        guard fstat(fd, &finished) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        guard sameVersion(opened, finished), bytes == opened.st_size,
              lstat(url.path, &named) == 0, sameVersion(opened, named) else {
            throw FileSinkError.targetChanged
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        let device = UInt64(truncatingIfNeeded: opened.st_dev), inode = UInt64(opened.st_ino)
        return "\(device):\(inode):\(digest)"
    }

    private static func sameVersion(_ a: stat, _ b: stat) -> Bool {
        a.st_dev == b.st_dev && a.st_ino == b.st_ino && a.st_mode == b.st_mode && a.st_size == b.st_size &&
        a.st_mtimespec.tv_sec == b.st_mtimespec.tv_sec && a.st_mtimespec.tv_nsec == b.st_mtimespec.tv_nsec &&
        a.st_ctimespec.tv_sec == b.st_ctimespec.tv_sec && a.st_ctimespec.tv_nsec == b.st_ctimespec.tv_nsec
    }

    static func publishNoOverwrite(temporary: URL, target: URL,
                                   beforePublish: () throws -> Void = {}) throws {
        var coordinationError: NSError?
        var accessorError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: target, options: [], error: &coordinationError) { coordinatedTarget in
            do {
                try beforePublish()
                let result = temporary.withUnsafeFileSystemRepresentation { source in
                    coordinatedTarget.withUnsafeFileSystemRepresentation { destination in
                        link(source!, destination!)
                    }
                }
                guard result == 0 else {
                    if errno == EEXIST { throw FileSinkError.targetExists }
                    throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
                }
            } catch {
                accessorError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let accessorError { throw accessorError }
        try? FileManager.default.removeItem(at: temporary)
    }

    /// Replaces an existing destination only when the coordinated target still
    /// has the identity captured during prepare. The check and replacement are
    /// inside one File Provider coordination callback.
    static func replaceIfUnchanged(temporary: URL, target: URL,
                                   originalFingerprint: String,
                                   beforePublish: () throws -> Void = {}) throws {
        var coordinationError: NSError?
        var accessorError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: target, options: [], error: &coordinationError) { coordinatedTarget in
            do {
                try beforePublish()
                guard try fingerprint(coordinatedTarget) == originalFingerprint else {
                    throw FileSinkError.targetChanged
                }
                _ = try FileManager.default.replaceItemAt(
                    coordinatedTarget, withItemAt: temporary,
                    backupItemName: nil, options: [.usingNewMetadataOnly]
                )
            } catch {
                accessorError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let accessorError { throw accessorError }
    }
}

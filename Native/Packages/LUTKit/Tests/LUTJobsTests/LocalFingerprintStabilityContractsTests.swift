import Foundation
import Darwin
import XCTest
@testable import LUTJobs

final class LocalFingerprintStabilityContractsTests: XCTestCase {
    private func folder(_ name: String) throws -> URL {
        let root = ProcessInfo.processInfo.environment["LUTCALC_FINGERPRINT_ARTIFACT_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let folder = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
    private func clean(_ folder: URL) {
        if ProcessInfo.processInfo.environment["LUTCALC_FINGERPRINT_ARTIFACT_DIR"] == nil {
            try? FileManager.default.removeItem(at: folder.deletingLastPathComponent())
        }
    }
    private func retain(_ result: [String: String], in folder: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(result).write(to: folder.appendingPathComponent("result.json"))
    }
    private func target(_ folder: URL, bytes: Data = Data("abc".utf8)) throws -> URL {
        let url = folder.appendingPathComponent("target.bin")
        try bytes.write(to: url, options: .atomic)
        return url
    }

    func testStableEmptySmallAndMultiBlockFingerprintsKeepCanonicalIdentity() throws {
        let folder = try folder("stable"); defer { clean(folder) }
        let fixtures: [(String, Data, String)] = [
            ("empty", Data(), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
            ("small", Data("abc".utf8), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
            ("large", Data(repeating: 0x41, count: 3 * 1024 * 1024), "a57493c037eb3a8a86ff87072edde226110455cd7fdab2f87bb4df072f67ffb0")]
        var results: [String: String] = [:]
        for (name, bytes, sha) in fixtures {
            let url = folder.appendingPathComponent(name + ".bin"); try bytes.write(to: url, options: .atomic)
            let values = try FileManager.default.attributesOfItem(atPath: url.path)
            let device = try XCTUnwrap(values[.systemNumber] as? NSNumber).uint64Value
            let inode = try XCTUnwrap(values[.systemFileNumber] as? NSNumber).uint64Value
            let value = try LocalFileCommit.fingerprint(url)
            XCTAssertEqual(value, "\(device):\(inode):\(sha)")
            results[name + ".bin"] = value
        }
        try retain(results, in: folder)
    }

    func testSameBytesReplacementBetweenIdentificationAndOpenIsRejected() throws {
        let folder = try folder("before-open"); defer { clean(folder) }
        let url = try target(folder), original = try LocalFileCommit.fingerprint(url)
        var changed = false
        XCTAssertThrowsError(try LocalFileCommit.fingerprint(url) { phase in
            if phase == .identified { try Data("abc".utf8).write(to: url, options: .atomic); changed = true }
        }) { XCTAssertEqual($0 as? FileSinkError, .targetChanged) }
        XCTAssertTrue(changed)
        let current = try LocalFileCommit.fingerprint(url)
        XCTAssertNotEqual(current, original)
        XCTAssertEqual(try Data(contentsOf: url), Data("abc".utf8))
        try retain(["before": original, "after": current], in: folder)
    }

    func testLateSymlinkIsNeverOpenedOrHashed() throws {
        let folder = try folder("late-symlink"); defer { clean(folder) }
        let url = try target(folder), referent = folder.appendingPathComponent("referent.bin")
        try Data("unrelated referent".utf8).write(to: referent, options: .atomic)
        var opened = false
        XCTAssertThrowsError(try LocalFileCommit.fingerprint(url) { phase in
            if phase == .identified {
                try FileManager.default.removeItem(at: url)
                try FileManager.default.createSymbolicLink(at: url, withDestinationURL: referent)
            }
            if case .opened = phase { opened = true }
        }) { XCTAssertEqual($0 as? FileSinkError, .unsafeTarget) }
        XCTAssertFalse(opened)
        XCTAssertEqual(try Data(contentsOf: referent), Data("unrelated referent".utf8))
    }

    func testSameBytesPathReplacementAfterOpenIsRejected() throws {
        let folder = try folder("after-open"); defer { clean(folder) }
        let url = try target(folder), original = try LocalFileCommit.fingerprint(url)
        XCTAssertThrowsError(try LocalFileCommit.fingerprint(url) { phase in
            if case .opened = phase { try Data("abc".utf8).write(to: url, options: .atomic) }
        }) { XCTAssertEqual($0 as? FileSinkError, .targetChanged) }
        let current = try LocalFileCommit.fingerprint(url)
        XCTAssertNotEqual(current, original)
        try retain(["before": original, "after": current], in: folder)
    }

    func testInPlaceMutationDuringMultiBlockReadIsRejected() throws {
        let folder = try folder("in-place"); defer { clean(folder) }
        let url = try target(folder, bytes: Data(repeating: 0x41, count: 3 * 1024 * 1024))
        let original = try LocalFileCommit.fingerprint(url)
        var changed = false
        XCTAssertThrowsError(try LocalFileCommit.fingerprint(url) { phase in
            if phase == .chunkRead(0) {
                let writer = try FileHandle(forWritingTo: url); defer { try? writer.close() }
                try writer.write(contentsOf: Data(repeating: 0x42, count: 1024 * 1024))
                try writer.synchronize(); changed = true
            }
        }) { XCTAssertEqual($0 as? FileSinkError, .targetChanged) }
        XCTAssertTrue(changed)
        let current = try LocalFileCommit.fingerprint(url)
        XCTAssertNotEqual(current, original)
        XCTAssertEqual(try Data(contentsOf: url).prefix(4), Data("BBBB".utf8))
        try retain(["before": original, "after": current], in: folder)
    }

    func testTruncationAfterLastReadIsRejected() throws {
        let folder = try folder("truncated"); defer { clean(folder) }
        let url = try target(folder)
        XCTAssertThrowsError(try LocalFileCommit.fingerprint(url) { phase in
            if phase == .finishedRead {
                let writer = try FileHandle(forWritingTo: url); defer { try? writer.close() }
                try writer.truncate(atOffset: 1); try writer.synchronize()
            }
        }) { XCTAssertEqual($0 as? FileSinkError, .targetChanged) }
        XCTAssertEqual(try Data(contentsOf: url), Data("a".utf8))
    }

    func testDirectoriesSymlinksAndFIFOsAreRejectedBeforeReading() throws {
        let folder = try folder("non-regular"); defer { clean(folder) }
        let regular = try target(folder), linked = folder.appendingPathComponent("linked.bin")
        let fifo = folder.appendingPathComponent("fifo")
        try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: regular)
        XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
        for url in [folder, linked, fifo] {
            var opened = false
            XCTAssertThrowsError(try LocalFileCommit.fingerprint(url) { phase in
                if case .opened = phase { opened = true }
            }) { XCTAssertEqual($0 as? FileSinkError, .unsafeTarget) }
            XCTAssertFalse(opened)
        }
    }

    func testThrowingBoundaryClosesDescriptorAndPreservesSource() throws {
        let folder = try folder("close-on-error"); defer { clean(folder) }
        let url = try target(folder)
        var descriptor: Int32?
        XCTAssertThrowsError(try LocalFileCommit.fingerprint(url) { phase in
            if case .opened(let fd) = phase { descriptor = fd; throw CancellationError() }
        }) { XCTAssertTrue($0 is CancellationError) }
        let fd = try XCTUnwrap(descriptor)
        XCTAssertEqual(fcntl(fd, F_GETFD), -1); XCTAssertEqual(errno, EBADF)
        XCTAssertEqual(try Data(contentsOf: url), Data("abc".utf8))
    }

#if os(macOS)
    func testIndependentProcessReplacementBetweenIdentificationAndOpenIsRejected() throws {
        let folder = try folder("cross-process"); defer { clean(folder) }
        let url = try target(folder), original = try LocalFileCommit.fingerprint(url)
        let competitor = folder.appendingPathComponent("competitor.bin")
        try Data("abc".utf8).write(to: competitor, options: .atomic)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/mv")
        process.arguments = ["-f", competitor.path, url.path]
        XCTAssertThrowsError(try LocalFileCommit.fingerprint(url) { phase in
            if phase == .identified {
                try process.run(); process.waitUntilExit()
                XCTAssertEqual(process.terminationStatus, 0)
            }
        }) { XCTAssertEqual($0 as? FileSinkError, .targetChanged) }
        XCTAssertNotEqual(process.processIdentifier, ProcessInfo.processInfo.processIdentifier)
        XCTAssertGreaterThan(process.processIdentifier, 0)
        let current = try LocalFileCommit.fingerprint(url)
        XCTAssertNotEqual(current, original)
        XCTAssertEqual(try Data(contentsOf: url), Data("abc".utf8))
        try retain(["before": original, "after": current,
            "parentPID": String(ProcessInfo.processInfo.processIdentifier), "writerPID": String(process.processIdentifier),
            "writerExit": String(process.terminationStatus), "writerExecutable": "/bin/mv",
            "writerSource": competitor.path, "writerTarget": url.path], in: folder)
    }
#endif
}

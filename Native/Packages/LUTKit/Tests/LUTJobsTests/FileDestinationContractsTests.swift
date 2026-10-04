import Foundation
import XCTest
import LUTCore
import LUTFormats
@testable import LUTJobs

final class FileDestinationContractsTests: XCTestCase {
    func testNonDirectoryDestinationIsRejectedBeforeTemporaryCreation() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-destination-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let parentFile = root.appendingPathComponent("parent-file")
        try Data("not a directory".utf8).write(to: parentFile)
        let target = parentFile.appendingPathComponent("result.cube")
        let sink = FileCubeSink(target: target)

        do {
            try await sink.prepare(size: 2, domain: .unit, title: "destination")
            XCTFail("A regular file cannot be used as the destination directory")
        } catch FileSinkError.destinationUnavailable {
            let state = await sink.state
            XCTAssertEqual(state, .idle)
        }
        let entries = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertEqual(entries, [parentFile.lastPathComponent])
    }

    func testReadOnlyDestinationDirectoryIsRejectedBeforeTemporaryCreation() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-permission-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
            try? FileManager.default.removeItem(at: root)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: root.path)
        let target = root.appendingPathComponent("result.cube")
        let sink = FileCubeSink(target: target)

        do {
            try await sink.prepare(size: 2, domain: .unit, title: "permission")
            XCTFail("A read-only destination directory must be rejected")
        } catch FileSinkError.destinationPermissionDenied {
            let state = await sink.state
            XCTAssertEqual(state, .idle)
        }
    }
}

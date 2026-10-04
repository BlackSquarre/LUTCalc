import Foundation
import XCTest
@testable import LUTProject

final class ProjectAssetDiscoveryContractsTests: XCTestCase {
    func testCapturedIdentityRediscoversRenamedAssetByHash() throws {
        let root = try makeDirectory("asset-discovery")
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("chosen.cube")
        let bytes = Data("LUT_1D_SIZE 2\n0 0 0\n1 0.5 0.25\n".utf8)
        try bytes.write(to: original)

        let identity = try ProjectAssetSourceIdentity(
            assetPath: "Resources/user-00000000-0000-0000-0000-000000000001.cube",
            sourceURL: original)
        let moved = root.appendingPathComponent("renamed-reference.cube")
        try FileManager.default.moveItem(at: original, to: moved)

        let found = try ProjectAssetDiscovery.rediscover([identity], in: [root])
        XCTAssertEqual(found[identity.assetPath], moved.standardizedFileURL)
    }

    func testOriginalFilenameDisambiguatesEqualBytes() throws {
        let root = try makeDirectory("asset-discovery-name")
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = Data("same bytes".utf8)
        let preferred = root.appendingPathComponent("chosen.cube")
        let duplicate = root.appendingPathComponent("copy.cube")
        try bytes.write(to: preferred)
        try bytes.write(to: duplicate)

        let identity = try ProjectAssetSourceIdentity(
            assetPath: "Resources/reference.bin", sourceURL: preferred)
        let found = try ProjectAssetDiscovery.rediscover([identity], in: [root])
        XCTAssertEqual(found[identity.assetPath], preferred.standardizedFileURL)
    }

    func testAmbiguousHashWithoutOriginalNameFails() throws {
        let root = try makeDirectory("asset-discovery-ambiguous")
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = Data("same bytes".utf8)
        try bytes.write(to: root.appendingPathComponent("first.bin"))
        try bytes.write(to: root.appendingPathComponent("second.bin"))
        let identity = try ProjectAssetSourceIdentity(
            assetPath: "Resources/missing-name.bin",
            originalFilename: "does-not-exist.bin",
            sha256: ProjectAssets.sha256(of: bytes))

        XCTAssertThrowsError(try ProjectAssetDiscovery.rediscover([identity], in: [root])) { error in
            XCTAssertEqual(error as? ProjectAssetDiscoveryError,
                           .ambiguous(identity.assetPath, 2))
        }
    }

    func testMissingAndUnreadableSourcesAreExplicit() throws {
        let root = try makeDirectory("asset-discovery-missing")
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = try ProjectAssetSourceIdentity(
            assetPath: "Resources/missing.bin",
            originalFilename: "missing.bin",
            sha256: String(repeating: "a", count: 64))

        XCTAssertThrowsError(try ProjectAssetDiscovery.rediscover([identity], in: [root])) { error in
            XCTAssertEqual(error as? ProjectAssetDiscoveryError, .missing(identity.assetPath))
        }

        let file = root.appendingPathComponent("not-a-directory")
        try Data().write(to: file)
        XCTAssertThrowsError(try ProjectAssetDiscovery.rediscover([identity], in: [file])) { error in
            XCTAssertEqual(error as? ProjectAssetDiscoveryError, .invalidRoot(file.standardizedFileURL))
        }
    }

    func testSymlinkCandidatesAndRootsAreRejected() throws {
        let root = try makeDirectory("asset-discovery-symlink")
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("real.bin")
        let link = root.appendingPathComponent("link.bin")
        try Data("real".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let identity = try ProjectAssetSourceIdentity(
            assetPath: "Resources/real.bin", sourceURL: target)
        try FileManager.default.removeItem(at: target)
        XCTAssertThrowsError(try ProjectAssetDiscovery.rediscover([identity], in: [root])) { error in
            XCTAssertEqual(error as? ProjectAssetDiscoveryError, .missing(identity.assetPath))
        }
        XCTAssertThrowsError(try ProjectAssetDiscovery.rediscover([identity], in: [link])) { error in
            XCTAssertEqual(error as? ProjectAssetDiscoveryError, .invalidRoot(link.standardizedFileURL))
        }
    }

    func testDiscoveryDoesNotTraverseSymlinkedDirectoriesOutsideAuthorizedRoot() throws {
        let root = try makeDirectory("asset-discovery-symlink-directory-root")
        let outside = try makeDirectory("asset-discovery-symlink-directory-outside")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        let outsideFile = outside.appendingPathComponent("escaped.bin")
        try Data("outside".utf8).write(to: outsideFile)
        let linkedDirectory = root.appendingPathComponent("linked", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: linkedDirectory,
                                                   withDestinationURL: outside)

        let identity = try ProjectAssetSourceIdentity(assetPath: "Resources/escaped.bin",
                                                      sourceURL: outsideFile)
        XCTAssertThrowsError(try ProjectAssetDiscovery.rediscover([identity], in: [root])) { error in
            XCTAssertEqual(error as? ProjectAssetDiscoveryError,
                           .missing(identity.assetPath))
        }
    }

    func testDuplicateAssetPathsAndInvalidIdentityAreRejected() throws {
        let bytes = Data("bytes".utf8)
        let hash = ProjectAssets.sha256(of: bytes)
        let first = try ProjectAssetSourceIdentity(assetPath: "Resources/a.bin",
                                                   originalFilename: "a.bin", sha256: hash)
        let second = try ProjectAssetSourceIdentity(assetPath: "Resources/a.bin",
                                                    originalFilename: "b.bin", sha256: hash)
        XCTAssertThrowsError(try ProjectAssetDiscovery.rediscover([first, second], in: [])) { error in
            XCTAssertEqual(error as? ProjectAssetDiscoveryError, .duplicateAssetPath("Resources/a.bin"))
        }
        XCTAssertThrowsError(try ProjectAssetSourceIdentity(assetPath: "../a.bin",
                                                            originalFilename: "a.bin", sha256: hash))
    }

    private func makeDirectory(_ name: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        return root
    }
}

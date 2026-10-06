import Foundation
import XCTest
@testable import LUTProject

final class ProjectAssetRecoveryContractsTests: XCTestCase {
    func testBookmarkIsPreferredAndContentIsRevalidated() throws {
        let root = try makeDirectory("bookmark")
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("chosen.cube")
        try Data("stable".utf8).write(to: source)
        let identity = try ProjectAssetSourceIdentity(assetPath: "Resources/user.cube", sourceURL: source)
        let bookmark = try ProjectAssetSecurityBookmark(sourceURL: source)

        let result = try ProjectAssetRecovery.resolve(identity: identity, bookmark: bookmark,
                                                      authorizedRoots: [root])
        XCTAssertEqual(result.url, source.standardizedFileURL)
        XCTAssertEqual(result.source, .bookmark)
        XCTAssertFalse(result.wasStale)
        XCTAssertNotNil(result.renewedBookmark)
    }

    func testBookmarkedReplacementIsRejectedWithoutDiscoveryFallback() throws {
        let root = try makeDirectory("replacement")
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("chosen.cube")
        try Data("before".utf8).write(to: source)
        let identity = try ProjectAssetSourceIdentity(assetPath: "Resources/user.cube", sourceURL: source)
        let bookmark = try ProjectAssetSecurityBookmark(sourceURL: source)
        try Data("after".utf8).write(to: source)

        XCTAssertThrowsError(try ProjectAssetRecovery.resolve(identity: identity, bookmark: bookmark,
                                                              authorizedRoots: [root])) { error in
            XCTAssertEqual(error as? ProjectAssetRecoveryError,
                           .contentChanged(identity.assetPath))
        }
    }

    func testInvalidBookmarkFallsBackToAuthorizedHashDiscovery() throws {
        let root = try makeDirectory("fallback")
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("renamed.cube")
        try Data("fallback".utf8).write(to: source)
        let identity = try ProjectAssetSourceIdentity(assetPath: "Resources/user.cube",
                                                      sourceURL: source)
        let invalid = ProjectAssetSecurityBookmark(rawBookmarkData: Data([1, 2, 3]))

        let result = try ProjectAssetRecovery.resolve(identity: identity, bookmark: invalid,
                                                      authorizedRoots: [root])
        XCTAssertEqual(result.url, source.standardizedFileURL)
        XCTAssertEqual(result.source, .authorizedDiscovery)
        XCTAssertNil(result.renewedBookmark)
    }

    func testNoBookmarkOrAuthorizedRootFailsExplicitly() throws {
        let identity = try ProjectAssetSourceIdentity(assetPath: "Resources/user.cube",
                                                      originalFilename: "user.cube",
                                                      sha256: String(repeating: "a", count: 64))
        XCTAssertThrowsError(try ProjectAssetRecovery.resolve(identity: identity,
                                                              bookmark: nil,
                                                              authorizedRoots: [])) { error in
            XCTAssertEqual(error as? ProjectAssetRecoveryError, .noAuthorizedSource(identity.assetPath))
        }
    }

    func testRevokedBookmarkWithoutReauthorizationFailsClosed() throws {
        let identity = try ProjectAssetSourceIdentity(
            assetPath: "Resources/provider.cube",
            originalFilename: "provider.cube",
            sha256: String(repeating: "b", count: 64))
        let revoked = ProjectAssetSecurityBookmark(rawBookmarkData: Data([0xde, 0xad, 0xbe, 0xef]))

        XCTAssertThrowsError(try ProjectAssetRecovery.resolve(identity: identity,
                                                              bookmark: revoked,
                                                              authorizedRoots: [])) { error in
            XCTAssertEqual(error as? ProjectAssetRecoveryError,
                           .noAuthorizedSource(identity.assetPath))
        }
    }

    func testResolvedBookmarkUnreadableDoesNotFallBackToAnotherAuthorizedFile() throws {
        let sourceRoot = try makeDirectory("unreadable-bookmark-source")
        let authorizedRoot = try makeDirectory("unreadable-bookmark-authorized")
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o600],
                                                    ofItemAtPath: sourceRoot.appendingPathComponent("source.cube").path)
            try? FileManager.default.removeItem(at: sourceRoot)
            try? FileManager.default.removeItem(at: authorizedRoot)
        }
        let source = sourceRoot.appendingPathComponent("source.cube")
        let replacement = authorizedRoot.appendingPathComponent("same-bytes.cube")
        try Data("stable source".utf8).write(to: source)
        try Data("stable source".utf8).write(to: replacement)
        let identity = try ProjectAssetSourceIdentity(assetPath: "Resources/user.cube",
                                                      sourceURL: source)
        let bookmark = try ProjectAssetSecurityBookmark(sourceURL: source)
        try FileManager.default.setAttributes([.posixPermissions: 0o000],
                                              ofItemAtPath: source.path)

        XCTAssertThrowsError(try ProjectAssetRecovery.resolve(identity: identity,
                                                              bookmark: bookmark,
                                                              authorizedRoots: [authorizedRoot])) { error in
            XCTAssertEqual(error as? ProjectAssetRecoveryError,
                           .bookmarkSourceUnreadable(identity.assetPath))
        }
    }

    private func makeDirectory(_ name: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-recovery-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        return root
    }
}

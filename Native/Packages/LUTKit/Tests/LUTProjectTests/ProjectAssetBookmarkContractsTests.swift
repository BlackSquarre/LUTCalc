import Foundation
import XCTest
@testable import LUTProject

final class ProjectAssetBookmarkContractsTests: XCTestCase {
    func testApplePlatformsPreserveSecurityScopeInBookmarkPolicy() {
#if os(macOS)
        XCTAssertTrue(ProjectAssetSecurityBookmark.bookmarkCreationOptions
            .contains(.withSecurityScope))
        XCTAssertTrue(ProjectAssetSecurityBookmark.bookmarkResolutionOptions
            .contains(.withSecurityScope))
#endif
    }

    func testSecurityBookmarkRoundTripsAndReportsFreshResolution() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.cube")
        try Data("LUT_1D_SIZE 2\n0 0 0\n1 1 1\n".utf8).write(to: source)

        let bookmark = try ProjectAssetSecurityBookmark(sourceURL: source)
        let resolved = try bookmark.resolve()

        XCTAssertEqual(resolved.url, source.standardizedFileURL)
        XCTAssertFalse(resolved.isStale)

        let renewed = try bookmark.renewedIfStale()
        XCTAssertEqual(renewed, bookmark)
        XCTAssertEqual(try renewed.resolve().url, source.standardizedFileURL)
    }

    func testBookmarkRejectsDirectoryAndSymlinkSources() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try ProjectAssetSecurityBookmark(sourceURL: root)) { error in
            XCTAssertEqual(error as? ProjectAssetDiscoveryError,
                           .invalidSource(root.standardizedFileURL))
        }

        let source = root.appendingPathComponent("source.bin")
        let link = root.appendingPathComponent("link.bin")
        try Data("source".utf8).write(to: source)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        XCTAssertThrowsError(try ProjectAssetSecurityBookmark(sourceURL: link)) { error in
            XCTAssertEqual(error as? ProjectAssetDiscoveryError,
                           .invalidSource(link.standardizedFileURL))
        }
    }

    func testInvalidBookmarkBytesFailClosed() {
        let bookmark = ProjectAssetSecurityBookmark(rawBookmarkData: Data([0, 1, 2, 3]))
        XCTAssertThrowsError(try bookmark.resolve()) { error in
            XCTAssertEqual(error as? ProjectAssetDiscoveryError, .invalidBookmark)
        }
        XCTAssertThrowsError(try bookmark.renewedIfStale()) { error in
            XCTAssertEqual(error as? ProjectAssetDiscoveryError, .invalidBookmark)
        }
    }

    private func makeDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-bookmark-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        return root
    }
}

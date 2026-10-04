import Foundation
import XCTest
import LUTCore
import LUTCatalog
@testable import LUTProject

final class ProjectStoreReplacementContractsTests: XCTestCase {
    func testCoordinatedReplacementRejectsCompetitorAtPublishBoundary() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-project-race-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let original = try makeManifest(exposure: 0)
        let revised = try makeManifest(id: original.id, exposure: 1)
        let competitor = try makeManifest(id: original.id, exposure: 2)
        let target = root.appendingPathComponent("project.lutcalc", isDirectory: true)
        try ProjectStore.saveNew(original, at: target, catalog: catalog)

        let competitorURL = root.appendingPathComponent("competitor.lutcalc", isDirectory: true)
        try ProjectStore.saveNew(competitor, at: competitorURL, catalog: catalog)

        XCTAssertThrowsError(try ProjectStore.saveExistingForTesting(
            revised, replacing: original, at: target, catalog: catalog,
            beforeReplacement: {
                try FileManager.default.removeItem(at: target)
                try FileManager.default.moveItem(at: competitorURL, to: target)
            })) { error in
            XCTAssertEqual(error as? ProjectError, .concurrentModification)
        }

        XCTAssertEqual(try ProjectStore.open(at: target, catalog: catalog), competitor)
        XCTAssertFalse(FileManager.default.fileExists(atPath: competitorURL.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted(),
                       [target.lastPathComponent])
    }

    func testEqualBytesReplacementWithNewDirectoryIdentityIsRejected() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-project-identity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let original = try makeManifest(exposure: 0)
        let revised = try makeManifest(id: original.id, exposure: 1)
        let target = root.appendingPathComponent("project.lutcalc", isDirectory: true)
        try ProjectStore.saveNew(original, at: target, catalog: catalog)
        let replacement = root.appendingPathComponent("replacement.lutcalc", isDirectory: true)
        try ProjectStore.saveNew(original, at: replacement, catalog: catalog)

        XCTAssertThrowsError(try ProjectStore.saveExistingForTesting(
            revised, replacing: original, at: target, catalog: catalog,
            beforeReplacement: {
                try FileManager.default.removeItem(at: target)
                try FileManager.default.moveItem(at: replacement, to: target)
            })) { error in
            XCTAssertEqual(error as? ProjectError, .concurrentModification)
        }
        XCTAssertEqual(try ProjectStore.open(at: target, catalog: catalog), original)
    }

    private func makeManifest(id: UUID = UUID(), exposure: Double) throws -> ProjectManifest {
        let settings = TransformSettings(inputTransfer: .linearScene,
                                         outputTransfer: .linearScene,
                                         inputSpace: .srgb,
                                         outputSpace: .srgb,
                                         inputRange: .data,
                                         outputRange: .data,
                                         exposureStops: exposure)
        return ProjectManifest(id: id, settings: settings, cubeSize: 17, domain: .unit)
    }
}

import Foundation
import XCTest
import LUTCore
import LUTCatalog
@testable import LUTProject

final class ProjectStagingRecoveryContractsTests: XCTestCase {
    func testRecoveryRemovesOnlyOldNamedStagingDirectories() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-staging-recovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let stale = root.appendingPathComponent(".lutcalc-\(UUID().uuidString).staging", isDirectory: true)
        let fresh = root.appendingPathComponent(".lutcalc-\(UUID().uuidString).staging", isDirectory: true)
        let unrelated = root.appendingPathComponent(".lutcalc-old.tmp", isDirectory: true)
        try FileManager.default.createDirectory(at: stale, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: fresh, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: false)

        let now = Date(timeIntervalSince1970: 10_000)
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-7200)], ofItemAtPath: stale.path)
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-60)], ofItemAtPath: fresh.path)

        let removed = try ProjectStore.recoverOrphanedStaging(
            in: root, olderThan: 3600, now: now
        )
        XCTAssertEqual(removed.map { $0.lastPathComponent }, [stale.lastPathComponent])
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    }

    func testRecoveryRejectsNegativeAgeAndLeavesFreshEntries() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-staging-recovery-invalid-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(try ProjectStore.recoverOrphanedStaging(in: root, olderThan: -1)) { error in
            XCTAssertEqual(error as? ProjectError, .invalidPackage)
        }
    }

    func testBackupRecoveryUsesTheSameStrictAgeAndNamePolicy() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-backup-recovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let stale = root.appendingPathComponent(".lutcalc-\(UUID().uuidString).backup", isDirectory: true)
        let fresh = root.appendingPathComponent(".lutcalc-\(UUID().uuidString).backup", isDirectory: true)
        let unrelated = root.appendingPathComponent("project.backup", isDirectory: true)
        try FileManager.default.createDirectory(at: stale, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: fresh, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: false)

        let now = Date(timeIntervalSince1970: 20_000)
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-7200)], ofItemAtPath: stale.path)
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-60)], ofItemAtPath: fresh.path)

        let removed = try ProjectStore.recoverOrphanedBackups(in: root, olderThan: 3600, now: now)
        XCTAssertEqual(removed.map { $0.lastPathComponent }, [stale.lastPathComponent])
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    }

    func testTemporaryRecoveryRemovesOldDirectoriesAndFilesButPreservesFreshAndSymlinkEntries() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-temporary-recovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let staleDirectory = root.appendingPathComponent(".lutcalc-\(UUID().uuidString).tmp", isDirectory: true)
        let staleFile = root.appendingPathComponent(".lutcalc-\(UUID().uuidString).tmp")
        let freshFile = root.appendingPathComponent(".lutcalc-\(UUID().uuidString).tmp")
        let symlink = root.appendingPathComponent(".lutcalc-\(UUID().uuidString).tmp")
        try FileManager.default.createDirectory(at: staleDirectory, withIntermediateDirectories: false)
        try Data("stale".utf8).write(to: staleFile)
        try Data("fresh".utf8).write(to: freshFile)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: staleFile)

        let now = Date(timeIntervalSince1970: 30_000)
        for url in [staleDirectory, staleFile, symlink] {
            try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-7200)], ofItemAtPath: url.path)
        }
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-60)], ofItemAtPath: freshFile.path)

        let removed = try ProjectStore.recoverOrphanedTemporaryEntries(
            in: root, olderThan: 3600, now: now
        )
        XCTAssertEqual(Set(removed.map(\.lastPathComponent)), Set([staleDirectory.lastPathComponent, staleFile.lastPathComponent]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staleDirectory.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staleFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: freshFile.path))
        let symlinkValues = try symlink.resourceValues(forKeys: [.isSymbolicLinkKey])
        XCTAssertEqual(symlinkValues.isSymbolicLink, true)
    }

    func testTemporaryRecoveryRejectsInvalidAgeAndParent() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-temporary-recovery-invalid-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(try ProjectStore.recoverOrphanedTemporaryEntries(in: root, olderThan: -1)) { error in
            XCTAssertEqual(error as? ProjectError, .invalidPackage)
        }
        let file = root.appendingPathComponent("parent-file")
        try Data().write(to: file)
        XCTAssertThrowsError(try ProjectStore.recoverOrphanedTemporaryEntries(in: file, olderThan: 1)) { error in
            XCTAssertEqual(error as? ProjectError, .invalidPackage)
        }
    }

    func testOpeningProjectPerformsBestEffortSiblingRecovery() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-open-recovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let settings = TransformSettings(inputTransfer: .djiDLog2, outputTransfer: .linearScene,
                                         inputSpace: .djiDGamut2, outputSpace: .acesAP0,
                                         inputRange: .data, outputRange: .data, exposureStops: 0)
        let manifest = ProjectManifest(settings: settings, cubeSize: 17, domain: .unit)
        let package = root.appendingPathComponent("project.lutcalc", isDirectory: true)
        try ProjectStore.saveNew(manifest, at: package, catalog: catalog)

        let old = Date(timeIntervalSinceNow: -7200)
        let staleNames = [
            ".lutcalc-\(UUID().uuidString).staging",
            ".lutcalc-\(UUID().uuidString).backup",
            ".lutcalc-\(UUID().uuidString).tmp"
        ]
        let fresh = root.appendingPathComponent(".lutcalc-\(UUID().uuidString).tmp")
        for (index, name) in staleNames.enumerated() {
            let url = root.appendingPathComponent(name, isDirectory: index < 2)
            if index < 2 {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            } else {
                try Data("stale".utf8).write(to: url)
            }
            try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: url.path)
        }
        try Data("fresh".utf8).write(to: fresh)

        _ = try ProjectEditingSession(opening: package, catalog: catalog)
        for name in staleNames {
            XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(name).path))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path))
    }

    func testSavingNewProjectPerformsSiblingRecoveryBeforeCreatingTemporaryPackage() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-save-recovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let stale = root.appendingPathComponent(".lutcalc-\(UUID().uuidString).tmp")
        try Data("stale".utf8).write(to: stale)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -7200)], ofItemAtPath: stale.path)

        let settings = TransformSettings(inputTransfer: .djiDLog2, outputTransfer: .linearScene,
                                         inputSpace: .djiDGamut2, outputSpace: .acesAP0,
                                         inputRange: .data, outputRange: .data, exposureStops: 0)
        let package = root.appendingPathComponent("new-project.lutcalc", isDirectory: true)
        try ProjectStore.saveNew(ProjectManifest(settings: settings, cubeSize: 17, domain: .unit),
                                 at: package, catalog: catalog)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.path))
    }
}

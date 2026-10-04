import Foundation
import LUTCore
import LUTCatalog

public enum ProjectSessionError: Error, Equatable, Sendable {
    case unboundDocument
}

public struct ProjectEditingSession: Sendable {
    private struct Snapshot: Sendable {
        let manifest: ProjectManifest
        let encoded: Data
    }

    private let catalog: AlgorithmCatalog
    private var state: Snapshot
    private var saved: Snapshot?
    private var savedManifestBytes: Data?
    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []

    public private(set) var url: URL?
    public private(set) var revision: UInt64 = 0
    public var current: ProjectManifest { state.manifest }
    public var documentID: UUID { state.manifest.id }
    public var isDirty: Bool { state.encoded != saved?.encoded }
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public init(new manifest: ProjectManifest, catalog: AlgorithmCatalog) throws {
        self.catalog = catalog
        state = Snapshot(manifest: manifest, encoded: try ProjectCodec.encode(manifest, catalog: catalog))
    }

    public init(opening url: URL, catalog: AlgorithmCatalog) throws {
        let target = url.standardizedFileURL
        let parent = target.deletingLastPathComponent()
        // Recovery is deliberately best effort: an unavailable provider or a
        // symlinked parent must not change the normal project-open error.
        _ = try? ProjectStore.recoverOrphanedStaging(
            in: parent, olderThan: ProjectStore.defaultOrphanRecoveryAge)
        _ = try? ProjectStore.recoverOrphanedBackups(
            in: parent, olderThan: ProjectStore.defaultOrphanRecoveryAge)
        _ = try? ProjectStore.recoverOrphanedTemporaryEntries(
            in: parent, olderThan: ProjectStore.defaultOrphanRecoveryAge)
        let manifest = try ProjectStore.open(at: target, catalog: catalog)
        let raw = try Data(contentsOf: target.appendingPathComponent("manifest.json"))
        let snapshot = Snapshot(manifest: manifest, encoded: try ProjectCodec.encode(manifest, catalog: catalog))
        self.catalog = catalog
        state = snapshot
        saved = snapshot
        savedManifestBytes = raw
        self.url = target
    }

    public mutating func apply(_ manifest: ProjectManifest) throws {
        guard manifest.id == documentID else { throw ProjectError.projectIdentityMismatch }
        let next = Snapshot(manifest: manifest, encoded: try ProjectCodec.encode(manifest, catalog: catalog))
        guard next.encoded != state.encoded else { return }
        undoStack.append(state)
        state = next
        redoStack.removeAll()
        revision &+= 1
    }

    public mutating func replaceForAssetChange(_ manifest: ProjectManifest) throws {
        guard manifest.id == documentID else { throw ProjectError.projectIdentityMismatch }
        state = Snapshot(manifest: manifest, encoded: try ProjectCodec.encode(manifest, catalog: catalog))
        undoStack.removeAll()
        redoStack.removeAll()
        revision &+= 1
    }

    @discardableResult
    public mutating func undo() -> Bool {
        guard let previous = undoStack.popLast() else { return false }
        redoStack.append(state)
        state = previous
        revision &+= 1
        return true
    }

    @discardableResult
    public mutating func redo() -> Bool {
        guard let next = redoStack.popLast() else { return false }
        undoStack.append(state)
        state = next
        revision &+= 1
        return true
    }

    public mutating func save(assetSources: [String: URL] = [:]) throws {
        guard let url else { throw ProjectSessionError.unboundDocument }
        try save(to: url, assetSources: assetSources)
    }

    public mutating func save(to url: URL, assetSources: [String: URL] = [:]) throws {
        let target = url.standardizedFileURL
        if target == self.url {
            guard let saved, let savedManifestBytes else { throw ProjectSessionError.unboundDocument }
            try ProjectStore.saveExisting(state.manifest, replacing: saved.manifest, at: target,
                                          catalog: catalog, assetSources: assetSources,
                                          expectedManifestBytes: savedManifestBytes)
        } else {
            var sources = assetSources
            if let previousURL = self.url, let saved {
                for (path, hash) in state.manifest.assetHashes where sources[path] == nil {
                    if saved.manifest.assetHashes[path] == hash {
                        sources[path] = previousURL.appendingPathComponent(path)
                    }
                }
            }
            try ProjectStore.saveNew(state.manifest, at: target, catalog: catalog, assetSources: sources)
        }
        let readback = try ProjectStore.open(at: target, catalog: catalog)
        let readbackEncoded = try ProjectCodec.encode(readback, catalog: catalog)
        guard readbackEncoded == state.encoded else { throw ProjectError.invalidPackage }
        savedManifestBytes = try Data(contentsOf: target.appendingPathComponent("manifest.json"))
        saved = state
        self.url = target
    }
}

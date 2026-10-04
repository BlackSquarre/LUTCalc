import Foundation

/// The source used to reconnect a user asset after a document or provider
/// lifecycle boundary.
public enum ProjectAssetRecoverySource: String, Codable, Equatable, Sendable {
    case bookmark
    case authorizedDiscovery
}

public struct ProjectAssetRecoveryResult: Sendable {
    public let url: URL
    public let source: ProjectAssetRecoverySource
    public let wasStale: Bool
    public let renewedBookmark: ProjectAssetSecurityBookmark?

    public init(url: URL, source: ProjectAssetRecoverySource, wasStale: Bool,
                renewedBookmark: ProjectAssetSecurityBookmark?) {
        self.url = url
        self.source = source
        self.wasStale = wasStale
        self.renewedBookmark = renewedBookmark
    }
}

public enum ProjectAssetRecoveryError: Error, Equatable, Sendable {
    case noAuthorizedSource(String)
    case contentChanged(String)
    case bookmarkSourceUnreadable(String)
    case discoveryFailed(ProjectAssetDiscoveryError)
}

/// Reconnects an external user asset without guessing across a replacement.
///
/// A bookmark is authoritative when it resolves and its bytes still match the
/// captured identity. If the bookmark cannot be resolved, already-authorized
/// roots may be searched by hash and original filename. A resolved bookmark
/// whose bytes changed is rejected instead of silently falling back to another
/// file, which keeps an external replacement visible to the caller.
public enum ProjectAssetRecovery {
    public static func resolve(
        identity: ProjectAssetSourceIdentity,
        bookmark: ProjectAssetSecurityBookmark? = nil,
        authorizedRoots: [URL] = []
    ) throws -> ProjectAssetRecoveryResult {
        if let bookmark {
            do {
                let resolved = try bookmark.resolve()
                let actualHash: String
                do {
                    actualHash = try ProjectAssets.sha256(of: resolved.url)
                } catch {
                    throw ProjectAssetRecoveryError.bookmarkSourceUnreadable(identity.assetPath)
                }
                guard actualHash == identity.sha256 else {
                    throw ProjectAssetRecoveryError.contentChanged(identity.assetPath)
                }
                do {
                    let renewed = try bookmark.renewedIfStale()
                    return ProjectAssetRecoveryResult(url: resolved.url,
                                                      source: .bookmark,
                                                      wasStale: resolved.isStale,
                                                      renewedBookmark: renewed)
                } catch {
                    return try discover(identity: identity, roots: authorizedRoots)
                }
            } catch let error as ProjectAssetRecoveryError {
                throw error
            } catch {
                // A revoked or stale bookmark may still be recoverable from
                // roots the caller has explicitly authorized for rediscovery.
            }
        }
        return try discover(identity: identity, roots: authorizedRoots)
    }

    private static func discover(identity: ProjectAssetSourceIdentity,
                                 roots: [URL]) throws -> ProjectAssetRecoveryResult {
        guard !roots.isEmpty else {
            throw ProjectAssetRecoveryError.noAuthorizedSource(identity.assetPath)
        }
        do {
            guard let url = try ProjectAssetDiscovery.rediscover([identity], in: roots)[identity.assetPath]
            else { throw ProjectAssetRecoveryError.noAuthorizedSource(identity.assetPath) }
            return ProjectAssetRecoveryResult(url: url,
                                              source: .authorizedDiscovery,
                                              wasStale: false,
                                              renewedBookmark: nil)
        } catch let error as ProjectAssetRecoveryError {
            throw error
        } catch let error as ProjectAssetDiscoveryError {
            throw ProjectAssetRecoveryError.discoveryFailed(error)
        }
    }
}

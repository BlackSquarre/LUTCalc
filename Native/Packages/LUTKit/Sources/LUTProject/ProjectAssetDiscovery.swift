import Foundation

/// A source identity kept outside the portable `.lutcalc` package.
///
/// The package still owns the self-contained asset bytes. This value is an
/// ephemeral locator for a caller that wants to reconnect the original file;
/// it deliberately does not contain a security bookmark or a provider token.
public struct ProjectAssetSourceIdentity: Codable, Equatable, Hashable, Sendable {
    public let assetPath: String
    public let originalFilename: String
    public let sha256: String

    public init(assetPath: String, originalFilename: String, sha256: String) throws {
        try ProjectAssets.validate(path: assetPath, hash: sha256)
        guard !originalFilename.isEmpty,
              originalFilename != ".", originalFilename != "..",
              !originalFilename.contains("/"), !originalFilename.contains("\\"),
              !originalFilename.contains("\0") else {
            throw ProjectAssetDiscoveryError.invalidIdentity(assetPath)
        }
        self.assetPath = assetPath
        self.originalFilename = originalFilename
        self.sha256 = sha256
    }

    public init(assetPath: String, sourceURL: URL) throws {
        let url = sourceURL.standardizedFileURL
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw ProjectAssetDiscoveryError.invalidSource(url)
        }
        try self.init(assetPath: assetPath,
                      originalFilename: url.lastPathComponent,
                      sha256: try ProjectAssets.sha256(of: url))
    }
}

public enum ProjectAssetDiscoveryError: Error, Equatable, Sendable {
    case invalidIdentity(String)
    case invalidSource(URL)
    case invalidBookmark
    case invalidRoot(URL)
    case duplicateAssetPath(String)
    case missing(String)
    case ambiguous(String, Int)
    case unreadable(URL)
}

/// A security-scoped bookmark for a user-selected source file.
///
/// The bookmark is deliberately kept separate from `ProjectAssetSourceIdentity`:
/// portable project packages continue to contain self-contained bytes, while a
/// caller may persist this opaque authorization outside the package when the
/// user explicitly grants access. Resolution reports staleness so the caller
/// can replace the bookmark after the URL has been renewed.
public struct ProjectAssetSecurityBookmark: Codable, Equatable, Hashable, Sendable {
    private let data: Data

#if os(macOS)
    /// macOS security-scoped URLs must carry the scope through both bookmark
    /// creation and resolution. iOS does not expose this option in its SDK;
    /// document-provider access is held by the document URL itself.
    static let bookmarkCreationOptions: URL.BookmarkCreationOptions = [.withSecurityScope]
    static let bookmarkResolutionOptions: URL.BookmarkResolutionOptions = [.withSecurityScope]
#endif

    public init(sourceURL: URL) throws {
        let url = sourceURL.standardizedFileURL
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw ProjectAssetDiscoveryError.invalidSource(url)
        }
#if os(macOS) || os(iOS)
        do {
            let options: URL.BookmarkCreationOptions = {
#if os(macOS)
                return Self.bookmarkCreationOptions
#else
                return []
#endif
            }()
            data = try url.bookmarkData(options: options,
                                        includingResourceValuesForKeys: nil,
                                        relativeTo: nil)
        } catch {
            throw ProjectAssetDiscoveryError.invalidBookmark
        }
#else
        throw ProjectAssetDiscoveryError.invalidBookmark
#endif
    }

    public init(rawBookmarkData: Data) {
        self.data = rawBookmarkData
    }

    public var rawBookmarkData: Data { data }

    public func resolve() throws -> ProjectAssetResolvedSource {
#if os(macOS) || os(iOS)
        var stale = false
        let url: URL
        do {
            let options: URL.BookmarkResolutionOptions = {
#if os(macOS)
                return Self.bookmarkResolutionOptions
#else
                return []
#endif
            }()
            url = try URL(resolvingBookmarkData: data,
                          options: options,
                          relativeTo: nil,
                          bookmarkDataIsStale: &stale)
        } catch {
            throw ProjectAssetDiscoveryError.invalidBookmark
        }
        let standardized = url.standardizedFileURL
        let values = try standardized.resourceValues(forKeys: [.isRegularFileKey,
                                                                 .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw ProjectAssetDiscoveryError.invalidSource(standardized)
        }
        return ProjectAssetResolvedSource(url: standardized, isStale: stale)
#else
        throw ProjectAssetDiscoveryError.invalidBookmark
#endif
    }

    /// 解析并在系统报告 stale 时重新生成安全书签。
    ///
    /// 新书签只从解析后的 regular file URL 生成；非法数据、目录和符号链接
    /// 继续 fail closed。当前书签未 stale 时直接保留原始字节，避免无意义的
    /// 重编码。调用方仍须在需要访问文件时自行管理 security-scoped access。
    public func renewedIfStale() throws -> ProjectAssetSecurityBookmark {
        let resolved = try resolve()
        guard resolved.isStale else { return self }
        return try ProjectAssetSecurityBookmark(sourceURL: resolved.url)
    }
}

public struct ProjectAssetResolvedSource: Equatable, Hashable, Sendable {
    public let url: URL
    public let isStale: Bool

    public init(url: URL, isStale: Bool) {
        self.url = url
        self.isStale = isStale
    }
}

/// Deterministic local source rediscovery for user-provided assets.
///
/// The caller supplies already authorized directories. Matching is by the
/// captured SHA-256; an exact original filename is used only to disambiguate
/// equal-byte candidates. Any remaining ambiguity or missing asset is an
/// explicit error rather than a guess.
public enum ProjectAssetDiscovery {
    public static func rediscover(
        _ identities: [ProjectAssetSourceIdentity],
        in roots: [URL]
    ) throws -> [String: URL] {
        var seen = Set<String>()
        for identity in identities {
            guard seen.insert(identity.assetPath).inserted else {
                throw ProjectAssetDiscoveryError.duplicateAssetPath(identity.assetPath)
            }
        }

        let normalizedRoots = try roots.map { root -> URL in
            let url = root.standardizedFileURL
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                throw ProjectAssetDiscoveryError.invalidRoot(url)
            }
            return url
        }

        var files: [URL] = []
        var seenURLs = Set<URL>()
        for root in normalizedRoots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey,
                                             .isSymbolicLinkKey],
                options: []
            ) else {
                throw ProjectAssetDiscoveryError.invalidRoot(root)
            }
            for case let candidate as URL in enumerator {
                let url = candidate.standardizedFileURL
                guard seenURLs.insert(url).inserted else { continue }
                let values: URLResourceValues
                do {
                    values = try url.resourceValues(forKeys: [.isDirectoryKey,
                                                              .isRegularFileKey,
                                                              .isSymbolicLinkKey])
                } catch {
                    throw ProjectAssetDiscoveryError.unreadable(url)
                }
                guard values.isSymbolicLink != true,
                      !Self.pathContainsSymbolicLink(from: root, to: url),
                      values.isRegularFile == true else {
                    continue
                }
                files.append(url)
            }
        }

        var hashes: [URL: String] = [:]
        for file in files {
            do {
                hashes[file] = try ProjectAssets.sha256(of: file)
            } catch {
                throw ProjectAssetDiscoveryError.unreadable(file)
            }
        }

        var result: [String: URL] = [:]
        for identity in identities {
            let matches = files.filter { hashes[$0] == identity.sha256 }
            guard !matches.isEmpty else {
                throw ProjectAssetDiscoveryError.missing(identity.assetPath)
            }
            let named = matches.filter { $0.lastPathComponent == identity.originalFilename }
            let selected: URL
            if named.count == 1 {
                selected = named[0]
            } else if matches.count == 1 {
                selected = matches[0]
            } else {
                throw ProjectAssetDiscoveryError.ambiguous(identity.assetPath, matches.count)
            }
            result[identity.assetPath] = selected
        }
        return result
    }

    /// Checks lexical components below an already validated root. System
    /// paths such as `/var` may themselves be compatibility symlinks, so only
    /// components inside the caller's explicit authorization are inspected.
    private static func pathContainsSymbolicLink(from root: URL, to url: URL) -> Bool {
        let root = root.standardizedFileURL
        let candidate = url.standardizedFileURL
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path.hasPrefix(rootPath) else { return true }
        let relativeComponents = candidate.path
            .dropFirst(rootPath.count)
            .split(separator: "/", omittingEmptySubsequences: true)
        var current = root
        for component in relativeComponents {
            current.appendPathComponent(String(component))
            guard let values = try? current.resourceValues(forKeys: [.isSymbolicLinkKey]) else {
                continue
            }
            if values.isSymbolicLink == true {
                return true
            }
        }
        return false
    }
}

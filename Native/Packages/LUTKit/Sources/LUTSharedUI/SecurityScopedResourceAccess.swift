import Foundation

/// 平台文件选择器返回的 URL 可能需要 security-scoped 授权。
/// 通过小型同步访问器隔离系统 API，便于验证成功、失败和取消路径的成对释放。
public protocol SecurityScopedResourceAccessing: Sendable {
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}

public struct NativeSecurityScopedResourceAccess: SecurityScopedResourceAccessing, Sendable {
    public init() {}

    public func startAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    public func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

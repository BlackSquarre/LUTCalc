# 2026-10-04 安全书签平台策略验收

## 范围

本轮只核对用户资源安全书签在 macOS 与 iOS SDK 中的可用 API 分支，不宣称已经完成 iCloud/File Provider 授权失效或真实恢复验收。

## 契约与结果

- 先行契约新增并通过：macOS 的安全书签创建和解析策略必须包含 `.withSecurityScope`；非法书签、目录和符号链接仍 fail closed。
- `swift test --package-path Native/Packages/LUTKit --filter ProjectAssetBookmarkContractsTests`：4 项通过。
- 首次尝试在 iOS 共用 `.withSecurityScope`，Xcode 27/iOS SDK 27 明确报告该选项在 iOS 不可用；失败日志保留在 `artifacts/2026-10-04-ios-security-scope/build.log`，未把它当作通过。
- 按 SDK 能力恢复平台分支：macOS 使用 `.withSecurityScope`，iOS 使用系统提供的 bookmark 选项；iOS generic Release 构建退出码 `0`，日志和退出码见 `artifacts/2026-10-04-ios-security-scope/build-v2.log` 与 `build-v2.exit`。
- macOS generic Release 构建退出码 `0`，完整 Swift Package Release 回归退出码 `0`；回归日志为 `full-swift-release.log`，其中 `LUTCoreTests` 183 项、`LUTCatalogTests` 24 项、`LUTAnalysisTests` 32 项均为 0 失败，其他包结果同样保存在原始日志中。
- 源码 SHA-256：`ProjectAssetDiscovery.swift` 为 `576e42fedd819b39965f938d1a8cac8a2485eefeb2f58cdb7298e297729f94a2`；书签契约为 `f52fe3bd1b683d4d431f666776e8ac070c0804e8ff5685a0edf24b878f465cf4`。

## 未覆盖范围

- 没有真实 iCloud/File Provider URL、授权撤销、重新授权、外部替换或后台终止后的设备证据。
- 本轮确认了 API 平台边界，但没有把 iOS bookmark 解析等同于持久授权成功；仍需在真实文稿提供商场景中验证。

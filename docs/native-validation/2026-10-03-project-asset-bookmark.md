# 项目来源安全书签与并发错误定位非 UI 阶段验收

日期：2026-10-03

## 范围

本轮在上一阶段本地来源哈希重发现的基础上，补充 `ProjectAssetSecurityBookmark`。它把用户主动选择的 regular file 转为 Foundation bookmark data，并在解析时报告 `isStale`；无效字节、目录、符号链接和解析后不再是 regular file 的结果均显式拒绝。书签仍独立于可携带的 `.lutcalc` 包，不把外部授权凭据写入项目包。

macOS 使用 Foundation 的 `.withSecurityScope`；iOS SDK 将该选项标记为 unavailable，因此 iOS 使用普通 bookmark data，仍由调用方负责在 Files/File Provider URL 上管理访问生命周期。该差异是 Apple API 约束，不能当作真实 provider 授权撤销已验收。

本轮还修复了 `GenerationCoordinator` 的并发错误定位：多个 worker 同时失败时，收集带 block index 的错误并选择最早 block，再向上返回原始 `PlanError`。这样不会因 worker 完成顺序改变 stage 9 的 `sampleIndex`。

## 契约与实现

先添加 3 项 `ProjectAssetBookmarkContractsTests`，红灯阶段确认接口和 `.invalidBookmark` 尚不存在。实现后覆盖：

- bookmark 创建、解析和新鲜度报告；
- 目录与符号链接来源拒绝；
- 任意 bookmark 字节 fail closed。

完整 Release 回归第一次暴露既有多音调并发测试的非确定错误位置（得到 `sampleIndex = 4096`，契约期望 0）。两个单独的 `MultitoneDocumentContractsTests` Release 重跑均通过，随后以最早 block 错误收集修复并再次验证定向与全量。

## 实际验证

工具链：Xcode 27、Swift 6（swift-driver 1.168.6）、macOS 27 SDK、Apple Silicon arm64。完整命令、源码哈希和结果包见 [artifact 目录](artifacts/2026-10-03-project-asset-bookmark/)。

最终结果：

- Debug 定向 3 项、Release 定向 3 项，0 失败；
- Release 全量 8 个测试包共执行 600 项，0 失败；LUTFormats 既有 `.labin` 与 NCP 外部夹具各 1 项按设计跳过；
- macOS、iOS generic、iOS Simulator generic Release 构建退出码均为 0；
- 源码审计通过，146 个 Swift 源文件无所列禁止运行时或内置查找资产；
- 三个 App 包审计通过，无所列 LUT/脚本文件且未直接链接 WebKit/JavaScriptCore；
- 构建日志中的 CoreSimulator 服务初始化警告来自当前主机资源环境，generic simulator 构建仍成功，不能替代 iPad 交互证据。

最终日志 SHA-256：

```text
契约红灯       a4c3cce581ed6025a7eb6175c53c277083ef22b24500afb84852e5c7dd98d5f9
Debug 定向      c56472e3ff22292017426afaa864b5f5dba42a4140cdb424e5cb9e64986af387
Release 定向    e04545e5925c4d9b3899ca938d879c74af7c6d914d25243442d494e67c6d43fe
Release 全量    4257f94f5ca7ea666bfd18a4a0816963de046f859e6a1bbaac175e9015501922
macOS 构建      ebbec3f27df0e11c8901b68b2c9ae7982717d294e63025a7777cdced196cf974
iOS 构建        bd73eb0acb5fec3eed9f2c65fb05f87c3975dd664e78980293116af0601cb3b5
模拟器构建      5e669182563240fefdd92900e37e00d933d31ed0bb24fdf0e9205cf7786550cf
源码审计        d3be41b866152b5840b67fbe667a6371e677fa390a20ee58f96d4f1c07fe63e2
App 包审计      5cf8f49359d02d2b03d3b23d7fcc0f25b68815ca27754ee29b15de8522a24d2f
```

## 未覆盖范围

书签契约没有证明真实 iCloud/File Provider 的授权撤销、跨进程 provider 行为、stale bookmark 在系统替换后的续期策略、目标替换竞争、磁盘故障、后台自动恢复或实体 iPhone 11 行为；iOS 的 Files 交互和 security-scoped 生命周期仍待真实平台验收。Finder、Files、iPad 多窗口、旋转、无障碍和其他 UI 按要求暂缓。

完整 ICC、HDR/EDR/OOTF、LUTAnalyst、全部格式与目标软件互操作、性能预算、签名发布和真实 `full-scope-acceptance.json` 仍未完成；Goal 保持 active。


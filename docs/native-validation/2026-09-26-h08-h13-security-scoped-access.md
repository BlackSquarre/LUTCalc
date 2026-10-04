# H08/H13 security-scoped 文件访问阶段验收

日期：2026-09-26

## 范围

本阶段把系统文件选择器返回的 URL 访问边界抽成共享 Swift `SecurityScopedResourceAccessing` 契约，并接入用户 LUT 与图像加载器。加载任务仍在 detached Swift task 中执行；授权成功时在读取或解码结束、解析失败和读取失败路径执行成对释放。授权未获得时不调用 stop，符合 `startAccessingSecurityScopedResource()` 的返回语义。

同时，原生 SwiftUI 文件选择器和导出器将 `NSUserCancelledError` 视为用户取消，不把取消显示成失败；其他错误仍保留给当前文档显示。该改动只修正状态呈现，不改变导出提交边界。

## 修改文件

- `Native/Packages/LUTKit/Sources/LUTSharedUI/SecurityScopedResourceAccess.swift`
- `Native/Packages/LUTKit/Sources/LUTSharedUI/UserLUTImportSession.swift`
- `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectSampleSession.swift`
- `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift`
- `Native/Packages/LUTKit/Tests/LUTSharedUITests/SecurityScopedLoaderContractsTests.swift`

## 先失败后通过的契约

新增 4 项 `SecurityScopedLoaderContractsTests`：

1. 用户 LUT 成功读取后 start/stop 各一次；
2. LUT 解析失败后仍 stop 一次；
3. 图像解码失败后仍 stop 一次；
4. 本地 URL 返回未获得授权时不调用 stop。

测试使用注入的记录访问器，不把本地文件系统行为当成 Files/File Provider 真机证据。

## 实际验证

工具链：Xcode 27.0、Swift 6.4、macOS SDK 27.0、iOS SDK 27.0。

### Swift Release

```text
swift test --package-path Native/Packages/LUTKit -c release --filter SecurityScopedLoaderContractsTests
```

结果：4 项通过，0 失败。

```text
swift test --package-path Native/Packages/LUTKit -c release
```

结果：退出码 0；测试清单 281 项，2 项既有公开 NCP 实样按设计跳过，其余通过。日志：`/tmp/lutcalc-security-scoped-swift-release-20260926.log`，SHA-256：`a88a00035ba2e2811eab0e7a46a2592b4a5d21735488d99bc74a06b227dcd3`。

### 原生发布入口

```text
bash tools/native-validation/verify-native-release.sh
```

结果：公式检查、CUBE 生成/独立读回、Swift Release、macOS Release、iOS Simulator Release、iOS generic Release、3 个 App 包资源审计均通过。脚本退出码 2，唯一直接失败是缺少真实的 `docs/native-validation/full-scope-acceptance.json`；未创建或伪造该清单。日志：`/tmp/lutcalc-security-scoped-native-release-20260926.log`，SHA-256：`2de9d57b5f1e88a181549bb04d1d088b58778ebb6084259e26a40d1e3cceb2e2`。

## 未覆盖范围

- 尚未取得 iPhone/iPad 真机上 Files、File Provider、security-scoped bookmark 失效、授权撤销、取消和替换竞争的完整交互证据；
- 尚未完成 iPad 多窗口、旋转、后台挂起/终止恢复和跨设备性能/内存/取消预算；
- 该阶段不改变完整 H08/H13、FULL-05/FULL-06、发布清单或 Goal 状态，Goal 继续保持 active。

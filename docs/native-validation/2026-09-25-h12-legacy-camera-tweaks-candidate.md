# H12 旧设置相机与调节开关候选阶段验收

日期：2026-09-25

## 范围

本阶段继续保持旧 `.lutcalc` 文件只读检查。针对旧 `js/lutcamerabox.js:getSettings` 和 `js/luttweaksbox.js:getSettings` 的共同结构，批量核对相机 stop correction 与调节总开关这两个可独立判定的字段。相机厂商/型号只是旧版预设身份，原生相机目录尚未冻结；各调节子项包含旧算法专用参数，原生等价链尚未证明，因此均不宣称迁移。

## 契约先行

先在 `LegacySettingsContractsTests` 增加 2 项契约：

- 其 `2^shift` 仍为有限正数的 JSON 数值 `cameraBox.shift` 报告为只读 `exposureStops` 候选，严格布尔 `tweaksBox.tweaks` 报告为只读启用状态；相机 `make`/`model` 与子调节字段继续列为未映射。
- 字符串/布尔混用的 stop correction 或调节开关拒绝映射，并保留在 `unmappedPaths`。

首次运行因 `LegacyMappedSettings` 尚无新候选字段而按预期编译失败。实现后使用 Release 定向测试复核。

## 实现边界

`LegacyMappedSettings` 新增两个候选字段：

- `exposureStops`：仅接受 `cameraBox.shift` 且 `2^shift` 为有限正数；不映射 `make`、`model`。
- `tweaksEnabled`：仅接受 `tweaksBox.tweaks` 的真正 JSON 布尔；不映射 `tweaksBox` 下的任何子算法参数。

候选只进入报告，不创建 `ProjectManifest`，不改变计算或导出行为，`canMigrate` 固定为 `false`。未知版本、缺失分区、格式方言与版本迁移规则保持原有严格边界。

## 验证

命令：

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Native/Packages/LUTKit -c release --filter LegacySettingsContractsTests
```

结果：`LegacySettingsContractsTests` **16 项通过，0 失败**。覆盖新相机/调节批量案例，以及既有版本、legal、网格、域、数值、曲线/色域、格式和重复键契约。

随后执行集中批量 Release 回归：`swift test --list-tests` 为 **165 项**；Swift Release XCTest、旧 Node/Python 契约、macOS/iOS Simulator/iOS generic Release 构建及 3 个 App 包资源审计均通过。完整日志为 `/tmp/lutcalc-h12-camera-tweaks-batched-release-20260925.log`，SHA-256 为 `3580b644ea28fb5babfa35537b9096a6bcc6d8d58822c972d798d186fe772419`。发布证据检查退出码 2，唯一直接原因仍是缺少真实 `docs/native-validation/full-scope-acceptance.json`。

源码 SHA-256：

- `Native/Packages/LUTKit/Sources/LUTProject/LegacySettingsInspector.swift`：`845bdd8cef425f30800ea558843a19d8df7ababb79dfa36c8791444ee52b7c40`
- `Native/Packages/LUTKit/Tests/LUTProjectTests/LegacySettingsContractsTests.swift`：`01474b3da43e85444ad2e924d40f42c438003317dc309cae9fb33e5f5906c521`

## 未完成项

本阶段不代表 H12 或 FULL-08 完成。相机预设目录、全部调节算法逐项等价、旧格式方言/版本迁移、原生项目创建、真机和发布门槛仍需后续独立验收。

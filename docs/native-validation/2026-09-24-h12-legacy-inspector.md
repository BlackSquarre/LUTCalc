# H12 旧设置只读识别阶段验收

日期：2026-09-24。状态：只读识别阶段通过；旧设置导入和 H12/APP-04/FULL-08 均未完成。

## 契约与实现

旧版 `js/lutmessage.js:getSettings` 生成单文件 JSON。实际散装入口 `js/splash.js` 使用 `v4.10`，手工镜像的 `js/lutcalccombined.js` 使用 `v4.09`。它们都与原生目录包共用 `.lutcalc` 扩展名。先写契约，要求报告版本、六个已知分区、缺失分区、未知顶层字段、尚未映射的字段路径和源文件 SHA-256，且绝不宣称可转换；还要拒绝目录包、畸形 JSON、符号链接与超限文件。契约首次编译因 `LegacySettingsInspector` 缺失而失败。

新增纯 Swift、只读的 `LegacySettingsInspector`。它只接受普通文件，读取上限 8 MiB，遍历深度与节点数有上限；识别版本标签 `v4.09`/`v4.10`，其他版本仅报告不接受迁移。当前所有设置字段均列为未映射，`canMigrate` 固定为 `false`。检查过程中不改旧文件、不创建原生项目，也不把旧资产放入 App。

## 修改文件、资料与源码版本

| 文件 | 用途 | SHA-256 |
| --- | --- | --- |
| `Native/Packages/LUTKit/Sources/LUTProject/LegacySettingsInspector.swift` | 只读识别与字段报告 | `177bcc3a2690006411f41b0b7ed513bdd923f88e78481f36d7a3c7ed2b359656` |
| `Native/Packages/LUTKit/Sources/LUTProjectSessionChecks/main.swift` | 版本、字段、拒绝路径契约 | `e1ad84146e61746629faf77e66423aeadb2110def5781763b90074c86ddd52c5` |
| `js/splash.js` | 散装入口版本来源，只读 | `7784eb14159f8a3805db8380509923df64231ffb68ded07dee529c995369e833` |
| `js/lutcalccombined.js` | 镜像入口版本来源，只读 | `75dabaed379417d7e2edd30dd3c6dd942b60a022d8b05f74a74787d0e6726b74` |
| `js/lutmessage.js` | JSON 结构来源，只读 | `bd712784c1aee8990aaeabbf4324f9df0fc3b2d9f5aa5e34e7bcf6447caf0a8c` |

## 实际验证

- 工具链：Apple Swift 6.2.1，arm64 Command Line Tools；无完整 Xcode/iOS SDK。
- `swift build --package-path Native/Packages/LUTKit --product LUTProjectSessionChecks` 在契约先行时退出码 1，缺少检查器类型；实现后 `swift run --package-path Native/Packages/LUTKit LUTProjectSessionChecks` 退出码 0。
- `tools/native-validation/verify-native-subset.sh > /tmp/lutcalc-h12-legacy-inspector-20260924.log 2>&1` 退出码 0。静态边界覆盖 40 个 Swift 源文件，旧 Node 测试 9/9 通过；新增检查器及既有 Release 子集契约通过。本阶段没有数值误差结果，原有数值夹具和阈值未改。

## 未覆盖范围

测试 JSON 是依据旧保存函数结构构造的契约样本，尚无用户真实旧文件覆盖。JSON 中同名重复键的检测、旧设置字段的算法映射、相机/格式/调节链恢复、旧资源迁移均未实现。文件识别不是原生项目导入；UI 文件选择和 File Provider 协调、XCTest 与双端设备验证未完成。

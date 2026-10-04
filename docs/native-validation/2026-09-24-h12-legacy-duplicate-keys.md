# H12 旧设置重复字段拒绝阶段验收

日期：2026-09-24。状态：**旧 `.lutcalc` 单文件 JSON 的重复键安全检查已实现并通过契约；字段迁移仍不可用。** 不更改旧文件，也不触碰旧 JS 引擎。此项修正[旧设置只读识别记录](2026-09-24-h12-legacy-inspector.md)列出的同名重复键缺口。

先写 `LegacySettingsContractsTests`，覆盖顶层 `version`、`gammaBox` 嵌套项与数组内对象的重复键，包含 `\u` 转义后才同名的键；还要求不同对象各自使用同一键保持合法。首次运行因 `LegacySettingsError.duplicateKey` 不存在而编译失败，日志 `/tmp/lutcalc-legacy-duplicate-red-20260924.log`。随后在 `LegacySettingsInspector` 已完成 `JSONSerialization` 语法验证之后，增加纯 Swift 逐字节扫描：每个对象单独维护解码后的键集合，重复时报告字段路径；数组保留索引；UTF-8、深度与节点数有限制。整个旧文件继续只读，`canMigrate` 仍为 `false`。旧 JS 的实际保存结构与原有 8 MiB 文件上限不变。

实际运行：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test -c release --package-path Native/Packages/LUTKit --filter LegacySettingsContractsTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run -c release --package-path Native/Packages/LUTKit LUTProjectSessionChecks
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash tools/native-validation/verify-native-release.sh
```

工具链 Xcode 27.0（27A266a）、Swift 6.4。修正后首项 2/2 XCTest 通过；`LUTProjectSessionChecks` 退出码 0，原有版本/字段/目录/链接/大小拒绝契约通过。完整发布入口中的 9 项 Node 子集检查通过、34 项 XCTest 通过且 0 失败，57 个 Swift 源文件静态原生边界检查通过，macOS、iOS Simulator、iOS generic 三个 Release 未签名构建各显示 `BUILD SUCCEEDED`。最终退出码 2，原因仍是缺少全量发布验收清单 `docs/native-validation/full-scope-acceptance.json`；不能计发布通过。本机完整日志 `/tmp/lutcalc-legacy-duplicate-release-20260924.log` 仅供诊断，关键结果已写在本文件。

修改版本 SHA-256：`Native/Packages/LUTKit/Sources/LUTProject/LegacySettingsInspector.swift` 为 `53cac162e728959c94d76ae227481217bd23eb758ec3adc0af7eeec7f8726548`；`Native/Packages/LUTKit/Tests/LUTProjectTests/LegacySettingsContractsTests.swift` 为 `507e4d20ff6c694b920ae277841a9fc649f27ee6214845df9f9715ce60e5ba79`。本阶段不涉及数值算法、网格、位宽、插值或精度门槛，故无新增误差结果。

未覆盖：用户真实旧设置样本、旧字段逐项可追溯映射、相机/调节/格式/精度恢复与 File Provider 导入。缺少这些条件时不能创建原生项目，`canMigrate` 保持关闭；H12/FULL-08 仍未完成。

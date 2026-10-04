# H12 Bradford 设置持久化与编辑保护

日期：2026-09-24。状态：**当前 `.lutcalc` 项目包的显式适应方式已可读写，草稿编辑保留该设置；旧 App JSON 不属于原生输入，当前入口明确拒绝；原生项目格式继续按独立 schema 规则验证。** 本项承接 H11 Panasonic 与 Apple 预设新增的 Bradford 选项，没有修改冻结数值阈值或网格。

## 失败先行契约与修正

`TransformSettings` 原有 CAT02 项目不写 `adaptation` 字段，新 Bradford 项目会明确写出它。新增 `ProjectContractsTests.testBradfordSettingsRoundtripAndUnknownAdaptationRejected` 后，首次 Release 单项测试失败：`unknownField("settings.adaptation")`，证实项目清单的严格字段白名单遗漏了新增字段。只将 `adaptation` 加入允许字段，未知字段继续拒绝，未知适应枚举也拒绝；`LUTProjectChecks` 进一步验证真实目录包的保存与重开。

随后新增 `SessionContractsTests.testEditingPreservesSavedBradfordChoice`：打开 Bradford 项目后修改输入范围、输出目标和曝光。首次 Release 测试三处失败，设置从 Bradford 静默退回 CAT02。原因是 `EditorSession` 与 `ProjectDocumentView` 重建 `TransformSettings` 时未传递原适应方式。六处草稿重建现均明确保留 `old.adaptation`。测试再确认项目保存后磁盘重开仍为 Bradford。视图回调的真实 iPhone/iPad 交互仍未验收。

相关文件 SHA-256：`ProjectManifest.swift` `c1b41fa2c18273a40443366157a1c04b0ccbdbb868cf2b1386c4f9dfc552c3e3`；`LUTProjectChecks/main.swift` `3ddd26e03d9dfc89a2b2b96b2cfcbdfdb00d99311b2c57135ccb5d36106d75ad`；`ProjectContractsTests.swift` `b61598fde3d76ab3a18c9996801471a81f989c79bc6a1beebe67a471e1c35e53`；`EditorSession.swift` `674ed5aa211a412d41e35785ab7709fbd418566d50a627818c5eec7b23656937`；`ProjectDocumentView.swift` `14fa4de69ae1b4314ac1db22d41341092456dd5a0ec7bde29b85da7b42a61859`；`SessionContractsTests.swift` `b7b78ba08e44d3bb55d0354b1c6a29fe145e62b1479e03662b0812a88ba97e8e`。源码/夹具版本与 H11 两份阶段记录保持关联。

## 实际验证

工具链：Xcode 27.0（27A266a）、Apple Swift 6.4。实际运行以下命令，两个新单项测试均先失败后通过；`LUTProjectChecks` 最终退出码 0：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test -c release --package-path Native/Packages/LUTKit --filter ProjectContractsTests/testBradfordSettingsRoundtripAndUnknownAdaptationRejected
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test -c release --package-path Native/Packages/LUTKit --filter SessionContractsTests/testEditingPreservesSavedBradfordChoice
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run -c release --package-path Native/Packages/LUTKit LUTProjectChecks
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash tools/native-validation/verify-native-release.sh
```

失败与修正后的单项输出本机分别在 `/tmp/lutcalc-bradford-project-red.log`、`/tmp/lutcalc-bradford-project-green.log`、`/tmp/lutcalc-bradford-session-red.log`、`/tmp/lutcalc-bradford-session-green-v2.log`。临时日志不是持久交付证据。

修正后最终一次 `verify-native-release.sh` 的实际结果：Swift Package 的 9 项子集检查全部通过；8 个 XCTest 套件共 32 项测试通过、0 失败；macOS、iOS Simulator、iOS generic 的 Release 未签名构建各显示 `BUILD SUCCEEDED`。脚本最终退出码为 2，明确停在缺少 `docs/native-validation/full-scope-acceptance.json`，因此发布验收仍未通过。最终本机日志路径为 `/tmp/lutcalc-final-stage-release-20260924.log`；本段保留了关键结果，避免把临时日志当作唯一证据。

当前清单格式仍为 `schemaVersion=1`，老文件缺少适应字段时保持 CAT02 默认读取。更早的原生清单版本迁移、旧 JS 单文件设置逐字段无损导入、File Provider 与设备保存事务仍待完成；不能把本项修正视为 H12 整体验收。

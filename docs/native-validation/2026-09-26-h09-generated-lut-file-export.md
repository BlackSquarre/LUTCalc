# H09 生成 LUT 系统文件导出阶段验收

日期：2026-09-26

## 范围

生成任务成功后，原生界面现在把输出临时文件读取成独立的 `GeneratedLUTExportDocument`（Swift `FileDocument`），再交给 SwiftUI `fileExporter`。文稿根据实际扩展名提供 `UTType`，系统保存面板的延迟写出、取消或失败不会重新读取可能已被清理或替换的临时文件；文稿保存的是生成成功时的原始字节快照。原有 `ShareLink` 继续保留。

文稿限制单一文件名、拒绝路径穿越，最大字节数与项目资源上限同为 256 MiB。该层只负责保存已生成文件，不改变 Double 计算、格式量化、目标文件提交和生成任务状态机。

## 修改文件

- `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectExportSession.swift`
- `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift`
- `Native/Packages/LUTKit/Tests/LUTSharedUITests/GeneratedLUTExportDocumentContractsTests.swift`

## 契约测试

新增 2 项 `GeneratedLUTExportDocumentContractsTests`：

1. 从实际生成文件读取后，即使源临时文件随后被改写，文稿文件名和字节在 `FileWrapper` 写出中仍保持生成时快照；
2. 路径穿越文件名和超过 256 MiB 的输入明确拒绝。

## 实际验证

工具链：Xcode 27.0、Swift 6.4、macOS SDK 27.0、iOS SDK 27.0。

```text
swift test --package-path Native/Packages/LUTKit -c release --filter GeneratedLUTExportDocumentContractsTests
```

结果：2 项通过，0 失败。

```text
swift test --package-path Native/Packages/LUTKit -c release
```

结果：退出码 0；测试清单 284 项，既有公开 NCP 实样按设计跳过，其余通过。最终日志：`/tmp/lutcalc-generated-export-final-swift-20260926.log`，SHA-256：`58ce0469c0c104662461580f3718416c191b201683265e2fd8066dbdb5c66357`。此前清单日志 SHA-256：`ad6ace9b7a1b09bac3b4629b90d7ba45838676a4b1654fc42e43dd345f9496f6`。

```text
bash tools/native-validation/verify-native-release.sh
```

结果：公式检查、CUBE 生成/独立读回、Swift Release、macOS Release、iOS Simulator Release、iOS generic Release、3 个 App 包资源审计均通过。脚本退出码 2，唯一直接失败是缺少真实 `docs/native-validation/full-scope-acceptance.json`；未创建或伪造该清单。最终日志：`/tmp/lutcalc-generated-export-final-native-release-20260926.log`，SHA-256：`8477bd150a3fab3575065da79f57280695f00e91be031d0f99e4306b38c53c92`。

## 未覆盖范围

- 尚未取得 macOS Finder、iOS/iPadOS Files 和 File Provider 真机上系统保存面板的完整交互证据；
- 尚未验证目标软件对每种格式的导入以及覆盖授权、磁盘满、后台挂起/终止和最终替换竞争；
- 该阶段不等于完整 H09/FLOW-03/FLOW-04/FLOW-06，也不改变 Goal 的 active 状态。

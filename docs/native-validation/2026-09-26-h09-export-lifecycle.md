# H09 生成临时文件生命周期阶段验收

日期：2026-09-26

## 范围

`ProjectExportSession` 现在登记自己创建的生成输出文件。成功输出在当前会话中保留供 `GeneratedLUTExportDocument`、`ShareLink` 和系统保存面板使用；会话关闭时保留最近一次成功结果以满足既有文档导出契约。开始下一次生成前清理上一份 owned 输出；取消、失败、过期请求和关闭中的未完成请求继续清理本次输出。用户指定的目标文件不由该会话删除。

## 修改文件

- `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectExportSession.swift`
- `Native/Packages/LUTKit/Tests/LUTSharedUITests/ProjectExportLifecycleContractsTests.swift`

## 契约测试

新增 2 项 `ProjectExportLifecycleContractsTests`：

1. 成功生成的临时输出在会话关闭后仍可读取；
2. 开始下一次生成前，上一份 owned 输出已清理。

测试通过注入的即时 Swift `ExportService` 创建可控输出，不依赖睡眠或真实磁盘故障。

## 实际验证

```text
swift test --package-path Native/Packages/LUTKit -c release --filter ProjectExportLifecycleContractsTests
```

结果：2 项通过，0 失败。

```text
swift test --package-path Native/Packages/LUTKit -c release
```

结果：退出码 0；测试清单 286 项，2 项既有公开 NCP 实样按设计跳过，其余通过。最终日志：`/tmp/lutcalc-export-lifecycle-final-swift-20260926.log`，SHA-256：`a27a0b53a0005e7ef4b93b171195078b823b78dc0bd67378c8bd11a39ace807f`。测试清单日志 SHA-256：`1499ba4ffd3d4788d891ac01434ac51c7cc49afea4db7b00a787f9a03c0e936b`。

```text
swift run --package-path Native/Packages/LUTKit -c release LUTDocumentExportChecks
```

结果：退出码 0，既有“关闭窗口后保留最近一次成功结果、关闭中的结果清理”契约通过。

```text
bash tools/native-validation/verify-native-release.sh
```

结果：公式检查、CUBE 生成/独立读回、Swift Release、macOS Release、iOS Simulator Release、iOS generic Release、3 个 App 包资源审计均通过。脚本退出码 2，唯一直接失败是缺少真实 `docs/native-validation/full-scope-acceptance.json`；未创建或伪造该清单。最终日志：`/tmp/lutcalc-export-lifecycle-final-native-release-20260926.log`，SHA-256：`3885014dd13331ffe4f976b96a511393b9ff4c8e412799ef99d13f1b80f84f56`。

## 未覆盖范围

- 系统保存面板已捕获字节文稿的真机 Files/File Provider 往返、授权撤销、覆盖竞争和磁盘满仍未验证；
- 该阶段不等于完整 H08/H09/FLOW-02/FLOW-04，也不改变发布清单缺失和 Goal active 状态。

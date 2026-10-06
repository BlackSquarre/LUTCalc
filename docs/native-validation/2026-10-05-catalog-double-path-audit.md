# AlgorithmCatalog 与 Double 生成路径审计

## 目的

本记录只审计原生算法目录中已有公开公式是否真正进入 `TransformPlan` 的 `Double` 计算路径。它不宣称完成任意 LUT 反求、厂商资料阻塞项、完整 HDR/ICC 或旧功能全量迁移。

## 审计方法

审计对象为（以下数字是 2026-10-05 审计时的历史快照）：

- `Native/Packages/LUTKit/Sources/LUTCore/TransformPlan.swift` 的 `TransferID`、输入解码分支和色域映射；
- `Native/Packages/LUTKit/Sources/LUTCore/NativeOutputEncoder.swift` 的输出编码分支；
- `Native/Packages/LUTKit/Sources/LUTCatalog/AlgorithmCatalog.swift` 的注册表与预设引用。

逐项核对 `TransferID` 枚举（79 项）与输入解码、输出编码分支。合并写法（例如多个 gamma、Apple Log 两个稳定 ID、ARRI SUP2/SUP3）按各自 ID 的 `switch` 可达性核对，不以文本出现次数代替覆盖判断。20 个 `ColorSpaceID` 均核对到 `ColorPrimaries`，并由 `TransformPlan` 的矩阵转换使用。

## 实际命令与结果

工具链：Swift Package Manager、Swift 6 package manifest、macOS Release。

```text
swift run -c release --package-path Native/Packages/LUTKit LUTCatalogChecks
APP-03 注册表基础契约通过：79 曲线、20 色域、75 预设、稳定 ID/别名/来源、重复与悬空引用拒绝
```

```text
swift test --package-path Native/Packages/LUTKit --filter RegistryContractsTests
LUTCatalogTests: 20 tests, 0 failures
RegistryContractsTests: 19 tests, 0 failures
ProPhotoBBCRegistryContractsTests: 1 test, 0 failures
```

`git diff --check` 通过。审计期间没有修改 `TransformPlan`、`NativeOutputEncoder` 或注册表实现；工作区中其他文件的既有修改保持不动。

## 当前计数说明

2026-10-06 后续注册表扩展后，当前计数已校准为 `82` 个 transfer、`23` 个色域和 `76` 个预设；`TransformPlanIdentityCoverageContractsTests` 对当前 `82` 个 transfer 的双向身份覆盖通过。本文的 `79/20/75` 仅保留为当日审计快照，不应作为当前目录数量引用。

## 结论

在本审计范围内，没有发现“已有公开公式已实现但未接入 Double 生成路径”的真实缺口，因此没有新增代码接线。该结论只证明目录到现有计算分支的连接性，不能扩大为公式数值完整性、独立参考一致性或全量迁移完成。

## 未覆盖范围

- 任意 3D LUT 全局反求和完整重建；
- `.labin`、直接查表注册及资料阻塞的厂商算法；
- 完整 ICC、HDR/EDR/OOTF、白平衡和调节链；
- 真机、平台文稿、发布签名和全量验收清单。

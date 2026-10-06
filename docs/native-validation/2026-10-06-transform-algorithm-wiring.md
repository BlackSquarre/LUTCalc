# TransformPlan 算法接线验收

## 范围

本记录只覆盖纯算法接线，不覆盖 SwiftUI、文稿界面或真机运行。审计对象为 GoPro GP-Log2 base-600、连续 Rec.2020 OETF，以及已有的 ACES RGC、BT.2100 HLG reference OOTF。

## 结果

- GP-Log2 已在 `TransformPlan` 的输入解码和输出编码路径使用 `GPLog2Transfer`；同空间 round-trip 契约覆盖 `0、0.18、0.5、1`。
- 连续 Rec.2020 已在 `TransformPlan` 的输入解码和输出编码路径使用 `Rec2020ContinuousTransfer`；契约覆盖分段阈值和代表性场景值。
- GP-Log2 的 `planVersion` 原先落入默认 D-Log2 身份，属于项目算法版本接线错误；已修正为 `minimal-gopro-gplog2-base600-v1`，避免项目缓存或重建时混淆算法。
- 连续 Rec.2020 的 `planVersion` 已为 `minimal-rec2020-continuous-v1`。

## S-Log3 身份复核

契约先行新增 published 与 LUTCalc legacy S-Log3 的同向计划比较。修复前二者均返回 `minimal-slog3-v1`，会造成不同 legal/data 语义复用同一缓存或批次指纹。现返回 `minimal-slog3-v1:<inputTransferID>:<outputTransferID>`，保留两端 transfer 原始 ID；Release `TransformAlgorithmWiringContractsTests` 4 项通过。
- ACES RGC 已有独立 stage 75 计划契约；BT.2100 HLG reference OOTF 已有 stage 130 与独立参考内核契约，本轮未重复改动其数值实现。

## 实际命令与结果

```text
swift test --package-path Native/Packages/LUTKit -c release --filter TransformAlgorithmWiringContractsTests
```

结果：`TransformAlgorithmWiringContractsTests` 3 项通过，0 失败。首次运行发现 GP-Log2 版本身份断言失败，修正 `TransformPlan.basePlanVersion` 后复跑通过。

## 未覆盖范围

本记录不证明任意 3D LUT 全局反求、`.labin`/直接查表替代、完整 ICC、PQ OOTF/HDR、UI 或平台发布验收已完成。

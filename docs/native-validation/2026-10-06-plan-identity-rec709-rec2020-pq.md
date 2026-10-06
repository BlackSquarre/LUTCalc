# Rec.709、Rec.2020 10-bit 与 PQ 计划身份验收

## 范围

本阶段只修复 `TransformPlan.planVersion` 的身份冲突。Rec.709 legacy、Rec.2020 10-bit 和 Rec.2100 PQ 的输入解码、输出编码、矩阵计算、Double 精度和阈值均未改变。

## 失败契约与实现

新增 `Rec709Rec2020PQPlanIdentityContractsTests`，先要求每个传递函数的 decode/encode 方向和不同输入/输出色域产生不同身份。随后仅修改 `TransformPlan.basePlanVersion` 的三个分支，使身份包含输入/输出 `TransferID` 与 `ColorSpaceID`。

`NativeOutputEncoder` 和 `TransformPlan` 的数值分派保持原样。

## 验证

命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter Rec709Rec2020PQPlanIdentityContractsTests
```

工具链：SwiftPM Release，Apple Swift 工具链。

结果：3 项通过，0 失败，退出码 `0`。

受影响回归：

- `swift test --package-path Native/Packages/LUTKit -c release --filter 'Rec2020TenBitContractsTests|Rec2020TwelveBitContractsTests|Rec709Rec2020PQPlanIdentityContractsTests'`：9 项通过，0 失败。
- `swift test --package-path Native/Packages/LUTKit -c release`：完整 SwiftPM Release 回归退出码 `0`。
- `git diff --check`：通过。

## 未覆盖范围

本阶段不代表全局 `TransformPlan` 身份审计完成，不覆盖其他 transfer、项目 schema、UI、格式往返、设备、性能或发布验收。Goal 保持 `active`。

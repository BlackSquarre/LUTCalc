# Rec.2020 continuous 与 GP-Log2 计划身份验收

## 范围

复核发现 `rec2020.bt2020-continuous.v1` 与 `gopro.gplog2-base600.v1` 的 `basePlanVersion` 只记录 transfer 方向，没有记录输入/输出 `ColorSpaceID`。不同矩阵色域路由因此可能共用计划身份。

本项只修复计划身份，不改 BT.2020 continuous 或 GP-Log2 base-600 的公开标量公式、输入域、Double 路径、范围、网格或量化规则。

## 契约与实现

- 两个现有 transfer 契约各新增方向、输入色域、输出色域差异检查，并确认基准身份包含双端色域 ID。
- 修复前定向 Release 执行 2 项新增身份测试，4 条差异断言失败，确认两个分支确实遗漏双端色域。
- 两个分支现使用完整 transfer 对与 `inSpace`/`outSpace` 字段。

## 验证

- 修复后定向 Release：`swift test --package-path Native/Packages/LUTKit -c release --filter 'Rec2020ContinuousContractsTests|GPLog2TransferContractsTests'`，7 项通过，0 失败。
- 工具链 Apple Swift 6.4，`swift-driver` 1.168.6，目标 arm64 macOS 27.0.0。
- 两个 transfer 的既有独立数值契约仍在同一命令中通过；没有新增采样表或厂商资源。
- 后续 LUTCore/目录组合命令 `swift test --package-path Native/Packages/LUTKit -c release --filter 'LUTCoreTests|LUTCatalogTests.RegistryContractsTests'` 退出码 `0`；其中同步了 `TransformAlgorithmWiringContractsTests` 的 GP-Log2 旧短身份断言。
- 全量 Release：`swift test --package-path Native/Packages/LUTKit -c release --quiet`，退出码 `0`，SwiftPM 输出 `All tests passed`。`git diff --check` 通过；SwiftPM 未导出 `.xcresult`。

## 未覆盖范围

这里只关闭两个 transfer 分支的计划身份别名，不代表 GP-Log2 设备范围、负值扩展、Rec.2020 完整 HDR/EDR 语义、`.labin`/直接查表、完整 ICC 或全局计划参数指纹完成。Goal 保持 `active`。

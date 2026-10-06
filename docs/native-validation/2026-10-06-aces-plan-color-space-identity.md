# ACES transfer 计划色域身份验收

## 范围

`TransformPlan.basePlanVersion` 中 ACEScc、ACEScct、ACESproxy 10-bit 和 ACESproxy 12-bit 原已区分输入/输出 transfer，但没有记录输入/输出 `ColorSpaceID`。同一 transfer 对下，变更任一色域仍会产生相同 `planVersion`，无法区分不同 primaries 矩阵路由。

本项只调整计划身份字符串和受影响的固定身份断言，不修改 ACES transfer 公式、矩阵、Double 计算、网格、位宽或容差。

## 契约与实现

- 在 `ACESCCContractsTests`、`ACESCCTContractsTests`、`ACESProxyContractsTests` 中新增双端色域身份契约。分别改变输入色域、输出色域，并检查身份串含 `inSpace`/`outSpace`。
- 修复前 Release 定向编译通过后，3 项契约测试执行并失败，共 16 条身份断言失败，证明旧版本遗漏双端色域字段。
- ACEScc、ACEScct 与两种 ACESproxy 计划版本现包含输入/输出 `TransferID` 和输入/输出 `ColorSpaceID`。目录测试中原硬编码的 ACEScc 旧短身份同步为新完整身份。

## 验证

- 修复后定向 Release：`swift test --package-path Native/Packages/LUTKit -c release --filter 'ACESCCContractsTests|ACESCCTContractsTests|ACESProxyContractsTests'`，14 项通过，0 失败。
- 目录定向 Release：`swift test --package-path Native/Packages/LUTKit -c release --filter LUTCatalogTests.RegistryContractsTests`，22 项通过，0 失败。
- 全量 Release：`swift test --package-path Native/Packages/LUTKit -c release --quiet`，退出码 `0`，输出 `All tests passed`。SwiftPM 工具链 Apple Swift 6.4，`swift-driver` 1.168.6，目标 arm64 macOS 27.0.0。
- 全量运行首次发现目录中另一个 ACEScc 旧短身份断言；更新后目录及完整 Release 回归均通过。SwiftPM 没有导出 `.xcresult`，本记录保存实际命令和结果。没有重新计算数值误差，因为 transfer 公式和生成路径未改。
- `git diff --check`：通过。

## 未覆盖范围

这只关闭 ACEScc/ACEScct/ACESproxy 四个计划分支的色域身份别名，不是所有 `TransformSettings` 的完整缓存指纹，也不表示全局 `TransformPlan` 身份审计完成。其他 transfer 家族、`.labin` 与直接查表替代、任意 3D 全根、完整 ICC/HDR/OOTF、平台/设备及发布验收仍未完成；Goal 保持 `active`。

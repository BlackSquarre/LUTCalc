# Mi-Log、Leica L-Log、KineLOG3 计划身份验收

## 范围

本工作包只修复 `TransformPlan.basePlanVersion` 中 Xiaomi Mi-Log、Leica L-Log、KineLOG3 三个固定版本分支的身份碰撞，不改 transfer 公式、矩阵、执行顺序、精度或数值阈值。

目录当前为 Xiaomi Mi-Log 与 Leica L-Log 提供 Rec.2020 曝光预设，为 KineLOG3 提供 Kinefinity Wide Gamut 曝光预设。契约以这些目录色域作为各自基准，并用已注册、可参与矩阵变换的 sRGB、Rec.2020、Display P3 色域检查两端身份字段。身份内容仅描述计划所选的输入/输出 transfer 和两端色域，不声称这些 transfer 只能与基准色域配对。

## 契约与修复

先在 `MiLogContractsTests`、`LLogContractsTests`、`KineLog3ContractsTests` 各加入一项契约，逐项要求反转 transfer 方向、只改变输入色域、只改变输出色域时 `planVersion` 均发生变化。

修改前运行：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter 'MiLogContractsTests|LLogContractsTests|KineLog3ContractsTests'
```

旧实现下三份新契约共报告 9 个 `XCTAssertNotEqual` 失败，证明每个分支均丢失方向、输入色域和输出色域身份。首次尝试曾因测试构造器遗漏必需 `exposureStops` 而编译失败；补为中性值 `0` 后，测试成功编译并得到上述红灯。

三个分支现在将输入/输出 `TransferID` 和输入/输出 `ColorSpaceID` 追加到各自原有 `minimal-…-v1` 标识之后。此前测试对旧完整字符串的断言改为检查稳定算法前缀，并保留新身份差异契约。

## 验证状态

合并后定向 Release 验收由主线程统一运行：Mi-Log、Leica L-Log、KineLOG3 与其他本轮计划身份契约组合共执行 59 项，0 失败。整包 `swift test --package-path Native/Packages/LUTKit -c release` 退出码 `0`，`git diff --check` 通过。

本工作包旧实现红测共 9 个身份断言失败。合并定向结果证明三个修复分支现有契约通过；本包不单独声称新增测试执行数，也不新增数值误差结论。

## 身份边界与未覆盖

- 本记录只覆盖上述三个 transfer 分支中 transfer 方向与两端色域字段的区分。
- `planVersion` 的这些字段不是所有 `TransformSettings` 数值参数的完整序列化指纹；不得据此推断 exposure、范围、位深、输出策略、其他选项或所有计划分支均已闭合。
- 本记录所列身份修复已纳入完整 SwiftPM Release 回归；未覆盖查表替代、`.labin`、ICC、HDR/OOTF 或平台验收。

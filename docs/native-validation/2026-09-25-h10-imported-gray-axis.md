# H10 用户 LUT 灰轴检查接线阶段验收

日期：2026-09-25。范围：把已实现的 Double 灰轴分析接到用户主动导入的三维 `CubeLUT` 和原生文稿功能草稿，保留该 LUT 只读且不参与生成的边界。

## 先失败契约

新增 `GrayAxisCubeContractsTests`，先运行 `swift test --package-path Native/Packages/LUTKit -c release --filter GrayAxisCubeContractsTests`。编译按预期失败：分析器只接受 `LUTVolume3D`，尚无 `CubeLUT` 入口与一维拒绝错误；日志 `/tmp/lutcalc-gray-axis-cube-red.log`，SHA-256 `a550c8427fce4fcc09adb202facce1e06966be8263af4f91187169d1ddc18592`。

契约用 2³ 非线性跨通道 LUT，前接输入域 `[-1,1]`、输出到 `[0.25,0.75]` 的 shaper。灰轴必须沿 shaper 原始输入域取样，依次得到 `0.0625`、`0.5625`，三线性中点重建最大残差为 `0.0625`。一维 LUT 必须明确拒绝，不能伪称为三维灰轴。

## 实现与验证

- `LUTAnalysis` 通过既有 `LUTFormats` 类型读取组合 CUBE；有 shaper 时沿 shaper 输入域，无 shaper 时沿三维域。取样仍调用 `CubeLUT.sample` 的 Double 路径，显式保留插值方法和沿线中点残差。与原 `LUTVolume3D` 入口共用分析计算，不改变生成计划。
- 文稿功能草稿在已载入三维用户 LUT 时显示“检查灰轴”按钮、样本/中点数及最大通道残差，明确提示残差只对应输入域对角线。切换 LUT、项目或插值方法时清除旧结果。
- Release 定向 `GrayAxisContractsTests` 3 项与新增 `GrayAxisCubeContractsTests` 2 项均通过；日志 `/tmp/lutcalc-gray-axis-cube-green.log`，SHA-256 `e2be95d602664b34d7343c77d197e5a694010a638b32395efc313945d3e59210`。macOS Release App 构建通过，日志 `/tmp/lutcalc-gray-axis-mac-build.log`，SHA-256 `d130b213a0439600b2f45122ed0bdf3e5f16d066934eb6103188b863d24fbe52`。
- 实现及新测试文件 SHA-256 分别为 `8d51c4a9cc5b43b6e817fe2d5fdca4812917cd811a01c5c9fceb2b45be462b60` 与 `436e18da71bb7cc4e66e21ec043f0ef1f3872d5dc25f3466ee37a5785f915f2d`。

该定向结果不证明完整 3D 重建、TF/颜色分离、裁剪/噪声病态分析、实际设备交互或用户 LUT 已进入变换。iOS 两种 Release 构建及全量数值回归随后已在[本批合并回归](2026-09-25-h04-h10-combined-release.md)中完成；H10/FULL-05 与发布门槛仍未完成。

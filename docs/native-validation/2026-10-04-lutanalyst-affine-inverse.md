# 2026-10-04 LUTAnalyst 显式仿射 3D 反求生成验收

## 范围

本工作包把既有 `KnownAffine3DTransform` 接入 `LUTGenerationRequest` 和 3D 生成路径。只有调用方显式提供、通过矩阵条件数／残差检查的仿射模型才可使用；计划同时冻结输入域、输出域和模型内容指纹。任务输出域必须等于请求网格域，反求结果超出声明输入域时失败。该能力不从任意用户 3D LUT 样本拟合或推断反函数。

仿射逆与 1D transfer 逆、用户 input shaper 不能隐式叠加。曝光批次将仿射计划传递至每项，并把完整模型指纹纳入批次 fingerprint。

## 数值契约

- 定向测试用完整非对称 3×3 矩阵与平移构造已知仿射模型，生成 3³ 网格 CUBE，再经 `CubeParser` 读回。
- 逐节点参照使用测试内独立伴随矩阵／行列式公式，不调用生产逆矩阵求解器；81 个 RGB 通道值最大绝对误差 Debug／Release 均为 `2.220446049250313e-16`，门槛保持 `2e-12`。
- 另有契约覆盖曝光批次传递及 fingerprint 区分、输出域不匹配、与其他输入逆冲突，以及奇异矩阵拒绝。

## 验收命令和结果

工具链：Xcode `27.0 (27A266a)`，Swift `6.4`，目标 `arm64-apple-macosx27.0.0`。

```sh
swift test --package-path Native/Packages/LUTKit -c debug \
  --filter AffineInverseGenerationContractsTests
swift test --package-path Native/Packages/LUTKit -c release \
  --filter AffineInverseGenerationContractsTests
swift test --package-path Native/Packages/LUTKit -c release
```

- 定向 Debug：4 项通过、0 失败，退出码 `0`。
- 定向 Release：4 项通过、0 失败，退出码 `0`。
- 全量 Release 使用 `set -o pipefail` 记录管道真实状态，退出码 `0`；LUTSharedUI `163`、LUTProject `64`、LUTPreview `94`、LUTJobs `72`、LUTFormats `61`（旧 `.labin` 研发样本和公开 NCP 样本各跳过 1 项）、LUTCore `236`、LUTCatalog `24`、LUTAnalysis `47`；共 `761` 项、0 失败、2 项按既有规则跳过。

日志：

- `artifacts/2026-10-04-lutanalyst-affine-inverse/targeted-debug.log`，SHA-256 `a5f5b904848eb6caad2a9a9a857f7e916a85aa36000474ba94d80858bddee71a`
- `artifacts/2026-10-04-lutanalyst-affine-inverse/targeted-release.log`，SHA-256 `d5134b18c50fbfa15b3813cba900b12ad36c346b5363f9f0b4d4d14073ffe5a2`
- `artifacts/2026-10-04-lutanalyst-affine-inverse/full-release.log`，SHA-256 `ae1734f55630257c2dd3aa9a485f68e6b7f1822dfba9ca7c02926bcabfac1e7b`

## 未覆盖范围

本记录只关闭显式已知仿射 3D 模型的生成接线。它不证明有限采样 LUT 可唯一拟合成仿射模型，不支持由任意 3D LUT 推断反函数，也不覆盖裁剪、多对一、局部奇异和全局多根分析。模型尚未进入项目持久化或 UI；自动 TF／颜色分离和完整重建、旧 `.labin`／查表替代、HDR／ICC、跨平台构建数值和全量 Goal 验收仍未完成。FULL-05、H10 和 Goal 均保持 active。

# H11 CIELAB 非矩阵计划阶段验收

日期：2026-09-26

## 失败契约

CIELAB 前置数学契约已经存在，但 `CIELABColorSpace` 明确不属于 `ColorSpaceID` 或现有 RGB `TransformPlan`。本批先加入 `CIELABPlanContractsTests`，要求以下类型和阶段存在：

- `CIELABPlanSettings` 必须显式保存源 XYZ 白点、Lab 白点、目标 XYZ 白点和 CAT 选择；
- XYZ→Lab 必须按“XYZ 输入 → 白点适应 → Lab 输出”执行；
- Lab→XYZ 必须按“Lab 输入 → 从 Lab 解码的 XYZ → 白点适应 → XYZ 输出”执行；
- L* 归一化为 0…1，a*/b* 保持传统单位；非有限 XYZ 必须拒绝；
- 不能把 Lab 当成 RGB 原色矩阵或静默映射到现有项目 schema。

首次执行：

```text
swift test -c release --package-path Native/Packages/LUTKit --filter CIELABPlanContractsTests
```

结果：按预期编译失败，`CIELABPlanSettings`、`CIELABTransformPlan` 和阶段 ID 尚不存在。该失败输出保留在本次会话日志中，随后才实现代码。

## Swift Double 实现

新增 `LUTCore/CIELABTransformPlan.swift`：

- `CIELABPlanSettings` 使用稳定 Codable 值保存三个白点和 `ChromaticAdaptation`；
- `CIELABTransformPlan` 只处理 XYZ/Lab 通道，不修改现有 RGB `TransformPlan`、`TransformSettings` 或项目 schema；
- 白点从冻结 XYZ 常数推导 chromaticity，使用既有 Bradford/CAT02 Double 矩阵；
- `CIELABStageID`/`CIELABStageTrace` 显式保留非矩阵阶段和中间 XYZ；
- `xyzToLab`、`labToXYZ` 复用既有分段 CIELAB 公式，错误通过明确阶段返回，不用零值替代。

新增 `CIELABPlanContractsTests` 共 5 项，覆盖：

1. 白点适应阶段和中性白；
2. Lab→XYZ 目标白点及往返；
3. Lab/XYZ 通道和阶段追踪、非有限输入拒绝；
4. 独立 Bradford 非中性样本：最大绝对误差门槛 `2e-14`；
5. D65→D50→D65 的 33³ 与 65³ 网格往返，最大绝对误差门槛 `2e-12`。

源码 SHA-256：

- `CIELABTransformPlan.swift`：`6a1c015f63380a3d73ecf75988a8aef087b4df4076a14127839f3973ba1a3e1f`；
- `CIELABPlanContractsTests.swift`：`e25a9ece568ce3c0250002921434009f5c613fc44ddf11be0de1bb160c062fef`。

## 验证结果

- 定向 Release：5 项通过；
- 全量 `swift test -c release --package-path Native/Packages/LUTKit`：225 项列出，1 项既有可选 NCP 实样按设计跳过，其余通过；
- `verify-native-subset.sh`：静态边界、旧 Node/Python 契约、7 个批量公式检查、46 对 33³/65³ CUBE 生成与读回、H04/H08/H09/H10/H12/H13 命令行契约全部通过；日志 `/tmp/lutcalc-cielab-plan-subset.log`，SHA-256 `fd4f5c5c3a725ea76b66086ca08ab2e3eb7b438ec7aeb45789342c7c7cb30963`；
- `verify-native-release.sh`：Swift Release、macOS Release、iOS Simulator Release、iOS generic Release、三个 App 包资源审计通过；最终日志 `/tmp/lutcalc-cielab-plan-release-final-20260926.log`，SHA-256 `f173708b48dcaaf3aefa93211ca01c58a2a5dba97bf67680f99e80d0b84898d7`；
- 发布证据检查仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出码 `2`，未创建或伪造清单。

## 范围结论

本批完成 CIELAB 非矩阵计划的白点、量纲和阶段语义冻结，并通过 Double 定向和网格回归。它不等于完整 CIELAB 色彩空间、Delta E、RGB↔Lab 项目持久化、显示色彩管理、Core Image/Metal、HDR/EDR、真机或完整迁移；现有 RGB `TransformPlan` 和原生项目 schema 继续保持不变。

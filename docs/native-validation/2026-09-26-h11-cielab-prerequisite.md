# H11 CIELAB 前置契约阶段验收

日期：2026-09-26。状态：前置数学契约通过；不代表完整 CIELAB 工作流、完整 H11 或全量迁移完成。

## 本批范围

- 在 `LUTCore` 增加 `XYZ64`、D50/D65 参考白点和 `CIELABColor` 值类型。
- 按 ISO 11664-4 与 ITU-R BT.2380-0 §3.3 实现 XYZ↔CIELAB 的纯 Swift `Double` 分段公式。
- 保留负值、超白和扩展域；仅拒绝非有限值。
- L* 使用 0…1 归一化，a*/b* 保留传统单位；不把 Lab 当作 RGB 矩阵色域注册，也未接入 `TransformPlan` 或项目持久化。

## 契约与实现

先加入失败契约 `CIELABContractsTests`，确认缺失的 `XYZ64`、白点和转换类型会使 Release 编译失败，日志为：

- `/tmp/lutcalc-cielab-red-20260926.log`
  - SHA-256：`bd4d568f42ddccadae1c53611a175084ef492b3f9d8758484ac7d6e136ed225f`

实现文件：

- `Native/Packages/LUTKit/Sources/LUTCore/CIELAB.swift`
- `Native/Packages/LUTKit/Tests/LUTCoreTests/CIELABContractsTests.swift`

契约覆盖：

1. D50/D65 精确白点常量。
2. `216/24389` 线性分支边界及边界下方行为。
3. 黑、典型、负值、超白 XYZ 的往返。
4. 白点中性轴 `L*=1, a*=0, b*=0`。
5. XYZ、Lab 非有限值拒绝。

## 验证证据

- 定向 Release：3 项 `CIELABContractsTests` 通过。
  - 日志：`/tmp/lutcalc-cielab-targeted-20260926.log`
  - SHA-256：`c86091754df6e72220d3b148a62393895ed9c50a43b22f7089136378078457dc`
- 独立 Decimal 参考批量：D50、D65 各覆盖 33³ 与 65³ 坐标，共 621,124 个样本；最大绝对误差均为 `1.7763568394002505e-15`，门槛 `2e-13`。
  - 脚本：`tools/native-validation/verify-cielab.py`
  - Swift 检查器：`Native/Packages/LUTKit/Sources/LUTCIELABChecks/main.swift`
  - 日志：`/tmp/lutcalc-cielab-independent-20260926.log`
  - SHA-256：`5a9720e7cac66412517bf016dcc2c7b564a42e37f77d747e472134a32445f19c`
- 全量 Swift Release：通过。
  - 日志：`/tmp/lutcalc-cielab-full-swift-20260926.log`
  - SHA-256：`6e835313f546e35c82973fef4173369f6ae67f357589ba855b9ec37ac495ee16`
- 与同日 BBC WHP283 批次合并后的集中回归为 220 项 Swift 测试；三平台 Release 构建和三个 App 包资源审计通过。合并日志为 `/tmp/lutcalc-after-cielab-bbc-release-20260926.log`，SHA-256：`3e27fb64f182de30d69b6c07351028aac01017debb831f1ebfd5e9f2a26bee43`。发布入口仍因缺少真实全量清单退出码 2。

## 未完成边界

本批没有声明完整 CIELAB D50↔D65 工作流、XYZ/RGB/显示转换、Delta E、Core Image/Metal、HDR/EDR、真机、Files/File Provider、项目持久化或发布门槛完成。后续接入必须先冻结非矩阵色彩空间、白点适应、a*/b* 量纲和 `TransformPlan` 阶段语义；当前 Goal 保持 active。

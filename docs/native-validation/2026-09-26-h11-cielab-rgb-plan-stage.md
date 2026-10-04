# H11 RGB↔XYZ↔CIELAB 桥接计划阶段验收

日期：2026-09-26

## 失败契约

CIELAB 前置数学契约和独立 XYZ↔Lab 非矩阵计划已经完成，但现有 RGB `TransformPlan` 仍只表达 RGB 原色与传递曲线。本批先加入 `CIELABRGBPlanContractsTests`，要求新增独立桥接类型，并在类型不存在时按预期编译失败。

失败契约要求：

- `CIELABRGBPlanSettings` 显式保存源/目标 RGB 原色、各自声明白点、Lab 白点和 CAT 选择；
- RGB→Lab 必须按“RGB 输入 → RGB→XYZ 矩阵 → 白点适应 → Lab 输出”执行；
- Lab→RGB 必须按“Lab 输入 → Lab 解码 XYZ → 白点适应 → XYZ→RGB 矩阵 → RGB 输出”执行；
- 阶段追踪必须区分 RGB、XYZ 和 Lab 通道，L* 保持 0…1，a*/b* 保持传统单位；
- 非有限输入和 RGB 原色白点声明不匹配必须显式拒绝；
- 不得修改现有 RGB `TransformPlan`、`ColorSpaceID` 或原生项目 schema。

首次定向命令：

```text
swift test -c release --package-path Native/Packages/LUTKit --filter CIELABRGBPlanContractsTests
```

结果：按预期因 `CIELABRGBTransformPlan`、`CIELABRGBPlanSettings` 和阶段类型尚不存在而失败；保留该失败契约后才实现 Swift 代码。

## Swift Double 实现

新增 `Native/Packages/LUTKit/Sources/LUTCore/CIELABRGBTransformPlan.swift`：

- 以独立 `CIELABRGBTransformPlan` 组合既有 RGB 原色矩阵与 `CIELABTransformPlan`，不把 Lab 注册为 RGB 原色或传递曲线；
- 正向路径使用源 RGB→XYZ 矩阵，再交给非矩阵 CIELAB 计划完成白点适应和 Lab 编码；
- 逆向路径先从 Lab 解码 XYZ，再完成 Lab 白点到目标 RGB 白点的适应，最后使用目标 XYZ→RGB 矩阵；
- 构造时校验 RGB 原色内置白点与声明白点的一致性，避免静默使用错误白点；
- `CIELABRGBStageTrace` 保留每个阶段的 RGB/XYZ/Lab 值；`CIELABRGBPlanError` 保留 Lab 子阶段或数值失败阶段；
- 所有计算继续使用 Swift `Double`，不引入厂商 LUT、`.labin`、等价采样表或 Web/JS runtime。

## 定向契约与数值门槛

新增 `CIELABRGBPlanContractsTests` 共 5 项：

1. 检查 RGB→XYZ→白点适应→Lab 的阶段顺序和中间值；
2. 用独立公开原色/Bradford 参考固定 sRGB D65→D50 样本：RGB `(0.25, 0.5, 0.75)` 得到
   `L*=0.7351559484043333`、`a*=-0.10203582393322475`、`b*=-0.24276801877406728`，门槛 `2e-14`；
3. 对 sRGB D65、Lab D50 的 33³ 与 65³ 全网格执行 RGB→Lab→RGB 往返，最大绝对误差门槛 `2e-12`，并检查逆向阶段顺序；
4. 非有限 RGB 输入拒绝；
5. RGB 原色白点与声明白点不匹配时拒绝。

## 回归结果

- 定向 Release：`CIELABRGBPlanContractsTests` 5 项通过；
- 全量 Swift Release：`swift test -c release --package-path Native/Packages/LUTKit` 通过；`swift test --list-tests` 列出 230 项，新增后 LUTCore 测试目标为 70 项，既有可选 NCP 实样仍按设计跳过 1 项；
- `bash tools/native-validation/verify-native-subset.sh` 通过，包含静态边界、既有 Node/Python 契约、7 个公式检查、46 对 33³/65³ CUBE 生成与独立读回及 H04/H08/H09/H10/H12/H13 命令行契约；日志：[subset 日志](file:///tmp/lutcalc-cielab-rgb-subset.log)；
- `bash tools/native-validation/verify-native-release.sh` 的 Swift Release、macOS Release、iOS Simulator Release、iOS generic Release 和三个 App 包资源审计通过；日志：[release 日志](file:///tmp/lutcalc-cielab-rgb-release.log)；
- 发布入口最终仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出码 `2`。未创建或伪造清单。

本批证据 SHA-256：

- `CIELABRGBTransformPlan.swift`：`0e3e5eafd7fbdd24f48ea03e1a3b76a4ede02e23debc48803bad450260562f28`；
- `CIELABRGBPlanContractsTests.swift`：`5c310130b3d8ab14ab9fd40a1837c2436d6826f67d16a7386c621a16ad197cdd`；
- 本验收记录正文（去除本哈希清单行）：`88f6db25b2f1ec2be265e5bd0e5ffbd4d58a323dca77f8a7cbc725c02f6ab805`；
- `/tmp/lutcalc-cielab-rgb-release.log`：`5fb537975bdb73f0821537cb17ae8a22c00d38b5350c2fb04a56235fb59670d8`；
- `/tmp/lutcalc-cielab-rgb-subset.log`：`261d42f9784717c88a18b1f4abc114c77bb2103a3176d1edd75e1e8e48f2a9ea`；
- `/tmp/lutcalc-cielab-rgb-swift-full.log`：`be5bdfc5381bc69a220159810a92a40ca5d5aeaa95015037c714875e567b3451`。

## 范围结论

本批只冻结 RGB↔XYZ↔CIELAB 的可追溯桥接阶段和数值契约，不等于完整 CIELAB 色彩空间、Delta E、完整显示色彩管理、ICC 工作空间转换、Core Image/Metal、HDR/EDR、真机验证、Files/File Provider 或完整迁移。现有 RGB `TransformPlan`、`ColorSpaceID`、原生项目 schema v1→v2 兼容及旧 App JSON 设置迁移删除状态均保持不变；真机仍按计划最后集中处理。

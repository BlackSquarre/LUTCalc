# LUTAnalyst 四面体分区三维反求诊断验收

## 范围

本工作包只处理已有 LUTAnalyst 任意 3D 反求缺口中可以由当前插值契约精确描述的子集：对 `tetrahedral` 插值的每个网格单元按现有六种轴序拆成四面体，逐个建立输出空间的 3×3 仿射方程并枚举目标的所有落入四面体的解。相邻四面体的同一边界解按输入坐标去重。

没有使用旧 JavaScript 的逆向采样表、经验外插、NaN 填充或任意模型拟合。奇异／病态仿射单元返回 `unresolved`，而不是选择一个伪唯一结果；带 input shaper 的 CUBE 和非 `tetrahedral` 插值显式拒绝。

## 契约与独立参照

- 单位 identity 网格：目标有且只有一个全局解，随后用 `LUTVolume3D.sample(..., .tetrahedral)` 回放，通道误差不超过 `2e-12`。
- 折叠网格 `4r(1-r)`：同一目标枚举出 `r=0.25` 与 `r=0.75` 两个分支，残差不超过 `2e-12`，不压成单值。
- 域外目标：报告无解；退化常量映射：报告 `unresolved` 并统计未决四面体。
- 非对称仿射网格：与独立 `KnownAffine3DTransform` 矩阵逆参照一致，输入误差不超过 `2e-12`。
- 无效无限容差、无效 condition limit、非 tetrahedral 插值和隐式 shaper 反求均拒绝。

## 实际变更

- 新增 `LUTAnalysis/Tetrahedral3DInverse.swift`，提供 `Tetrahedral3DInverseReport`、所有解、残差和未决四面体计数。
- `ImportedLUTAnalyzer.diagnoseTetrahedralColourInverse(...)` 只接受 `tetrahedral`，将诊断接入既有分析入口；不改变原有 transfer/shaper 1D 反求。
- 新增 `TetrahedralInverseContractsTests` 共 7 项契约。

## 验收命令与结果

工具链：Xcode `27.0 (27A266a)`，Swift `6.4`，目标 `arm64-apple-macosx27.0.0`。

```sh
swift test --package-path Native/Packages/LUTKit \
  --filter TetrahedralInverseContractsTests
swift test --package-path Native/Packages/LUTKit -c release \
  --filter TetrahedralInverseContractsTests
swift test --package-path Native/Packages/LUTKit -c release
```

- 定向 Debug：7 项通过、0 失败，退出码 `0`。
- 定向 Release：7 项通过、0 失败，退出码 `0`。
- 全量 Release：8 个测试包通过，`LUTSharedUITests` 163、`LUTProjectTests` 64、`LUTPreviewTests` 94、`LUTJobsTests` 72、`LUTFormats` 61、`LUTCore` 236、`LUTCatalog` 24、`LUTAnalysis` 54，共 768 项，其中 **766 项通过、2 项跳过、0 失败**。跳过项为 LUTFormats 中既有 `.labin` 研发夹具和公开 NCP 样本。

日志与 SHA-256：

- `artifacts/2026-10-04-lutanalyst-tetrahedral-inverse/targeted-debug.log`：`d7476f731d0a3b5271f293fbc2ebb9eb1e014b3b2c4d7f0920ad4d27b60ceb36`
- `artifacts/2026-10-04-lutanalyst-tetrahedral-inverse/targeted-release.log`：`45d7531731f7d22d9ebde1d3b8cde9f9bba2ce132ef0abd6eea3854c1c497a9a`
- `artifacts/2026-10-04-lutanalyst-tetrahedral-inverse/full-release.log`：`d2bd734e0415ee5de5ff4dea86ea8c1788545d128480016c9ad191e428d65ab4`

## 未覆盖范围

这只关闭了当前 tetrahedral 分区的可穷举诊断子集，不等于任意 3D LUT 的连续全局唯一性证明，也不接通 tricubic／trilinear 反求、自动 TF／颜色分离、完整重建、导出计划、项目持久化或目标软件往返。跨四面体边界的连续平面多解、采样噪声下的稳定性和带 shaper 的组合反求仍保持显式未完成。9 个 `.labin`、45 个直接查表注册、HDR／ICC 其余范围、UI、设备和发布验收不变；FULL-05、H10 与 Goal 继续保持 `active`。

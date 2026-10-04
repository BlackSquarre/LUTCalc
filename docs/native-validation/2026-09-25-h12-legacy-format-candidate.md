# H12 旧设置格式候选阶段验收

日期：2026-09-25。范围：为旧版 `.lutcalc` 单文件只读检查增加现有原生 writer 可表达格式的候选映射；不开放旧项目转换，不把候选识别写成 H12/FULL-08 完成。

## 失败契约与实现

先在 `LegacySettingsContractsTests` 增加精确格式名、MLUT/grade 分支和不支持方言拒绝契约。实现后，`LegacyMappedSettings` 新增：

- `outputFormat: String?`
- `outputFormatIsMLUT: Bool?`

仅在版本已识别、`formats.grading` 为严格布尔值且对应标题精确匹配现有原生 writer 时报告候选：

| 旧标题 | 原生候选 | 分支 |
| --- | --- | --- |
| `SPI 3D (.spi3d)` | `spi3d` | grade |
| `SPI 1D (.spi1d)` | `spi1d` | grade |
| `DaVinci Resolve 1D (.ilut)` | `ilut` | grade |
| `DaVinci Resolve 1D (.olut)` | `olut` | grade |
| `Assimilate 1D (.lut)` | `lut` | grade |
| `Varicam 3D MLUT (.vlt)` | `vlt` | MLUT |

Resolve/CUBE 方言、未知标题、缺失分支和类型不严格的输入继续留在 `unmappedPaths`。`canMigrate` 固定为 `false`，候选不会创建原生项目或改变导出行为。

## 验证

- 定向 `LegacySettingsContractsTests`：14 项通过，覆盖成功候选、未知/方言拒绝、数值候选、域候选、曲线/色域候选及重复键防护。
- Release 完整回归：157 项 Swift XCTest 通过；macOS、iOS Simulator、iOS generic Release 构建和三个 App 包资源审计通过。
- 批处理接入后的完整 Release 日志：`/tmp/lutcalc-h12-format-batched-release-20260925.log`，SHA-256：`46976acf9bf2d9a9c5c9bf1502e74d244a53387a8856428a48dd4af737104f5f`。

发布证据检查仍拒绝通过，因为真实 `docs/native-validation/full-scope-acceptance.json` 尚不存在；没有伪造该清单。旧格式的全部方言、目标软件导入、Files 独立读回/取消、完整 H12 迁移和真机新增验证仍未完成。

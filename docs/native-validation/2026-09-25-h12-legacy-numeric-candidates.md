# H12 旧设置位深与精度候选阶段验收

日期：2026-09-25。状态：旧 `.lutcalc` 只读检查的数值字段候选已增加；不开放迁移，也不创建原生项目。

## 先失败的契约

先加入两个 `LegacySettingsContractsTests`：

- `lutBox.inBits` 与 `lutBox.outBits` 必须是相同的严格整数，并且只能是原生当前支持的 8、10、12 位；
- `generateBox.precision` 必须是 3–128 的严格整数。

定向 Release 编译按预期失败，因为 `LegacyMappedSettings` 尚无 `rangeBitDepth` 和 `decimalPrecision` 字段。失败日志：`/tmp/lutcalc-h12-numeric-red-20260925.log`；SHA-256：`9aa5bee6431e0c181d6ddc5d99dcd72e2672ffeb4cf822a459c8708e980e0f90`。

## 实现与边界

- `LegacyMappedSettings` 新增只读候选 `rangeBitDepth`、`decimalPrecision`。
- 位深只有在输入和输出相等、类型不是布尔值、且属于 8/10/12 时才映射；不一致、非整数和未支持位深保持未映射。
- 精度只有在严格整数且处于 3–128 时才映射；缺失、非整数和越界保持未映射。
- 候选仅进入报告的 `mappedPaths` 和 `mappedSettings`，不写入 `ProjectManifest`；`canMigrate` 继续固定为 `false`。
- 旧相机、调节、格式方言和完整 legal 数值链仍未转换，不能由本候选推断迁移可用。

## 定向验证

`LegacySettingsContractsTests` 共 12 项通过，覆盖合法位深/精度、位深不一致、非整数、越界值、重复键、范围、网格、域和精确曲线/色域候选。

`LUTProjectSessionChecks` 同步覆盖旧报告字段保留和“不宣称转换”断言，命令退出码为 0。

## 批量回归与平台构建

执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash tools/native-validation/verify-native-release.sh`，沿用一次 Release 构建后批量运行全部契约与 33³/65³ 检查：

- Swift Release XCTest：154 项通过，0 失败；
- 旧 Node 契约、Python 资源审计及既有数值逐节点检查通过；
- macOS、iOS Simulator、iOS generic Release 构建均 `BUILD SUCCEEDED`；
- 3 个 App 包资源审计通过；
- 发布入口最终退出码为 2，唯一直接原因仍是缺少真实 `docs/native-validation/full-scope-acceptance.json`，未伪造清单。

完整日志：`/tmp/lutcalc-h12-numeric-release-20260925.log`；SHA-256：`31192dbe722a2e68a75143fad992c3903266fae394ff8a387111c0e6ff924708`。

## 未完成项

旧 JSON 的相机、调节、格式/方言、精度实际写出语义、版本迁移、iOS Files/File Provider 和完整 H12/FULL-08 仍未完成。真机工作按用户安排集中到最后执行。

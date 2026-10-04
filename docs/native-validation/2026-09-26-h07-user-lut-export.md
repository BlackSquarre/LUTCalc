# H07 用户 LUT 原始导出阶段验收

日期：2026-09-26。范围：已主动导入并保存到原生 `.lutcalc` 项目的用户 LUT，经过 SHA-256 校验后从项目资源导出原始字节，并接入 SwiftUI 系统文件导出面板。本项不把用户 LUT 当作内置算法，也不把它接入尚未定义顺序的 19 阶段 `TransformPlan`。

## 实现与契约

- `LUTProjectDocument.StoredUserLUTExport` 是 Swift `FileDocument`，只携带项目中已验证的原始字节和原始扩展名建议文件名。
- 导出前重新核对项目资源角色、资源存在性及 SHA-256；没有用户 LUT 时返回 `noImportedLUT`，资源被篡改时返回 `assetHashMismatch`。
- `ProjectDocumentView` 增加“导出项目中的原始 LUT”，使用 `.fileExporter` 和系统 `.data` 类型；实际扩展名由项目资源名保留。没有加入 WebView、JavaScriptCore、采样数组或颜色计算路径。
- 先失败的契约验证了包级重开后导出字节缺失；实现后从带用户 LUT 的项目导出，文件字节与导入原始字节逐字相同。无用户 LUT 的项目导出入口报明确错误。

## 文件与工具链

修改文件及 SHA-256：

- `Native/Packages/LUTKit/Sources/LUTSharedUI/LUTProjectDocument.swift` — `d7536941f96c3f64faf2bc514e19762341b16575434daf6865750741e1b0f04a`
- `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift` — `2a67555664e8640bbf00d255172ec4f62b207a554067f08f5e9ddbfa542f2ced`
- `Native/Packages/LUTKit/Tests/LUTSharedUITests/UserLUTProjectAssetContractsTests.swift` — `a885a2ac71049d1c9a09844d87570ed0fc40aa5a68b7cfb835f70be114a4b8e0`

工具链：Xcode 27.0（27A266a）、Apple Swift 6.4、macOS/iOS SDK 27.0、Apple Silicon Mac。测试日志：定向 `/tmp/lutcalc-userlut-export-ui-build2-20260926.log`（SHA-256 `41b1eb4954188f0331949f324bb48d8ce168754a4132991a72c7c6e96772181d`）；完整入口 `/tmp/lutcalc-userlut-export-release-20260926.log`（SHA-256 `9d3286b6569ccd9ae10e9ae0728e7fa5813c39bdf94b1abe4f62cc2055c1b920`）。

## 实际验证

| 命令 | 结果 |
| --- | --- |
| `swift test --package-path Native/Packages/LUTKit -c release --filter UserLUTProjectAssetContractsTests` | 6 项通过，包含普通资源不阻塞生成、用户 LUT 原始导出、篡改拒绝和无资源错误。 |
| `bash tools/native-validation/verify-native-release.sh` | 原生子集通过；7 个独立公式检查、46 个 33³/65³ CUBE 生成/读回对通过；Swift 测试清单 246 项；macOS、iOS Simulator、iOS generic Release 构建及 3 个 App 包资源审计通过。 |

完整脚本总退出码仍为 2，唯一末端阻塞是缺少真实 `docs/native-validation/full-scope-acceptance.json`；这不是本项伪造的发布清单。真实 Finder/Files 保存回调、File Provider、iPhone/iPad 真机导出交互仍未完成；用户 LUT 参与颜色生成的组合语义也保持拒绝，避免猜测处理顺序。

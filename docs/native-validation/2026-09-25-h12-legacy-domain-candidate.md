# H12 旧设置输入域候选映射阶段验收

日期：2026-09-25。范围：为旧版 `.lutcalc` 单文件只读检查补充 `lutBox` 输入域候选；不开放旧项目转换，也不宣称 FULL-08 或 H12 完成。

## 证据与边界

旧版 `js/gamma.js` 的 `LUTGamma.setParams` 在 `scaleCheck` 为严格布尔 `true` 且存在两个数值时，把网格坐标 `k` 按 `k * (scaleMax - scaleMin) + scaleMin` 映射后再进入曲线；`inCalcRGB` 和 `oneDCalc` 对 RGB/1D 坐标使用同一线性域变换。原生 `LUTDomain` 以三个通道的最小/最大值表示采样输入域，因此仅对三个通道相同的标量边界提供只读候选。

- 仅在已识别 `v4.09`/`v4.10`、`legalIn/legalOut` 为严格 JSON 布尔值、`scaleCheck` 为严格 `true`、`scaleMin/scaleMax` 为有限 JSON 数值且 `scaleMin < scaleMax` 时，报告 `mappedSettings.inputDomain`。
- 候选域使用同一标量边界复制到 R/G/B；`scaleCheck:false`、缺字段、布尔/数字混用、非有限或反向边界保持未映射。
- `canMigrate` 继续固定为 `false`。候选不创建 `ProjectManifest`，也没有证明旧版完整 legal 数值链与原生全管线等价。

## 契约验证

先加入两个失败契约：一个要求严格有限递增边界产生 `inputDomain`，一个覆盖关闭、反向和类型混用拒绝；首次 Release 编译因 `LegacyMappedSettings` 尚无 `inputDomain` 字段失败。随后新增可选 `LUTDomain` 候选和严格有限数值门控。

实际命令：

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Native/Packages/LUTKit -c release --filter LegacySettingsContractsTests
```

结果：8 项通过、0 失败（2026-09-25）。

## 修改与未覆盖

- `Native/Packages/LUTKit/Sources/LUTProject/LegacySettingsInspector.swift`：只读报告增加 `inputDomain` 候选，严格拒绝不确定数值。
- `Native/Packages/LUTKit/Tests/LUTProjectTests/LegacySettingsContractsTests.swift`：新增 2 项候选映射/拒绝契约。

验收时 SHA-256：检查器 `28fbf4c11e0df7a473b8865273f8ecd704691e6156e507a8da1608be110b2845`；契约 `412ca9f3889786368edbf624c0731fbd4b2fbd825dd9f1cc57abcb6b724c9005`。旧版输入域来源 `js/gamma.js` 与保存字段来源 `js/lutlutbox.js` 未修改。

旧曲线/色域名称、调节链、相机与格式预设仍无法无损映射；版本迁移、旧 legal 数值链等价、双端文件交互仍未验收。完整发布入口需由主任务在最终源码上重跑。

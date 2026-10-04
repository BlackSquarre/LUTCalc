# H12 旧设置曲线与色域候选映射阶段验收

日期：2026-09-25

## 范围

本阶段继续保持旧 `.lutcalc` 单文件只读检查，不创建 `ProjectManifest`，不开放迁移。仅当 `gammaBox.recGamma` 与 `gammaBox.recGamut` 同时逐字匹配当前 Swift 注册表时，报告输入曲线/色域候选；输出曲线/色域同理。任一名称未知、变体或缺失时，整对字段保持未映射，避免把近似名称或厂商别名静默替换为另一算法。

示例：`D-Log2` + `D-Gamut2` 映射为 `.djiDLog2` + `.djiDGamut2`；`Linear scene` + `ACES AP0` 映射为 `.linearScene` + `.acesAP0`。候选值只出现在报告中，`canMigrate` 仍固定为 `false`。

## 契约与实现

先加入两个失败契约，首次 Release 编译因 `LegacyMappedSettings` 尚无四个候选字段失败，日志为 `/tmp/lutcalc-h12-gamma-candidate-red-20260925.log`。随后在纯 Swift `LegacySettingsInspector` 中复用 `AlgorithmCatalog.builtIn()` 做精确名称查找，并增加：

- `inputTransfer` / `outputTransfer`
- `inputSpace` / `outputSpace`
- 成对字段的路径标记
- 未知名称保持 `unmappedPaths`

定向 `LegacySettingsContractsTests` 共 **10 项通过**，包含重复键、范围/网格/域候选、精确曲线/色域候选和未知名称拒绝。

## 证据哈希

```text
fab357c462cf6de7750c4c1e175d7b4cb89c9f2cac41943d5a2683ba8a260634  Native/Packages/LUTKit/Sources/LUTProject/LegacySettingsInspector.swift
d2f07f5681c54a754ddb97be0f216d125285b6b4804791858d90d15217722dbd  Native/Packages/LUTKit/Tests/LUTProjectTests/LegacySettingsContractsTests.swift
```

## 状态边界

这只是旧字段的只读候选识别，不是旧设置迁移。旧调节链、相机、格式/精度、旧 legal 数值链等仍未证明与原生计划等价；未知字段继续阻止迁移，真机 Files/File Provider 和完整 H12/FULL-08 仍未完成。

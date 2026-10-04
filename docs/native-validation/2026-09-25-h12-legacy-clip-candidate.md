# H12 旧设置硬剪裁字段只读候选验收

日期：2026-09-25

## 范围

本阶段继续只读取旧 `.lutcalc` JSON，不创建 `ProjectManifest`，不开放迁移。旧版 `js/lutlutbox.js:getSettings` 会把硬剪裁选择写入 `lutBox.clipOption`，把“0%-100%”开关写入 `lutBox.clipLegal`。原生 `TransformPlan` 尚未实现旧版硬剪裁阶段，因此本阶段只在检查报告中暴露候选值，`canMigrate` 仍固定为 `false`。

## 先失败的契约

新增 `LegacySettingsContractsTests` 的两个契约，要求四个已知选项可报告、未知数值和非严格类型拒绝。首次 Release 定向编译按预期失败，因为 `LegacyMappedSettings` 尚无 `LegacyClipMode`、`clipMode` 和 `clipLegalRange`，日志：

```text
/tmp/lutcalc-h12-clip-red.log
SHA-256: 44ca70a79f75484275d0ae542a7b215d86cfbcfed7a4881f36d86a82a6056542
```

## 实现边界

- `LegacyClipMode` 严格识别 `0=unclipped`、`1=bothBlackAndWhite`、`2=blackOnly`、`3=whiteOnly`。
- `clipOption` 只有严格整数且属于 0–3 时才进入 `mappedPaths`；布尔、非整数、越界值保持 `unmappedPaths`。
- `clipLegal` 只有真正 JSON 布尔值才进入 `mappedPaths`；它与剪裁选项一样只是报告候选。
- 候选不进入 `TransformSettings`、不改变计算/导出、不写入项目包；未知的旧硬剪裁算法仍阻止迁移。

## 定向验证

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --package-path Native/Packages/LUTKit -c release \
  --filter LegacySettingsContractsTests
```

结果：`LegacySettingsContractsTests` **24 项通过，0 失败**；包括四个选项、越界/小数/布尔类型、`clipLegal` 类型和既有旧字段边界。日志：

```text
/tmp/lutcalc-h12-clip-green.log
SHA-256: 34c150d953462e8c0f8402eac846cdff0698df470c6f614b3bab7d7e2fb79410
```

对应 `LUTProject` Release 目标构建也通过，日志 `/tmp/lutcalc-h12-clip-build.log`，SHA-256：`79c96dde48bb32ec9f25ac1775b2b2d55fa4dc8cd08c345e6580de01f0b8bba3`。

源码 SHA-256：

- `Native/Packages/LUTKit/Sources/LUTProject/LegacySettingsInspector.swift`：`089211bcf67113b73395cc059e24ee880bd1537af75dcc6cb8d2ad2b45c95410`
- `Native/Packages/LUTKit/Tests/LUTProjectTests/LegacySettingsContractsTests.swift`：`27c5f5ce321db3f3b0ed64b6c585e29b1722c887938017b1498663794d778105`

## 未完成项

旧硬剪裁阶段的数值等价、所有调节算法、相机身份、格式方言、版本迁移和项目创建仍未完成；本阶段不勾选 H12、FULL-08 或发布门槛。真机与 Files/File Provider 验证按既定安排最后集中执行。

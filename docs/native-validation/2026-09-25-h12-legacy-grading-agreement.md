# H12 旧设置 grading 一致性阶段验收

日期：2026-09-25。

## 证据范围

旧版 `js/lutlutbox.js:getSettings` 与 `js/lutformats.js:getSettings` 都读取同一个 `lutUsage` 单选控件：前者把值保存为 `lutBox.grading`，后者把值保存为 `formats.grading`。因此两个字段同时存在时，只有严格布尔且值一致，输出格式候选才有可验证的依据。

本阶段只读检查旧 JSON，不创建 `ProjectManifest`，`canMigrate` 继续固定为 `false`。

## 先失败后通过

先加入三个 `LegacySettingsContractsTests`：

- 两个字段一致时，输出格式候选应同时报告 `lutBox.grading` 与 `formats.grading`；
- 两个字段冲突时，拒绝输出格式候选，并保留相关路径在 `unmappedPaths`；
- `lutBox.grading` 使用数字而非 JSON 布尔时，同样拒绝候选。

首次 Release 定向运行中，旧检查器仍会把冲突输入识别为 `spi3d`，且没有报告 `lutBox.grading`，测试按预期失败。

## 实现与边界

`LegacySettingsInspector` 现在在支持格式候选判定中加入以下门控：

- `lutBox.grading` 缺失时，保持既有旧样本兼容，仍可仅依据 `formats.grading` 判定；
- 两字段都存在时，要求两者均为严格 JSON 布尔且值相等；
- 一致时把 `lutBox.grading` 加入 `mappedPaths`；
- 冲突或类型不严格时，格式标题、两处 grading 字段均保持未映射，不产生 `outputFormat` 或 `outputFormatIsMLUT` 候选。

没有改变任何旧 JavaScript、格式 writer、原生项目模型或 `canMigrate` 状态。

## 验收命令

工具链：Apple Swift 6.4（swift-driver 1.168.6，macOS 27 SDK）。

```sh
swift test -c release --package-path Native/Packages/LUTKit --filter LegacySettingsContractsTests
swift run -c release --package-path Native/Packages/LUTKit LUTProjectSessionChecks
```

结果：`LegacySettingsContractsTests` 22 项通过、0 失败；`LUTProjectSessionChecks` 通过。定向日志：`/tmp/lutcalc-h12-grading-agreement-release-20260925.log`，SHA-256：`d0a3bb5cb8aee39da1dd50c5f8d4c3c91ed5d79cf67083229a27df6e571e1236`。

源码 SHA-256：

- `Native/Packages/LUTKit/Sources/LUTProject/LegacySettingsInspector.swift`：`405d7af5c0fcb5275aaefa5625cf40ad0f77101ffce0727efe723c55ddbb1ab4`
- `Native/Packages/LUTKit/Tests/LUTProjectTests/LegacySettingsContractsTests.swift`：`e03420f78ccdff8c3935e1a4167acb96f123e41dce471d80ccce13d97c362132`
- 证据来源 `js/lutlutbox.js`：`c63db842b8585b2d8949c0bb7b0ef36b854b2573490a4b0d55682ac03eda8a60`
- 证据来源 `js/lutformats.js`：`f197be83d3071f927ff682be9970b4efdddb94e8eddea11b466df14118c46dab`

## 未完成边界

这只是重复序列化字段的一致性检查，不证明旧设置完整无损迁移。相机身份、调节算法、格式方言、版本迁移、iOS Files/File Provider、真机交互和完整 H12/FULL-08 仍未完成；`canMigrate` 保持 `false`。

# H12 旧 App 设置迁移移除验收

日期：2026-09-25。状态：**已从原生应用范围删除；不是待完成功能。**

用户决定不再支持任何旧 LUTCalc 网页 App 的单文件 JSON 设置迁移。原生应用不读取、识别、分析、候选映射、无损转换或导入旧版 `version`/`lutBox`/`gammaBox` 等设置；这部分不属于 Goal、H12 或 FULL-08 的待办。

## 当前代码边界

- 当前 Swift 源码不包含旧设置检查器、候选报告、映射模型、迁移入口或 `canMigrate`。
- `ProjectCodec` 只解析原生 `.lutcalc` 项目清单；旧网页 JSON 不是原生项目，必须拒绝且不创建项目、不复制资源。
- 原生项目自身的 schema 兼容规则独立保留：schema v1 的原生包可按既定 `assetRoles` 规则读入并规范化为当前 schema；这不读取旧网页 App 设置。

## 契约验证

新增回归 `ProjectContractsTests.testExternalLegacyAppSettingsAreRejected`，批量覆盖 `v4.09`、`v4.10` 及缺失分区的旧设置形状；每个输入均由 `ProjectCodec.decode` 拒绝。

执行：

```text
swift test -c release --package-path Native/Packages/LUTKit --filter ProjectContractsTests/testExternalLegacyAppSettingsAreRejected
```

结果：1 项通过，0 失败（2026-09-25）。原生 schema v1→v2 契约仍由 `ProjectContractsTests` 的现有测试单独覆盖。

## 影响范围

旧 App 设置导入、无损迁移、旧设置候选映射及其契约不再追踪。原生项目保存、Files/File Provider、真机和发布门槛仍按 H12、H08/H09 与路线图继续验证；Goal 保持 active，不能据此宣称完整迁移或发布完成。

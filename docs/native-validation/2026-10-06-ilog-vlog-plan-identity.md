# I-Log 与 V-Log 计划身份验收

## 范围

修正 `TransformPlan.planVersion` 对 I-Log 与 V-Log 返回固定短身份的问题。新身份包含输入 transfer ID、输出 transfer ID、输入色域 ID 和输出色域 ID，避免正反方向或色域组合共用计划缓存身份。未改动 transfer 公式、生成精度、网格、量化或阈值。

## 契约与结果

先增加方向与色域契约，再运行旧实现作为红测。旧实现下 `ILogContractsTests` 与 `VLogPlanIdentityContractsTests` 暴露 8 个身份断言失败，具体表现为相反方向及不同色域仍返回 `minimal-ilog-v1`／`minimal-vlog-v1`。

修复后执行：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter 'ILogContractsTests|VLogPlanIdentityContractsTests|CatalogTransferSmokeTests'
```

结果：Release 构建成功；`ILogContractsTests` 4 项、`VLogPlanIdentityContractsTests` 2 项、`CatalogTransferSmokeTests` 1 项通过，合计 7 项、0 失败。I-Log 已有独立标量样本契约仍通过，最大允许误差 `2e-12`；本次不更改公式，故没有新增算法误差数据。

工具链：Xcode 27.0（27A266a），Apple Swift 6.4.0.34.1，arm64 macOS。

`git diff --check` 通过。

## 未覆盖

本验收只关闭 I-Log/V-Log 的方向及色域计划身份冲突；未覆盖其他 transfer 家族的全局身份审计、数值独立参照、`.labin` 替代、直接查表替代、全根证明、ICC/HDR、平台验收或发布验收。Goal 继续保持 `active`。

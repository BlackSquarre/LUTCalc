# F-Log2 非 C 与 legacy 方向身份验收

## 目的

避免 F-Log2 published、F-Log2 C 与 LUTCalc legacy 计划因 encode/decode 方向或输入／输出色域不同而复用同一 `planVersion`。本项只修复计划身份，不改变传递函数、矩阵、Double 生成路径或数值阈值。

## 契约与实现

- 在 `FLog2ContractsTests` 中固定 published 非 C、F-Log2 C 和 legacy 身份必须包含输入／输出 `TransferID` 与两端 `ColorSpaceID`。
- 新契约比较 published 与 legacy 两种 transfer 的 encode/decode 方向，要求 `planVersion` 不同，并检查两端 transfer 和色域 ID 都存在。
- `TransformPlan.basePlanVersion` 对 `minimal-flog2-v1`、`minimal-flog2c-v1`、`minimal-flog2-legacy-v1` 三分支均编码完整 transfer 对和色域对。

## 验证

- 工具链：Xcode 27.0 (Build 27A266a)，Apple Swift 6.4.0，arm64 macOS。
- 定向命令：`swift test --package-path Native/Packages/LUTKit -c release --filter 'FLog2ContractsTests'`。
- 结果：`FLog2ContractsTests` 执行 11 项、失败 0，退出码 0。覆盖 transfer 分段数值、非有限拒绝、published/legacy 公式路径、C gamut 双端身份及本次新增的非 C/legacy 正反方向身份契约。
- 首次尝试时，共享 SwiftPM 构建遇到其他工作包正在编辑的 `ILogContractsTests.swift` 和 `VLogPlanIdentityContractsTests.swift` 编译错误，测试未运行；待并行编辑稳定后相同定向命令构建并通过。未修改这两个文件。
- `git diff --check` 对本工作包的 Swift 源和测试文件通过。

## 未覆盖

本次没有运行完整 SwiftPM 套件，也未重做全局 `TransformPlan` 参数身份审计。其他 transfer 家族、UI、平台／真机、格式互操作和发布验收不在本工作包结果内；全量迁移 Goal 继续 `active`。

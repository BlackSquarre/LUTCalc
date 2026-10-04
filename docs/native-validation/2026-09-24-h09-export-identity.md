# H09 导出身份隔离阶段验收

日期：2026-09-24。状态：阶段通过，H09/FLOW-02/FLOW-03 尚未完成。

## 契约与实现

先在 `LUTSessionChecks` 加入确定性挂起的导出服务：旧项目发起导出后打开另一个项目，再让旧任务分别成功和失败。两种旧结果均不得提交到新项目的 `exportStatus` 或 `lastExport`，旧任务的临时输出必须清理。契约先因 `ExportService` 和注入构造器尚不存在而编译失败。

`EditorSession` 随后增加可注入的 `ExportService`，默认实现仍使用原有 `GenerationCoordinator` 和 `FileCubeSink`。每次导出记录请求 ID 与文档 ID；打开项目使旧请求失效。异步任务返回后先核对身份，再更新状态或结果；过期任务清理其输出。用户 LUT 尚未接入变换计划时，导出前的错误仍显示为失败状态。

## 修改文件与源码版本

| 文件 | 内容 | SHA-256 |
| --- | --- | --- |
| `Native/Packages/LUTKit/Sources/LUTSharedUI/EditorSession.swift` | 导出服务注入、请求与文档身份门控、过期输出清理 | `31a30655f82d3b1e294bbccfa169e02e4faa527345776b5b1ad033651f96817f` |
| `Native/Packages/LUTKit/Sources/LUTSessionChecks/main.swift` | 挂起后切换项目、旧成功/失败、未支持用户 LUT 错误契约 | `6ca9c698499b1c73525953741bbab74ba205ee0d026b407f52b19ee2c8575456` |

## 实际验证

- 工具链：Apple Swift 6.2.1，arm64 Command Line Tools；无完整 Xcode/iOS SDK。
- `swift build --package-path Native/Packages/LUTKit --product LUTSessionChecks` 在契约先行时退出码 1，缺少 `ExportService` 和注入构造器；实现后 `swift run --package-path Native/Packages/LUTKit LUTSessionChecks` 退出码 0。
- `tools/native-validation/verify-native-subset.sh > /tmp/lutcalc-h09-export-identity-20260924.log 2>&1` 退出码 0。静态边界覆盖 39 个 Swift 源文件，旧 Node 9 项通过；新身份契约在 Release 通过，其他现有原生子集契约通过。此项无新的数值误差，原有数值门槛未改。

## 未覆盖范围

项目切换后的旧任务目前以身份门控保证正确性，仍可能继续消耗计算直到结束；草稿 UI 尚未提供项目切换入口和任务主动取消接线。系统文件授权、分享、多窗口、完整 Xcode 构建、XCTest、模拟器及真机验证未执行。任务完成状态仅说明当前受测子集，不能视为完整迁移或发布通过。

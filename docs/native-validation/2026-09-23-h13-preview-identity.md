# H13 预览身份门控阶段验收

日期：2026-09-23。状态：阶段通过，H13 尚未完成。

## 契约

依据[运行契约](../native-swift-runtime-contracts.md)，预览请求和结果带有 `documentID`、`revision`、`requestID`、`planVersion`。结果和错误只有四项与当前活动会话完全相同才可提交；关闭文档后，即使标识相同也不可提交。请求创建时核对计划版本，避免标识与实际算法设置脱节。

## 修改

| 文件 | 内容 | SHA-256 |
| --- | --- | --- |
| `Native/Packages/LUTKit/Sources/LUTPreview/CPUPreview.swift` | 四字段身份、计划版本校验、活动状态门控及每文档请求会话 | `81a9fddecabc5f6c7eccec7904489040d6f7eb968a00ed5cf8e936e8e16e1f18` |
| `Native/Packages/LUTKit/Sources/LUTPreviewChecks/main.swift` | 同号不同文档/请求/计划、过期修订、后发请求、关闭状态和版本不符契约 | `684f0846a6cc109890ddc7e27ff9b53f98895e7a9be3a694c61e4ffe5bd6a61b` |
| `Native/Packages/LUTKit/Tests/LUTPreviewTests/PreviewContractsTests.swift` | XCTest 对应契约；完整 Xcode 环境待运行 | `5da1502902ae347760118840e4e363ee1601fb8c92d5db3efb2954e5e1124f9a` |

## 实际验证

- Apple Swift 6.2.1，arm64 Command Line Tools。
- 先修改可执行契约，`swift build --package-path Native/Packages/LUTKit --product LUTPreviewChecks` 因身份类型及接口缺失而失败；随后实现。
- 再增加“同一修订的慢请求 A 晚于快请求 B”和“关闭后旧结果返回”契约，`swift build --package-path Native/Packages/LUTKit --product LUTPreviewChecks` 因会话类型缺失而失败；随后实现。
- `swift run --package-path Native/Packages/LUTKit LUTPreviewChecks` 退出码 0；通过 Double 像素取样、alpha 处理、四字段匹配、同修订后发请求替换、逆序修订拒绝及关闭状态检查。
- 最终运行 `tools/native-validation/verify-native-subset.sh > /tmp/lutcalc-h13-session-validation-20260923.log 2>&1`，退出码 0；包括 Release 包构建、CUBE、项目、任务、旧引擎及 Node 既有回归。未改冻结夹具或阈值。

## 尚未覆盖

当前只提供纯 Swift 请求会话及结果提交判断；真实异步预览任务、UI 会话关闭通知与错误显示尚未接线。图像解码、ICC/显示空间、Core Image、双平台 App 构建和真机验证均未完成，不计 FLOW-05/UI-03/UI-04 通过。

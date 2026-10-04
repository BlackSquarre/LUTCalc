# 2026-10-04 算法计划身份与批次指纹接线验收

## 范围

本工作包修复已有算法路径的计划身份碰撞。此前 `TransformPlan.basePlanVersion` 的通用回退会让 `null.lutcalc-legacy.v1`、`linear.scene.v1` 和未命中专用分支的路径共享 `minimal-dlog2-v1`，从而可能让生成结果标题、预览身份、批次检查点和请求指纹混淆。修复只改变稳定身份字符串，不改变任何 Double 数值、网格、位宽、插值或阈值。

## 契约先行与实现

新增 `NullTransferContractsTests.testPlanIdentityDoesNotAliasNullOrSceneLinearWithDLog2`，要求：

- D-Log2 默认身份仍为 `minimal-dlog2-v1`；
- Null legacy 身份为 `analytic-null-legacy-v1`，并保留 `completeV2` 输出码值后缀；
- 纯 scene-linear 身份为 `minimal-linear-scene-v1`；
- 三者互不相等。

首次契约在旧实现上失败：Null 和 scene-linear 会落入错误的 D-Log2 回退身份。实现后只在输入与输出同为 Null 或同为 scene-linear 时使用独立身份；混合链路也绑定输入／输出 TransferID，不能回退到 D-Log2 身份。性能探针的实际 `djiDLog2 → linearScene` 链路因此固定为 `minimal-linear-scene-v1:dji.dlog2.v1:linear.scene.v1`。

批次指纹包含 `planVersion`。因此纯 linear 3DL 批次的指纹从历史冻结值
`053beb449842948f76f1df1954d3a4af950cdbc61cbabd1b1987be9dc49e86cc`
变为
`14203e2798be5c95c73957c75a3648755c152294791b449a728e04fd1a5f55f8`。
旧检查点不会被静默复用，会按指纹不匹配拒绝恢复。

## 验证

工具链：Xcode 27.0（Build 27A266a），Apple Swift 6.4，arm64 macOS 27.0。

定向 Debug 命令：

```sh
swift test --package-path Native/Packages/LUTKit --filter NullTransferContractsTests
```

结果：4 项通过、0 失败；日志 `/tmp/lutcalc-plan-identity-null-debug-20261004-r3.log`。

定向 Release 命令：

```sh
swift test -c release --package-path Native/Packages/LUTKit --filter NullTransferContractsTests
```

结果：4 项通过、0 失败；日志 `/tmp/lutcalc-plan-identity-null-release-20261004-r3.log`，SHA-256 `c063fcc88d8144f0c20ae884e40b3ec5c07c90f6d422bd11ecd1bce2069781bb`。

性能探针身份回归：

```sh
swift test --package-path Native/Packages/LUTKit --filter DevicePerformanceProbeContractsTests
swift test -c release --package-path Native/Packages/LUTKit --filter DevicePerformanceProbeContractsTests
```

结果：Debug、Release 各 7 项通过、0 失败；日志 SHA-256 分别为 `093d7c10843529c8d233df89cdc3a6d0bdc971e86a90257a131a87b5b4c5a1a9`、`75a4cbb587be9ce8a0c7a8d594a3edd6e0840a0b99acb79d72cee1fd002906b3`。原有测试把混合链路错误冻结为 `minimal-dlog2-v1`，已改为实际稳定身份；未改变采样、Double 计算或校验和。

定向 Debug 交叉检查同时覆盖性能探针、批次指纹和 Null 契约，共 8 项通过、0 失败。

完整 Release 命令：

```sh
swift test -c release --package-path Native/Packages/LUTKit
```

结果：8 个 XCTest 包共执行 `694` 项，`0` 失败；LUTFormats 的旧 `.labin` 和 NCP 外部夹具各 1 项按原规则跳过。日志 `/tmp/lutcalc-plan-identity-full-release-20261004-r4.log`，SHA-256 `c8580715fe73c0b4e13534e29f278f929002619f0dfa70f197428867ef35ff44`。

共享包的 macOS、generic iOS 和 generic iOS Simulator Release 构建均生成产品，DerivedData 分别为 `/tmp/LUTCalcPlanIdentityMacDD`、`/tmp/LUTCalcPlanIdentityIOSDD` 和 `/tmp/LUTCalcPlanIdentitySimDD`。构建期间 CoreSimulator 服务报告内存不足警告；未把它扩展为模拟器运行或 UI 证据。

源码与契约 SHA-256：

- `Native/Packages/LUTKit/Sources/LUTCore/TransformPlan.swift`：`7ae3086e4a158173428c75865ec3a40cc64a1058b1d759f97390955e816cc738`
- `Native/Packages/LUTKit/Tests/LUTCoreTests/NullTransferContractsTests.swift`：`7a4a9b9311ee603f7e9299c15c51150271fdc79dd11110cda7789690510ce783`
- `Native/Packages/LUTKit/Tests/LUTSharedUITests/ExposureBatchThreeDLFlavorContractsTests.swift`：`aa19078a8f1fb1907001dd211af2b905f5d076a7c9bb661b7d1d64d74d41ffc7`
- `Native/Packages/LUTKit/Tests/LUTSharedUITests/DevicePerformanceProbeContractsTests.swift`：`d10499052d762e30fee3c8eac56412fa78f8d130f9a394c111ff198651a9b370`

## 未覆盖

本包只修复稳定计划身份和批次指纹接线，不代表完整相机模型、全部算法公式、查表替代、`.labin` 替代、HDR/OOTF、ICC、LUTAnalyst 任意 3D 逆、格式第三方往返、File Provider、UI、真机性能预算或签名发布完成。Goal 保持 `active`。

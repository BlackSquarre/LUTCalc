# 2026-10-04 LUTAnalyst cubic 平台区间诊断验收

## 范围

本轮只修正已有一维 cubic inverse 诊断在恒值平台上的状态表达。用户导入的一维 LUT 在目标值落在连续平台时，解不是若干离散点；报告必须保留平台区间并返回 `nonUnique`。孤立根和既有非单调 hump 多根继续保留。没有实现任意三维逆、自动分离或内置查表替代。

## 契约先行与实现

新增契约 `testTransferInverseRootsExposeConstantPlateauAsNonUniqueInterval`：构造六节点一维 LUT，目标值在中间恒值平台，要求三个通道均为 `nonUnique`，平台区间为 `0.4...0.6`，平台外孤立根继续存在。先行编译暴露报告缺少区间字段，随后增加 `TransferInverseRootDiagnostic.nonUniqueBrackets`；`LegacyCubicCurve1D.allInverseRoots` 识别并合并恒值区间，同时过滤平台内重复端点根。

## 实际验证

工具链：Xcode 27.0（27A266a）、Swift 6.4（swiftlang 6.4.0.34.1），macOS arm64。

定向命令：

```sh
swift test -c debug --package-path Native/Packages/LUTKit \
  --filter ImportedLUTAnalysisContractsTests/testTransferInverseRootsExposeConstantPlateauAsNonUniqueInterval
```

结果：退出码 `0`，定向测试 `1` 项通过。

完整命令：

```sh
swift test -c release --package-path Native/Packages/LUTKit
```

结果：退出码 `0`，8 个测试包均通过、0 失败；LUTAnalysis 测试包 `46` 项通过。LUTFormats 中既有外部夹具跳过规则保持不变。日志未覆盖真机、目标软件或发布清单。

Release 日志：`/tmp/lutcalc-lutanalyst-plateau-full-release-20261004.log`；SHA-256：`f5bc7454b857ceee6fff8ea6a10cb88dce39d999c4f198ff1359346ad6d42cb5`。

## 未覆盖与状态

本轮只关闭一维 cubic 平台的可观察性。任意 3D LUT 逆、自动 transfer/colour 分离、完整重建、全局三维多解证明、方向/量化导出接入、9 个 `.labin`、45 个直接查表注册、Canon CP IDT、RED DRAGONColor2/IPP2、ARRI SUP2 raw、PQ OOTF、完整 HDR/ICC、UI、性能、签名和真实 `full-scope-acceptance.json` 仍未完成。Goal 保持 `active`。

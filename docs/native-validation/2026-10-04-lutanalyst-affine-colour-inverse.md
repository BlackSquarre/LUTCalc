# LUTAnalyst 显式仿射颜色模型逆验收

## 范围

本包只把已有 `KnownAffine3DTransform` 接入 `ImportedLUTAnalysisReport`。调用方必须显式提供矩阵和偏置；代码不从三维 LUT 节点拟合或推断仿射模型。没有实现任意三维 LUT 逆，也没有改变无模型入口的拒绝语义。

## 契约先行与实现

新增契约使用非对角 3×3 矩阵、偏置和 unit input domain，验证前向结果经显式模型逆变换后恢复输入。旧实现没有带 `using`／`inputDomain` 参数的 `inverseColourLUT`，定向 Release 编译真实失败；日志 `/tmp/lutcalc-affine-report-red-20261004.log`，SHA-256 `30451188411fe8b83577a4cdd07818bcd2c58f35c626652c4b0c97ed6505a2a4`。

新增入口：

```swift
report.inverseColourLUT(output,
                        using: model,
                        inputDomain: .unit,
                        outputDomain: nil,
                        tolerance: 2e-12)
```

入口要求报告确实包含颜色 LUT，并复用 `KnownAffine3DTransform.inverse` 的有限值、输入／输出域、矩阵条件和前向重建残差检查。`report.inverseColourLUT(output)` 仍抛出 `.arbitrary3DInverseUnsupported`。

## 定向验证

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  --filter 'ImportedLUTAnalysisContractsTests/testColourInverseAcceptsOnlyCallerSuppliedKnownAffineModel' \
  2>&1 | tee /tmp/lutcalc-affine-report-contract-20261004.log
```

结果：退出码 `0`，1 项通过；日志 SHA-256：
`1c096ce8d19e0b8e4bbe5836403079fdadf138e8f95bb8a7561e8a81cca08bf9`。

## 完整验证

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  > /tmp/lutcalc-affine-report-full-release-20261004.log 2>&1
```

结果：退出码 `0`；8 个 Swift 测试包共执行 `737` 项，失败 `0`，LUTFormats 的既有外部夹具 `2` 项按原规则跳过；日志 SHA-256：
`ffca6bd014c878c5e6cc4d1d8ee50909528ff9a5aa21a0c991c14bbdc27edabb`。

源码 SHA-256：

- `Native/Packages/LUTKit/Sources/LUTAnalysis/ImportedLUTAnalysis.swift`：`e3a37ab000415d782cc6e49346ee34a2650ee330db4a0c700e14344c5f2531f2`
- `Native/Packages/LUTKit/Tests/LUTAnalysisTests/ImportedLUTAnalysisContractsTests.swift`：`33ba65af2b3af472e3e15486c9a484eff10b414a99a36b30f114998cd5d2110c`

## 未覆盖范围

完整 LUTAnalyst 的 TF／颜色分离和重建、方向／量化元数据、病态模型和多解全局报告、任意三维逆、三维域外旧实现冲突、项目生成／导出接入和目标调色软件往返仍未完成。直接查表、`.labin`、Canon CP IDT、RED DRAGONColor2／IPP2、SUP2 raw、PQ OOTF、完整 HDR／ICC、UI、设备和发布清单状态不变。

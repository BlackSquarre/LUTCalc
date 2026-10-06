# ICC MPE `parf` 公式类型边界验收

日期：2026-10-05

## 范围

本轮只核对 ICC.1:2022-05 `multiProcessElementsType` 的 `cvst` 公式曲线边界。规范 Table 60 对 MPE 的 `parf` 只定义 function type 0、1、2；传统 `parametricCurveType` 的 `para` type 3、4 属于另一种 tag/曲线编码，不能移植到 `cvst`。因此新增契约固定 type 3、4 必须返回 `.unsupportedCurve("parf-3")`／`.unsupportedCurve("parf-4")`，没有新增未经规范定义的计算公式。

## 来源与实现

- 规范来源：ICC.1:2022-05，`/tmp/icc-1-2022-05.pdf`，SHA-256：`aad8e33128635893e38ae780def3b29e661e4541be03cb235c67dd94d558001b`。
- 规范位置：§10.16.2.2，Table 58–60；传统 `para` 为 §10.18，Table 67–68。
- 实现：[ICCMPETransform.swift](/Users/lingru/claude/LUTCalc/Native/Packages/LUTKit/Sources/LUTPreview/ICCMPETransform.swift)。生产代码继续只实现 MPE type 0、1、2，并拒绝未知类型。
- 契约：[ICCMPEContractsTests.swift](/Users/lingru/claude/LUTCalc/Native/Packages/LUTKit/Tests/LUTPreviewTests/ICCMPEContractsTests.swift)。

## 契约与结果

新增 `testMPEFormulaCurveRejectsTraditionalParametricTypesThreeAndFour`，分别使用 6 参数和 7 参数的 type 3/4 合成 `mpet` profile，验证解析阶段拒绝且错误身份准确。

实际命令：

```sh
swift test --package-path Native/Packages/LUTKit \
  --filter ICCMPEContractsTests
swift test --package-path Native/Packages/LUTKit -c release \
  --filter ICCMPEContractsTests
swift test --package-path Native/Packages/LUTKit -c release
bash Scripts/verify-native-numerics.sh
```

结果：Debug 定向 23 项通过；Release 定向 23 项通过；Swift Release 全量测试退出码 0，各测试包 0 失败，LUTFormats 的既有外部夹具按原规则跳过；原生数值门禁 66 项通过，退出码 0。结果包位于 `docs/native-validation/artifacts/2026-10-05-icc-mpet-formula-boundary/`：

- `targeted-debug.log` SHA-256：`501326d38c3970183487d137fce7399efe55195e659bbba0dba7185cf3585e42`
- `targeted-release.log` SHA-256：`014f23b4cfac1f4c288d37cc524e2e67361af0ef6346c63dd18eb8b5e95d4259`
- `full-release.log` SHA-256：`1edb893b1d7aa4e452c05acd6d418310ad674d56b9be5da68710ba94be72d9cd`
- `numerics-gate.log` SHA-256：`b0c0a0ae1aaa37b65d8da6b77a615b30b409b5f88fde92973c68c2f42c6889f5`

所有退出码文件内容均为 `0`。

## 未覆盖范围

本轮不扩大 MPE 元素集合，不实现未来规范元素，不改变采样曲线首尾段拒绝规则，也不宣称完整 ICC 完成。真实第三方 profile 逐码参照、所有 profile class 与 rendering intent、黑点补偿、gamut mapping、ColorSync、HDR/EDR、目标软件往返、`.labin` `0/9`、直接查表注册 `0/45`、LUTAnalyst 任意 3D 反求、UI、设备性能和发布清单仍未完成。`docs/native-validation/full-scope-acceptance.json` 未创建，Goal 保持 `active`。

# ICC MPE `parf` 公式类型复核

日期：2026-10-06

## 复核结论

本次重新核对 ICC.1:2022-05（`/tmp/icc-1-2022-05.pdf`，SHA-256
`aad8e33128635893e38ae780def3b29e661e4541be03cb235c67dd94d558001b`）的
`multiProcessElementsType`。`cvst` 内的 `parf` function type 仅定义 0、1、2；传统
`para` parametricCurveType 的 type 3、4 使用不同的标签编码和参数布局，不能接入
`parf`，也不存在可由现有字段安全推导的替代公式。因此本轮不修改生产代码。

## 现有实现与契约

- `ICCMPETransform` 以 `Double` 执行 `parf` type 0、1、2，并对未知类型返回
  `unsupportedCurve("parf-N")`。
- `ICCMPEContractsTests` 的 type 3/4 合成 `mpet` 输入验证了解析期拒绝；同一测试包还覆盖
  公式 Double 计算、breakpoint 和资源边界。
- 传统 `para` type 3/4 已在 Matrix/TRC 与 mAB/mBA 路径中按其自身规范实现，不应复制到 MPE。

## 验证

实际命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter ICCMPEContractsTests
```

结果：Release `ICCMPEContractsTests` 29 项通过，0 失败；type 3/4 拒绝契约保持通过。

## 未闭合范围

本复核不宣称完整 ICC。真实第三方 profile 逐码参照、完整 profile class/intent、BPC、
通用 gamut mapping、ColorSync、HDR/EDR、传统任意通道 linking，以及 `.labin`、直接查表和
LUTAnalyst 任意三维全局反求仍未完成。Goal 继续保持 `active`。

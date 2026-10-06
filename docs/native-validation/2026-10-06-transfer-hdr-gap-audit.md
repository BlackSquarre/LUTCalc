# Transfer 与 HDR/OOTF 算法缺口审计

日期：2026-10-06。

## 审计结论

本轮只检查已有 Swift `Double` 传递函数、色域和 HDR/OOTF 数学路径，未新增生产算法。`HLGTransfer`、`PQTransfer`、`BT1886Transfer`、ACEScc/ACEScct/ACESproxy、Rec.709、Rec.2020 连续 OETF、SMPTE 240M 及已登记色域矩阵均已有公开公式、明确单位或域边界、执行接线和定向契约。没有发现同时满足公开公式、独立参照且不扩大范围的安全新增缺口。

## 已核对路径

- `TransferID` 与 `TransformPlan` 的输入解码、`NativeOutputEncoder` 的输出编码；现有目录中的公开 transfer 均有最终 `Double` 路径。
- HLG/PQ 标量编码及 HLG reference OOTF/EOTF 的已验收子集；这些路径保持显式参数和既有拒绝边界。
- `LegacyCubicCurveAnalysis` 的导数临界点求解已对判别式溢出使用系数缩放；Release `RootContractsTests` 8 项通过，其中包含判别式溢出仍保留有限临界根的契约。

## 研究阻塞

旧 `LUTGammaOOTFPQ` 的 `Lw`、`scale`、输入百分比单位和 knee 语义无法与 BT.2100 标准 OOTF 唯一对应，历史 knee 两侧存在约 `1.7751367975487e-3` nits 跳变。因此不猜测公式、不平滑历史跳变，也不把兼容内核注册为标准 PQ OOTF。完整 PQ OOTF、自动峰值和 HDR/EDR 设备语义继续保持未完成。

## 实际命令与结果

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter RootContractsTests
```

工具链：SwiftPM Release，Apple Swift 工具链。结果：`RootContractsTests` 执行 8 项、0 失败，退出码 `0`。原始输出及 SHA-256 位于 `artifacts/2026-10-06-transfer-hdr-gap-audit/`。

## 未覆盖范围

本审计不关闭 `.labin` `0/9`、直接查表 `0/45`、任意 3D LUT 全局反求、自动 transfer/colour 分离、完整 ICC、完整 HDR/EDR/OOTF、目标软件往返、平台交互、真机性能、签名发布或真实 `full-scope-acceptance.json`。Goal 继续保持 `active`。

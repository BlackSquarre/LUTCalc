# ICC MPE 末段采样曲线验收

## 范围

本项只处理 ICC.1:2022-05 `multiProcessElementsType`（`mpet`）中 `curf` 的 `samf` 分段边界。采样段的首个样本值由前一段末值隐含，因此首段不能是 `samf`；末段有前一段提供隐含起点，允许 `samf`，其最后显式样本作为该分段终点。此前实现错误地拒绝末段采样，导致合法用户 profile 无法解析。

## 契约与实现

先行失败契约把原有“首段和末段均拒绝”改为“仅首段拒绝、末段按规范插值”。旧生产代码在末段构造上返回 `.malformed`。修复后，末段采样分段的上界使用归一化曲线域终点 `1.0`，中间段仍使用下一个 breakpoint；首段仍返回 `.malformed`。

参考实现依据 Little CMS `Type_MPEcurve_Read`/`Write` 对 segmented curve 的采样段编码，以及 ICC.1:2022-05 §10.16.2.1、§10.16.2.3 的隐含首样本规则。未引入厂商 LUT、`.labin` 或采样表。

## 实际命令与结果

工具链：SwiftPM、Apple Swift/XCTest，macOS 当前 SDK。

```sh
swift test --package-path Native/Packages/LUTKit -c debug --filter ICCMPEContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter ICCMPEContractsTests
git diff --check
```

Debug 与 Release 的 `ICCMPEContractsTests` 均为 28 项通过、0 失败。结果日志：

- `artifacts/2026-10-06-icc-mpet-final-sampled/debug.log`，SHA-256 `9a049bb58595cc55d89db5c69826219621ab6d1b9449a0f4cf316bae2d4ab47f`
- `artifacts/2026-10-06-icc-mpet-final-sampled/release.log`，SHA-256 `ff1154bcf957dc24da613a21622875c7ae8c93e1448638b937ea98a9a68fefe0`

## 未覆盖范围

本项不代表完整 ICC profile linking、真实第三方 profile 逐码参照、BPC、gamut mapping、ColorSync、其他未来 MPE 元素或 Goal 完成。`.labin`、直接查表注册和 LUTAnalyst 全局 3D 反求仍未完成。

# 算法重点 Release 回归

## 命令

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter 'TricubicInverseContractsTests|TrilinearInverseContractsTests|TetrahedralInverseContractsTests|CombinedShaperColourInverseContractsTests|ICCMPEContractsTests|ICCRGBProfileLinkContractsTests|BT2100HLGReferenceOOTFContractsTests|BT2100HLGReferenceEOTFContractsTests|LegacyPQOOTFContractsTests|ACESReferenceGamutCompressionContractsTests'
```

## 结果

命令退出码 `0`，共通过 `137` 项：LUTPreview `69` 项、LUTCore `23` 项、LUTAnalysis `45` 项，失败 `0`。日志 SHA-256：
`7e47fbba5187e8200d423c651ecc12868fce1a2320e617e21397dadb8e91dda5`。

覆盖 ICC MPE/profile 路由、ACES reference gamut compression、BT.2100 HLG EOTF/OOTF、隔离的旧 PQ OOTF、tetrahedral/trilinear/tricubic 和组合 shaper 反求的已声明边界。

## 未覆盖范围

这些是局部公式和拒绝边界契约，不证明任意 3D LUT 全局根完备性、自动 transfer/colour 分离、完整 ICC 的 BPC/gamut mapping/ColorSync、完整 PQ OOTF/HDR/EDR 设备语义、`.labin` 或直接查表替代。Goal 保持 `active`。

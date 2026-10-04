# ICC RGB/Lab PCS linking 非 UI 子集验收

## 范围与标准依据

本轮只接通用户主动提供的 RGB ICC profile 在 PCS `Lab ` 下的有限 linking 路由，不涉及界面、系统 ColorSync、Metal、目标调色软件或完整 ICC 色彩管理。PCS Lab 编码沿用已有 `ICCLabPCS`，其来源为 ICC.1:2022-05 §10.15–§10.16；D50 PCS Lab 到 `CIELABColor` 的转换沿用已有 Double 实现。

统一入口现在按 profile header 和标签方向明确分派：

- 源 profile 必须为 RGB/`Lab `，并具有 `A2B0`；目标 profile 必须为 RGB/`Lab `，并具有 `B2A0`。
- `mft1/mft2` 使用 `ICCMFTLabTransform`；`mAB`/`mBA` 使用 `ICCMABLabTransform`，方向不匹配直接拒绝。
- RGB/`XYZ ` 的既有 matrix/TRC 与有限 LUT 路由保持不变。
- PCS 混用、缺失方向标签、未知标签类型及非 RGB profile 不猜测、不回退。

没有把任何 profile、厂商 LUT、旧 `.labin` 或等价采样表放入 App 资源。

## 契约先行

先新增：

1. 两个 RGB/`Lab ` `mft2` profile 通过统一入口完成 round-trip；
2. 两个 RGB/`Lab ` `mAB`/`mBA` profile 通过统一入口完成 round-trip；
3. RGB/`Lab ` 与 RGB/`XYZ ` 混用时返回 `.mismatchedPCS`。

旧实现运行：

```text
swift test --package-path Native/Packages/LUTKit --filter ICCRGBProfileLinkContractsTests
```

退出码 `1`，先行失败原始日志保存在 `/tmp/lutcalc-icc-lab-link-red.log`；原因是统一错误类型尚无 `.mismatchedPCS`，且没有 Lab route。

## 实现后验证

```text
swift test --package-path Native/Packages/LUTKit --filter ICCRGBProfileLinkContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter ICCRGBProfileLinkContractsTests
swift test --package-path Native/Packages/LUTKit -c release
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -sdk macosx -destination generic/platform=macOS -derivedDataPath /tmp/lutcalc-icc-lab-link-mac-20261004 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/lutcalc-icc-lab-link-ios-20261004 CODE_SIGNING_ALLOWED=NO build
```

结果：

- Debug 定向 8 项，0 失败；
- Release 定向 8 项，0 失败；
- Swift Release 全量回归执行 8 个测试包共 678 项，0 失败；LUTFormats 的 56 项中旧 `.labin` 与 NCP 外部夹具各跳过 1 项；
- macOS generic Release 构建退出 `0`；
- iOS generic Release 构建退出 `0`；
- 既有 XYZ matrix/TRC、XYZ LUT、显式 alpha 像素 linking 契约仍通过。
- `python3 tools/native-validation/check-release-evidence.py` 退出 `2`，原因仍是缺少真实 `docs/native-validation/full-scope-acceptance.json`；没有创建或伪造该清单。

结果包、退出码和日志位于：

`docs/native-validation/artifacts/2026-10-04-icc-rgb-lab-link/`

## 未覆盖范围

本记录不宣称完整 H13。尚未完成：独立真实（非 synthetic）`mft1`、`mAB`、`mBA` profile 夹具的统一入口逐码参照；perceptual／saturation／absolute intent；黑点补偿；gamut mapping；任意通道数；像素布局；系统色彩管理；跨平台独立参照；项目 schema 接入；目标软件往返；HDR/EDR；File Provider；实体 iPhone 11 重复性能；签名发布和真实 `full-scope-acceptance.json`。Goal 保持 active。

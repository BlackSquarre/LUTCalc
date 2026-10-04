# 2026-10-03 ICC PCS XYZ 用户导入接入非 UI 验收

## 范围

本阶段只处理用户主动提供的 ICC LUT profile 中 RGB↔PCS XYZ 的三通道 CPU 子集：

- `mft2` 的 `A2B0`／`B2A0` 双向适配；
- `mAB`／`mBA` 的 16 位 CLUT 双向适配；
- ICC `u1Fixed15` PCS XYZ 编码、Double 连续值和严格域检查；
- 明确拒绝没有八位 PCS XYZ 定义的 `mft1`，以及八位 `mAB/mBA` CLUT、非 RGB、非 `XYZ ` PCS 和错误方向。

本阶段没有接入项目生成计划、完整 ICC profile 类型、其他 rendering intent、黑点补偿、gamut mapping、像素布局、系统色彩管理、UI、设备或发布签名。

## 规范依据

实现依据公开的 ICC.1:2022-05：

- §6.3.4.2 Table 11：16 位 PCS XYZ 使用 `u1Fixed15`，`0x8000` 表示 `1.0`，`0xffff` 表示 `65535/32768`；
- §6.3.4.1：PCS XYZ 不能使用八位整数编码；
- §10.8／§10.9：`mft1`／`mft2` LUT 结构和表精度；
- §10.10／§10.11：`mAB`／`mBA` 管线及 CLUT 精度。

独立规范原文下载为 `/tmp/icc-2022.pdf`，其文本摘录为 `/tmp/icc-2022.txt`；这两个临时文件不属于应用资源，也没有打包进仓库。

## 契约先行

先加入 `ICCPCSXYZContractsTests`，实现前运行的红灯命令为：

```text
swift test --package-path Native/Packages/LUTKit --filter ICCPCSXYZContractsTests
```

实际失败原因为 `ICCMFTXYZTransform`、`ICCMABXYZTransform` 及对应错误类型尚不存在；原始日志保留于 `/tmp/lutcalc-icc-pcs-xyz-contract-red-20261003.log`。

## 实现

- 新增 `ICCXYZPCS`，只实现公开的连续 `u1Fixed15` 归一化边界，不隐式 clamp；
- 新增 `ICCMFTXYZTransform`，要求 RGB、`XYZ `、三通道和 `mft2`；`mft1` 明确返回 `.unsupportedEncoding`；
- 新增 `ICCMABXYZTransform`，要求 RGB、`XYZ `、三通道和 16 位 CLUT；八位 CLUT 明确返回 `.unsupportedEncoding`；
- `ICCMFTTransform` 暴露实际表样本字节数，`ICCMABTransform` 暴露实际 CLUT 样本字节数，仅用于编码门控；
- 继续复用既有矩阵、输入表、CLUT、输出表顺序和 `Double` 路径，不新增任何内置 LUT 或等价采样表。

## 实际验证

工具链：Xcode 27.0、Swift 6.4、macOS arm64。

定向 Debug：

```text
swift test --package-path Native/Packages/LUTKit --filter ICCPCSXYZContractsTests
```

实际执行 7 项，0 失败。日志 SHA-256：

```text
6764743597e1bf7b5b497a45ca6ea8d9730b3678a15c316486d04002ae5eee9d
```

定向 Release 同样执行 7 项，0 失败。日志 SHA-256：

```text
0e3567e209b3f8b13d4a9df5cbe2e6d334b937c44942e0ed0596ac807788a03b
```

Release 全量：

```text
swift test -c release --package-path Native/Packages/LUTKit
```

8 个测试包实际执行 591 项，0 失败；分包为 `LUTSharedUITests` 137、`LUTProjectTests` 43、`LUTPreviewTests` 79、`LUTJobsTests` 50、`LUTFormatsTests` 56、`LUTCoreTests` 174、`LUTCatalogTests` 20、`LUTAnalysisTests` 32。旧 `.labin` 和 NCP 外部夹具各 1 项按既有规则跳过。日志 SHA-256：

```text
af21ec91dfa5b67cbf2a1891081a6f43417a70f8b032543afafb5c0456e36168
```

三平台未签名 Release 构建均实际退出 0：

```text
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalc-icc-pcs-xyz-mac-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalc-icc-pcs-xyz-ios-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalc-icc-pcs-xyz-sim-20261003 CODE_SIGNING_ALLOWED=NO build
```

最终重跑日志 SHA-256：

| 目标 | 日志 SHA-256 |
| --- | --- |
| macOS | `6d13eea03a188f0aeef0e19e87111ea146257a41abf07de343e08b684099285a` |
| iOS | `d0712ae2d1519e4bab06c78466caffda2e455b182772b53e5adf3bc4483437ad` |
| iOS Simulator | `5230652c31f77fd4e61d2c8df18d268bd5b724feda59177177896f0e183f028b` |

三个实际产物分别为：

- `/tmp/LUTCalc-icc-pcs-xyz-mac-20261003/Build/Products/Release/LUTCalcMac.app`
- `/tmp/LUTCalc-icc-pcs-xyz-ios-20261003/Build/Products/Release-iphoneos/LUTCalcIOS.app`
- `/tmp/LUTCalc-icc-pcs-xyz-sim-20261003/Build/Products/Release-iphonesimulator/LUTCalcIOS.app`

源码边界审计实际通过，计数 145 个 Swift 源文件；App 包审计实际通过，三个包均未发现 `.js`、`.html`、`.c`、`.cc`、`.cpp`、`.m`、`.mm`、`.labin` 或 WebKit/JavaScriptCore 直接链接。审计日志 SHA-256 分别为：

```text
源码：f531c6426c8b302a8e2c9ff6da39d39c646869989d89afb1d9c4edab344dbdf9
App 包：5cf8f49359d02d2b03d3b23d7fcc0f25b68815ca27754ee29b15de8522a24d2f
```

CoreSimulator 在构建日志中仍报告既有内存／设备集订阅警告；三条构建命令均退出 0 且生成目标包。该结果不计作模拟器运行或设备交互证据。

## 未覆盖与状态

本阶段只闭合 H13 的 PCS XYZ 用户导入 CPU 子集。完整 ICC profile 类型、任意通道数、其他 rendering intent、黑点补偿、gamut mapping、像素布局、profile linking 的其他路径、跨平台独立参照、项目接入、HDR/EDR、设备、性能、签名发布和真实 `docs/native-validation/full-scope-acceptance.json` 仍未完成。H13、FULL-08、H14 和 Goal 继续保持 active；没有创建或伪造全量清单。

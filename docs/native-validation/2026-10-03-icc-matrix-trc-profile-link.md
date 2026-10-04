# ICC matrix/TRC profile linking 子集验收

日期：2026-10-03

## 范围

本轮补齐 H13/FULL-03 的一个非 UI 子集：把两个用户提供的 RGB matrix/TRC ICC profile 通过 ICC PCS XYZ 连接起来。连接只实现显式选择的 relative colorimetric intent；不实现 perceptual、saturation、absolute colorimetric 的 gamut mapping、黑点补偿或显示渲染，也不把这些 intent 伪装成同一条数学路径。

## 契约先行

先增加三项契约：相对色度连接的独立结果、未实现 rendering intent 的拒绝、PCS 白点不一致的拒绝。实现前运行因 `ICCMatrixTRCProfileLink` 和错误类型不存在而编译失败；实现后重新运行通过。

## 实现

- 新增 `ICCMatrixTRCProfileLink`，分别构造现有 `ICCMatrixTRCTransform` 的源与目标路径。
- `convert` 执行 source encoded RGB → XYZ PCS → target encoded RGB，所有中间计算保持 `Double`。
- 新增 `ICCMatrixTRCRenderingIntent`，只允许 `.relativeColorimetric`。
- 源/目标 profile 必须都是现有 RGB/XYZ matrix/TRC 受限子集，且 profile `wtpt` 在 `2e-12` 独立阈值内一致；否则显式拒绝。
- 不保留或打包用户 ICC LUT 采样表；已有 `mft1/mft2/mAB/mBA` 路径仍保持用户导入专用边界。

## 实际命令与结果

工具链：Xcode 27.0、Swift 6.4、macOS arm64，Swift Package `Native/Packages/LUTKit`。

```text
swift test --package-path Native/Packages/LUTKit --filter ICCMatrixTRCContractsTests/testMatrixTRCProfileLinking
```

结果：3 项通过，0 失败。首次运行在实现前按契约预期编译失败；实现后同一命令通过。

```text
swift test --package-path Native/Packages/LUTKit --filter LUTPreviewTests
```

结果：63 项通过，0 失败；日志 `/tmp/lutcalc-icc-profile-link-debug-20261003.log`。

```text
swift test -c release --package-path Native/Packages/LUTKit --filter ICCMatrixTRCContractsTests
```

结果：18 项通过，0 失败；Release 编译和测试通过。日志 `/tmp/lutcalc-icc-profile-link-release-20261003.log`。构建只有既存的 `UnnecessaryEffectMarker` 警告。

随后运行完整 Swift 回归：共执行 545 项，0 失败；旧 `.labin` 和 NCP 公共 specimen 各跳过 1 项。日志 `/tmp/lutcalc-icc-profile-link-full-20261003.log`，SHA-256 `3f8b1da73d311da4c9ab5d98f50c1be0435fbbb87ab11db206be935657f5069c`。

## 独立数值结果

测试 profile 使用单位矩阵和公开可复现的 gamma/线性曲线。源 gamma=2、目标线性曲线的连接点 `(0.5, 0.25, 0.75)` 读回为 `(0.25, 0.0625, 0.5625)`，逐通道误差低于 `2e-14`。既有 matrix/TRC 33³/65³ round-trip 继续低于 `2e-12`。

## 未覆盖范围

这不是完整 ICC 实现。仍缺完整 ICC profile 类型、非 RGB 通道、PCS Lab、profile linking 的其他 rendering intent、黑点补偿、gamut mapping、设备链、所有图像像素布局及跨平台独立参照；UI、HDR/EDR 和真实第三方色管软件往返也未验收。Goal 保持 active。

# 2026-10-05 ICC absolute 不同媒体白点验收

## 范围

本工作包只处理用户提供的 RGB matrix/TRC ICC profile 在 `absoluteColorimetric` 下连接时，源和目标 `mediaWhitePointTag` 不相同的情形。仍不实现 LUT profile、`Lab ` PCS、`DToB3`/`BToD3`、黑点补偿、gamut mapping 或系统 ColorSync。

## 公式与边界

依据 ICC.1:2022-05 §6.3.2.2 公式 (1)–(6) 与 Annex D §D.6.1 公式 (D.6)–(D.7)：

1. 源 matrix/TRC 产生 media-relative `PCSXYZ`。
2. 源值按 `source.mediaWhitePoint / PCSWhite` 转为 ICC-absolute `nCIEXYZ`。
3. 再按 `PCSWhite / target.mediaWhitePoint` 转为目标 media-relative `PCSXYZ`。

两步合并为逐通道 `source.mediaWhitePoint / target.mediaWhitePoint`。实现只在 absolute matrix/TRC 路径使用该比例；relative 路径仍要求媒体白点在 `2e-12` 相对容差内一致。PCS 白点在两步中相消，因此没有把 D50 常数误当成媒体白点。

## 契约先行

先新增两个差异白点 synthetic profile 契约，再运行旧实现，两个测试均按预期失败并返回 `mismatchedPCSWhitePoint`：

```sh
swift test --package-path Native/Packages/LUTKit \
  --filter 'ICCMatrixTRCContractsTests/testAbsoluteColorimetricScalesBetweenDifferentMediaWhitePoints|ICCRGBProfileLinkContractsTests/testAbsoluteColorimetricMatrixRouteScalesDifferentMediaWhitePoints'
```

失败日志：`/tmp/lutcalc-icc-different-whitepoint-red.log`，SHA-256 `8da0b3583a92546a372cba1dac981a7b5160ff9e62a421e8a0514970e3e831ef`。

## 实现与定向验证

`ICCMatrixTRCProfileLink` 增加 absolute 的 source/target 媒体白点比例；`ICCRGBProfileLink` 继续只把 absolute 分派到 matrix/TRC，LUT 和 Lab 明确拒绝。独立 synthetic 预期输入 `(0.5, 0.25, 0.75)`，源 gamma 为 2，目标为恒等，白点比例为 `(0.5, 2.0, 0.5)`，输出为 `(0.125, 0.125, 0.28125)`。

修复后定向 Debug 2 项和定向 Release ICC 75 项均通过；定向 Release 日志 `/tmp/lutcalc-icc-different-whitepoint-release.log`，SHA-256 `d1fbbe896783dc2a1c82314f5380548b4cf2fc2a4faee7a820d576a4b266a1b9`。相对 intent 的不同白点拒绝、相同白点 absolute、LUT/Lab absolute 拒绝均保持通过。

## 完整入口复验

```sh
Scripts/verify-native-release.sh
```

结果：

- 66 项原生静态/公式检查通过；Node 契约 11 项通过。
- Swift Release 全量执行 799 项，0 失败；`LUTFormats` 的既有外部夹具仍按原规则跳过。
- macOS、generic iOS、generic iOS Simulator Release 构建均出现 `BUILD SUCCEEDED`。
- 3 个实际 App 包审计通过，没有列出的 LUT、脚本或 WebKit/JavaScriptCore 直接链接。
- 入口最终退出码为 `2`，唯一门槛是缺少真实 `docs/native-validation/full-scope-acceptance.json`；本工作包没有创建或伪造该文件。

完整日志：`artifacts/2026-10-05-icc-whitepoint-absolute/release-gate.log`，SHA-256 `5b76542aeb1c335b35c1d6fdfd318563cda25c1a5db8f2908578c058ad296962`。

## 未覆盖

仍未完成不同 profile 类型的 absolute linking、`DToB3`/`BToD3`、perceptual/saturation、黑点补偿、gamut mapping、真实非 synthetic profile 逐码独立参照、系统 ColorSync、HDR/EDR、完整查表替代和 Goal 全量验收。该记录只关闭 ICC matrix/TRC 不同媒体白点 absolute 的数学子集，Goal 保持 `active`。

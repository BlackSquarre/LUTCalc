# ICC 传统 LUT absolute intent 接线验收

## 范围

本阶段将已有用户导入 `mft2`、`mAB`、`mBA` 的 PCS XYZ 执行器接到传统 ICC absolute colorimetric 标签 `A2B3`／`B2A3`。源 profile 的 PCS XYZ 先按 ICC.1:2022-05 §6.3.2.2 的媒体白点比例转换到 absolute，再按目标媒体白点比例进入目标 profile。计算仍使用 Swift `Double`，不新增 profile、厂商 LUT、旧 `.labin` 或等价采样表。

## 失败契约

在适配器白名单和 intent 分派尚未扩展前，带有 `A2B3`／`B2A3` 的合成 profile 被拒绝。缺少精确 `A2B3` 时 absolute linking 保持明确 `missingTransformTag`，不回退到其他 intent。

## 实现

- 传统 LUT intent 选择器加入 `A2B3`／`B2A3`，absolute 不借用 `A2B0/A2B1/A2B2`。
- MFT、MAB、Lab 适配器加入 intent 3 方向白名单。
- `ICCLUTProfileLink` 保存源／目标 `wtpt` 比例，执行与 `ICCMatrixTRCProfileLink` 相同的媒体白点缩放。
- 缺失、非 XYZ、非有限或非正 `wtpt` 继续拒绝。

## 实际验证

工具链：Xcode `27.0 (27A266a)`，Swift `6.4`，Apple Silicon macOS。

```sh
swift test --package-path Native/Packages/LUTKit -c debug --filter ICCLUTProfileLinkContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter ICCLUTProfileLinkContractsTests
```

结果：Debug／Release 各 10 项通过、0 失败。覆盖 absolute 精确标签、不同媒体白点比例、缺少标签拒绝及既有 perceptual／relative／saturation 路由回归。

随后运行 `swift test --package-path Native/Packages/LUTKit -c release`，8 个测试包共执行 863 项、0 失败；`LUTFormats` 的既有外部夹具仍按原规则跳过。完整日志和退出码文件保存在 `artifacts/2026-10-06-icc-traditional-absolute-intent/`，`full-release.log` SHA-256 为 `6341509c0ed8939bdf94e11a1d613c9f012e523c35b381b47dd579e067626545`。

## 未覆盖范围

- 本阶段不实现黑点补偿、gamut mapping、ColorSync、系统工作空间或显示管理。
- 真实第三方 profile 逐码参照、目标调色软件往返、完整 ICC profile class 和发布验收仍未完成。

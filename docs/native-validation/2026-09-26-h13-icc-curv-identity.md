# H13 ICC 零节点曲线阶段验收

日期：2026-09-26。公开语义来源：ICC.1:2022-05 规范 <https://www.color.org/specification/ICC.1-2022-05.pdf> 的 `curveType`：count 为 0 时表示恒等响应，count 为 1 时是 u8Fixed8 gamma，更多节点是采样曲线。仅扩展用户 ICC RGB matrix/TRC CPU 子集，不把任何 ICC 节点或采样表作为内置转换。

先新增合成 ICC 的三个通道 `curv(count=0)` 契约：单位矩阵下，`(0.125, 0.5, 0.875)` 正反向均应逐位保持。修复前报 `unsupportedCurve("curv:0")`；修复后走显式恒等解析分支。相同契约也确认 count=2 的采样曲线仍报 `unsupportedCurve("curv:2")`，不将其冒充解析公式。现有 type 1–4 逆函数、分段失败和 33³/65³ 往返契约保持通过。

修改文件：`Native/Packages/LUTKit/Sources/LUTPreview/ICCMatrixTRCTransform.swift`、`Native/Packages/LUTKit/Tests/LUTPreviewTests/ICCMatrixTRCContractsTests.swift`、`docs/native-swift-roadmap.md`、本记录。前两项当前 SHA-256 分别为 `4635f6e18106ecdabda61791193c6d96dd24b94b145d5c6bb7aec456f2caefe3`、`06a4691cf8144615cf1f95bf489a713cb406ada9d3074ea77d1c1c24414bd268`；测试内合成 ICC 即本段夹具，以测试文件哈希锁定，基础外部夹具未更改。工具链仍为 Xcode 27.0（27A266a）、Apple Swift 6.4、macOS/iOS 27.0 SDK。

| 实际命令 | 结果 |
| --- | --- |
| `swift test --package-path Native/Packages/LUTKit -c release --filter ICCMatrixTRCContractsTests.testZeroCountCurveIsIdentityWithoutSamplingTable` | 修复前退出 1，准确复现 `unsupportedCurve("curv:0")`；日志 `/tmp/lutcalc-icc-identity-red-20260926.log`，SHA-256 `ddfab50ac0651b0998110477e05bb15cc557439227937312c88f6b9e3beb3b60`。 |
| `swift test --package-path Native/Packages/LUTKit -c release --filter ICCMatrixTRCContractsTests` | 修复后 11 项通过；日志 `/tmp/lutcalc-icc-identity-targeted-20260926.log`，SHA-256 `32c4be3f67a2317e3054e2e1f49cd8a9824dc443ac87dbeb9cf51832b9ce901c`。 |
| `bash tools/native-validation/verify-native-release.sh` | 原生子集、Swift Release 全包、macOS/iOS Simulator/iOS generic 三个 Release 构建与三个 App 包资源审计通过；Swift 清单 244 项，公开 NCP 实样 1 项因未提供路径按设计跳过。总退出码 2，因真实 `docs/native-validation/full-scope-acceptance.json` 缺失。日志 `/tmp/lutcalc-h13-icc-identity-release-20260926.log`，SHA-256 `0aa44fab654992986fb4d3afdca12ce203b2b885208e191b72b48835708f58bd`。 |

本次恒等样本误差为 0；未对完整 ICC、跨白点工作/显示转换、Core Image、HDR/EDR 或真实设备 ICC 文件作验收。源代码、Mac 数值测试、双端构建及真机交互分别保持独立状态，H13/UI-03 与发布门槛仍未完成。

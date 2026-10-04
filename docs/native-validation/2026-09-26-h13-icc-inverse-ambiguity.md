# H13 ICC 参数曲线反求歧义阶段验收

日期：2026-09-26。范围：用户图像 ICC 的 RGB matrix/TRC CPU 子集，`para` type 1–4 的反向求值。此项是现有 H13 子段的数值纠错，不代表完整 ICC 色彩管理或 H13 完成。

## 失败契约与修改

- 先新增合成 ICC 契约：type 3/4 在 `d=0.5` 两侧输出断层时，目标 `0.1875` 无原像；在两侧输出重叠时，目标 `0.36` 有两个原像。旧实现均返回一个错误候选。type 1/2 在 `b=-0.25` 时有平段，平段输出不能被宣称有唯一逆。
- `ICCMatrixTRCTransform.swift` 现分别核对低段和高段候选的分支、单位域及前向残差；无候选报 `outsideDomain`，不同的两个候选报 `nonUnique`。type 1/2 平段输出报 `nonUnique`。type 3 的高段幂底在切点也做非负检查。前向公式、ICC 数据来源和默认显示路径未变。
- 本项反求候选前向残差界固定为 `2e-12 × max(1, |目标|)`；它只用于判定候选是否确实落在该解析分支，不放宽既有 33³/65³ 往返测试的 `2e-12` 输入误差门槛。合成夹具与预期在 XCTest 源码中，不进入 App。

## 文件、工具链与证据

修改文件：`Native/Packages/LUTKit/Sources/LUTPreview/ICCMatrixTRCTransform.swift`、`Native/Packages/LUTKit/Tests/LUTPreviewTests/ICCMatrixTRCContractsTests.swift`、`docs/native-swift-roadmap.md`、本记录。源码 SHA-256 前两项分别为 `da33a7fb8cb5d881201aa4bb6547347a57f91b07444d3a24749c08b5f5da2eb6`、`5125b77b7107cab1f19c8e0ccef13e53e7f023ce7814a091541b5264d79d3d59`。合成 ICC 夹具版本由上述测试文件哈希锁定；未改动的基础夹具 `numeric-contracts.json` 与 `dlog2-reference.json` 哈希分别为 `217a1138bc6dee0d041608bbadd00264dacf377184b0f43ef2ea4ce68e7a9d8b`、`1f90b116bdd507f9142547dbb1fdf757fec1e3d2c9e22a77057e08a05eb5ab91`。

实际工具链：Xcode 27.0（27A266a）、Apple Swift 6.4、macOS/iphoneos/iphonesimulator 27.0 SDK，执行主机为 Apple Silicon Mac。

| 实际命令 | 结果 |
| --- | --- |
| `swift test --package-path Native/Packages/LUTKit -c release --filter ICCMatrixTRCContractsTests` | 先复现 type 3/4 四个失败，再复现 type 1/2 两个失败；修复后 10 项通过。日志 `/tmp/lutcalc-icc-inverse-targeted-20260926.log`，SHA-256 `9939db8a6d7fc6f8349e776884599532f9b69289526ec382abaa516af4d3b43e`。 |
| `swift test --package-path Native/Packages/LUTKit -c release` | 退出 0，清单 243 项；公开 NCP 实样 1 项因未提供路径按设计跳过。日志 `/tmp/lutcalc-icc-inverse-swift-full-20260926.log`，SHA-256 `a94a93dcc652162cc194137e964aaf62f2582122ad880e1e6e64d484f71585c5`。 |
| `tools/native-validation/verify-native-subset.sh` | 退出 0；旧 Node/Python、公式与 33³/65³ CUBE 批量独立读回、原生静态及命令行契约通过。日志 `/tmp/lutcalc-icc-inverse-subset-20260926.log`，SHA-256 `e110c1ca1f1f7ab96ecb2e3cedcd0aa1654547c1b0e8418ba2f384cbacf7f54a`。 |
| `bash tools/native-validation/verify-native-release.sh` | macOS、iOS Simulator、iOS generic 三个 Release 构建和三个 App 包资源检查通过；总退出码 2，仅在真实全量验收清单 `docs/native-validation/full-scope-acceptance.json` 缺失处停止。日志 `/tmp/lutcalc-icc-inverse-release-20260926.log`，SHA-256 `a1cc6807e19c225b704aebd77e532511d667b00b4a78d3338d9306ec545ea637`。 |

合成断层/重叠案例现分别返回明确失败；既有连续 type 3 的 33³/65³ 往返门槛仍通过，测试未输出逐节点最大值，故不编造精确最大误差。当前仅完成源码、Mac Release 测试、三平台构建和所述数值子段；未验证本变更在真实 iPhone/iPad 上的 ICC 文件交互。完整 ICC、工作/显示空间转换、Core Image、HDR/EDR、Files/File Provider、全量算法覆盖和发布门槛均保持未完成。

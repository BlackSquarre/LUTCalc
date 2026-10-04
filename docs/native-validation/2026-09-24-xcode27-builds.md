# Xcode 27 双平台构建与发布入口阶段记录

日期：2026-09-24。此前默认 `xcode-select` 指向 `/Library/Developer/CommandLineTools`，导致 `xcodebuild` 检查退出码 2；本次确认 `/Applications/Xcode.app` 实际存在，显式设置 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` 后完成包测试和三个 Release App 目标构建。构建通过不代表 App 已在模拟器或真机运行。

## 工具链与实际结果

- `xcodebuild -version`：Xcode 27.0（27A266a）；Swift 6.4；macOS 27、iPhoneOS 27、iPhoneSimulator 27 SDK。原先 Command Line Tools 仍可用于 Swift 6.2.1 的子集验证。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash tools/native-validation/verify-native-release.sh > /tmp/lutcalc-logc4-release-xcode27-20260924-v4.log 2>&1`：最终退出码 2。子集检查通过，静态审计覆盖 53 个 Swift 源文件；旧 Node 9/9、当前 Release 数值与文件/任务契约通过。
- `swift test -c release --package-path Native/Packages/LUTKit`：8 个 XCTest 套件共 30 项，0 失败（各套件在日志中分别报告 2、2、2、2、6、10、2、4 项）。
- `xcodebuild ... -scheme LUTCalcMac -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build`、`LUTCalcIOS` 对 iOS Simulator 及 iOS generic 的两条同等命令：均显示 `BUILD SUCCEEDED`。这是未签名构建，未安装或启动 App。
- 发布入口最后由 `check-release-evidence.py` 因缺 `docs/native-validation/full-scope-acceptance.json` 返回退出码 2。该文件需真实全量验收后生成；当前 H 工作包尚未完成，不创建空白或伪通过清单。

## 本次为通过 Xcode 工具链而修复的源码

| 文件 | SHA-256 | 修改与验证 |
| --- | --- | --- |
| `Native/Packages/LUTKit/Sources/LUTFormatChecks/main.swift` | `14421fce64aef35946b7d86d732ae400e54f0ad5d1c97b2719bcce03db1ffd54` | 将复杂推断式拆为明确 Double 与数组构造；原语义不变 |
| `Native/Packages/LUTKit/Tests/LUTFormatsTests/CubeContractsTests.swift` | `764e02077b9701850b810142bc59ac0ce0acd8ed76306b70e53ee0830a78f9d0` | 同上；原组合 shaper 契约保留 |
| `Native/Packages/LUTKit/Tests/LUTJobsTests/GenerationContractsTests.swift` | `1e429a80289475d5a5b98a564e0f2cc034e9b32d0ab7297c94d7c9a576544bfa` | 先 `await` 读取 actor 状态，再传给 XCTest 的同步断言；原断言未变 |
| `Native/Packages/LUTKit/Sources/LUTCore/Matrix3x3.swift` | `d280bdf3521752b6312d11739620e2565e9abd57089a676ea1393ddcfa1af203` | 对每个元素绝对值不超过 1024、均为整数且行列式为 ±1 的矩阵，用在 Double 中可精确表示的余子式求逆；其余矩阵仍用 LU，条件数和残差检查仍对两条路径执行。原测试要求整数逆精确相等，未更改预期或阈值 |
| `tools/native-validation/verify-native-subset.sh` | `98c9432233b00d0681d101ce44b44cf1eb02e72aa57b1aa15a59815ad4e1c6c3` | 兼容 Xcode 和 Command Line Tools 两种 Swift Package 模块目录；仍对 macOS App 入口做源码类型检查 |

本阶段没有 Finder/Files、File Provider、macOS 窗口、iOS/iPadOS 模拟器界面或真机运行证据；双端功能、数值输入、保存/分享及发布就绪仍须单独验收。`APP-01` 的“可构建”子条件已满足，整个工作包因运行和支持矩阵未完成而暂不勾选。

后续已完成首次 macOS 窗口及 iPhone/iPadOS 模拟器启动检查，见[双端原生草稿运行记录](2026-09-24-native-runtime-draft.md)。上段“没有运行证据”是本构建阶段的历史边界，后续运行记录也没有覆盖真机、保存及完整交互。

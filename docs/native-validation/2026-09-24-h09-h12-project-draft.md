# H09/H12 项目草稿界面接线阶段验收

日期：2026-09-24。状态：阶段通过，H09、H12、FLOW-03 和 FLOW-04 均未完成。界面只作为功能草稿，视觉与完整交互由用户另行设计。

## 契约与实现

先扩展 `LUTSessionChecks`：打开包含 sRGB 输入/输出、12-bit video 范围、非整数曝光及扩展域的项目，要求导出快照保留完整设置、尺寸和域；修改曝光后保存，不得抹去其他字段。带用户 LUT 资源的项目在资源链尚未接入生成计划时必须明确拒绝导出。缺少 `openProject` 时契约先编译失败，随后接入 `ProjectEditingSession`。

`EditorSession` 现在可打开、保存、另存为、撤销和重做项目；会话从项目清单同步草稿字段，设置改动通过完整清单的编辑会话保存。共用 SwiftUI 草稿显示实际项目的输入/输出与尺寸，以及项目名称和未保存状态；不再把打开的其他项目误标成默认 DJI 链。用户 LUT 资源尚未进入 `TransformPlan`，导出入口会抛出 `userLUTNotInPlan`。

## 修改文件与源码版本

| 文件 | 内容 | SHA-256 |
| --- | --- | --- |
| `Native/Packages/LUTKit/Sources/LUTSharedUI/EditorSession.swift` | 项目会话、设置同步与导出拒绝 | `91cb22c25c01f03f5b1c77619dbc01c4b4146f1c73a7b7a6de4415f04818c8ce` |
| `Native/Packages/LUTKit/Sources/LUTSharedUI/ContentView.swift` | 项目状态和当前输入/输出显示草稿 | `ee6bb817e5b36f5135fc7d808a55b9edbc42ad86fde92698de0a3532701f7328` |
| `Native/Packages/LUTKit/Sources/LUTSessionChecks/main.swift` | 完整项目快照、精确保存和用户资源拒绝契约 | `e34444a39a5985e49e04c66bc9a980296fd19b571bdda36506d21fb3840cf1d0` |
| `Native/Packages/LUTKit/Package.swift` | 契约目标增加项目与注册表依赖 | `4b3071aa3468d48925cc41a1127f5c4ebcf3a3d183c23db36805412c50e08a63` |

## 实际验证

- 工具链：Apple Swift 6.2.1，arm64 Command Line Tools；本机无完整 Xcode/iOS SDK。
- 契约先写，`swift run --package-path Native/Packages/LUTKit LUTSessionChecks` 初次因尚无 `openProject` 编译失败；实现后退出码 0。第一次绿测时发现契约夹具选用了已有 DJI 输出却期望 `.custom`；将夹具改为 sRGB 输出后通过，未改生产逻辑或数值阈值。
- `tools/native-validation/verify-native-subset.sh > /tmp/lutcalc-h09-h12-project-ui-validation-20260924.log 2>&1` 退出码 0。静态边界检查覆盖 39 个 Swift 源文件，旧 Node 9 项通过；H09/H12 契约和其他现有 Release 子集契约通过。该项是结构和保存行为检查，没有新的数值误差指标；原有数值门槛未修改。

## 未覆盖范围

草稿尚无系统文件打开/保存按钮、`DocumentGroup`、文件授权、分享、多窗口 UI 或设备验证。无项目的新草稿在首次保存前尚无撤销历史。旧 JSON 设置仍不能无损导入；用户导入的 LUT 尚未进入导出计划。打开另一项目与进行中的导出任务间还需要身份隔离契约。完整 Xcode 构建、XCTest、模拟器和真机验证未执行。

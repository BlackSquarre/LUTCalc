# H12 未保存编辑切换保护阶段验收

日期：2026-09-24。状态：模型层阶段通过，H12/APP-04/FLOW-04 尚未完成。

## 契约与实现

先扩充 `LUTSessionChecks`：未保存的新草稿和已打开项目的编辑，默认打开另一项目都应抛出 `unsavedChanges`，并完整保留原设置；即使项目已保存，不完整的曝光输入草稿也不得被无提示丢弃。只有调用方明确传入 `discardUnsavedChanges: true` 时，才可放弃当前编辑并切换。契约先因错误类型缺失而编译失败。

`EditorSession` 新增 `hasUnsavedChanges`，综合项目包的精确脏状态、尚未保存的新草稿语义修改与未提交的曝光输入。打开项目默认保护现有编辑；显式丢弃仅作为后续 UI 确认后的模型入口，当前草稿 UI 尚未提供该确认交互。打开失败时不替换原会话。

## 修改文件与源码版本

| 文件 | 内容 | SHA-256 |
| --- | --- | --- |
| `Native/Packages/LUTKit/Sources/LUTSharedUI/EditorSession.swift` | 脏状态判断与切换守卫 | `fdc7c2c20d25ad7699ff502013031e13a076454d14464906d26b235727ff290f` |
| `Native/Packages/LUTKit/Sources/LUTSessionChecks/main.swift` | 新草稿、已有项目与不完整输入的保留契约 | `29d14beac9880a84293386b01440af2f052c340fb17ffa2ffd413a2136b42e18` |

## 实际验证

- 工具链：Apple Swift 6.2.1，arm64 Command Line Tools；无完整 Xcode/iOS SDK。
- `swift build --package-path Native/Packages/LUTKit --product LUTSessionChecks` 在契约先行时退出码 1，缺少 `unsavedChanges`；实现后 `swift run --package-path Native/Packages/LUTKit LUTSessionChecks` 退出码 0。
- `tools/native-validation/verify-native-subset.sh > /tmp/lutcalc-h12-unsaved-switch-20260924.log 2>&1` 退出码 0。静态边界覆盖 40 个 Swift 源文件，旧 Node 测试 9/9 通过；新 H12 守卫及其余 Release 子集契约通过。本阶段不改变数值算法或误差门槛。

## 未覆盖范围

系统打开/保存 UI 与显式丢弃确认尚未实现，多窗口冲突的 UI 恢复流程、Files/File Provider、XCTest 以及双端 App/设备验证尚未完成。模型层守卫并不代表 H12 完成。

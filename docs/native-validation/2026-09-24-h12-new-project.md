# H12 新项目编辑会话阶段验收

日期：2026-09-24。状态：模型层阶段通过，H12/APP-04 尚未完成。

## 契约与实现

先在 `LUTSessionChecks` 要求新项目首次保存前就是独立的完整 `ProjectEditingSession`：它应被视为未保存，编辑曝光后可撤销和重做；首次另存为后项目读回保留精确值并恢复干净状态。契约先因 `newProject` 缺失而编译失败。

`EditorSession.newProject()` 创建默认 D-Log2/D-Gamut2 → 线性 AP0 的原生项目会话，分配新文档 ID，复用完整清单的历史与保存逻辑。已有未保存编辑时默认拒绝新建；显式丢弃参数留给后续界面确认调用。新建时旧导出请求身份失效。

## 修改文件与源码版本

| 文件 | 内容 | SHA-256 |
| --- | --- | --- |
| `Native/Packages/LUTKit/Sources/LUTSharedUI/EditorSession.swift` | 新建完整项目会话 | `7092fd19150905a581dc4a80193974e53b6732d1485a07c4f97aba0dd70036f6` |
| `Native/Packages/LUTKit/Sources/LUTSessionChecks/main.swift` | 保存前历史及保存后状态契约 | `244d550a66769a074cdb41990530da7e1e6689f95f8f68828c88c76faad7da56` |

## 实际验证

- 工具链：Apple Swift 6.2.1，arm64 Command Line Tools；无完整 Xcode/iOS SDK。
- `swift build --package-path Native/Packages/LUTKit --product LUTSessionChecks` 在契约先行时退出码 1，缺少 `newProject`；实现后 `swift run --package-path Native/Packages/LUTKit LUTSessionChecks` 退出码 0。
- `tools/native-validation/verify-native-subset.sh > /tmp/lutcalc-h12-new-project-20260924.log 2>&1` 退出码 0。静态边界覆盖 40 个 Swift 源文件，旧 Node 测试 9/9 通过；新增会话契约和既有 Release 子集通过。本阶段不改变数值路径或误差门槛。

## 未覆盖范围

草稿 UI 尚无新建/打开/保存按钮或丢弃确认；系统项目包类型、Files/File Provider、XCTest 与双端构建/真机验证未完成。旧单文件设置仍只读识别，不能导入。此项不表示 APP-04 全项通过。

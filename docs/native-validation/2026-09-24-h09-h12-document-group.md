# H09/H12 双端 DocumentGroup 草稿接线阶段验收

日期：2026-09-24。状态：工程与共享代码阶段通过；H01/H09/H12、FLOW-03/FLOW-04 和双端平台验收均未完成。用户将另行设计正式 UI，本阶段只有功能草稿。

## 契约与实现

在[FileDocument 包适配阶段](2026-09-24-h12-file-document.md)之后，先扩充 `LUTDocumentChecks`：新建系统文档必须有已知 D-Log2/D-Gamut2 默认设置；导出快照保留项目参数和域；含用户 LUT 资源的项目在该资源尚未进入计划时必须拒绝生成；文档内曝光修改及撤销/重做要保留 Double 符号零和资源清单。对应契约先因默认构造、导出快照及文档编辑接口缺失而编译失败，随后逐项实现。

两个 App 的场景均由 `WindowGroup` 切换为 `DocumentGroup(newDocument:)`，绑定同一 Swift `LUTProjectDocument` 和共享 `ProjectDocumentView`。草稿页直接修改绑定项目的完整清单，可撤销/重做、编辑输入范围/曝光/输出目标/3D 尺寸并从当前文档快照导出 CUBE；后台请求按身份提交结果，取消按钮调用任务取消。系统文档负责项目打开/保存的 UI 生命周期，生成的 CUBE 继续使用系统分享入口。旧 `ContentView`/`EditorSession` 暂保留作为已验证的会话草稿与契约目标，不作为当前两个 App 的场景入口。

按[Apple 文件类型声明](https://developer.apple.com/documentation/uniformtypeidentifiers/defining-file-and-data-types-for-your-app)及[XcodeGen ProjectSpec](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md)，两个 App 均声明 exported `org.lutcalc.project`，符合 `com.apple.package`/`public.content`，扩展名 `.lutcalc`，并登记可编辑的 package 文档类型。iOS 声明在原位置打开。用 XcodeGen 2.46.0 重新生成项目和 plist；生成前将原项目副本保存于 `/tmp/lutcalc-xcodeproj-before-documentgroup-20260924`，生成后的工程差异为 10 行，仅是 Info.plist 引用变化。没有清理用户文件。

## 修改文件与源码版本

| 文件 | 内容 | SHA-256 |
| --- | --- | --- |
| `Native/Packages/LUTKit/Sources/LUTSharedUI/LUTProjectDocument.swift` | 默认项目、完整清单历史、导出快照 | `b893c839c24d4bf2ac473c5d3f1145bdda52c185f50c3eda4abc1c8675b841dd` |
| `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift` | 绑定文档的双端 SwiftUI 功能草稿 | `66e86927c44ffa8ed9ad70be6e9a282098d11d4627edf978f48c95bae81b740d` |
| `Native/Packages/LUTKit/Sources/LUTDocumentChecks/main.swift` | 默认、历史和导出快照契约 | `4ebac62fce07b7b9e1be3620f4a42571cce0917f461b3f8c5dfd8d099c181315` |
| `Native/Apps/macOS/LUTCalcMacApp.swift` | macOS `DocumentGroup` 场景 | `80e48b5cb33daa9fe9fabacbfc744c4bc50516ae28edcbcb19c209c3348ccd4b` |
| `Native/Apps/iOS/LUTCalcIOSApp.swift` | iOS/iPadOS `DocumentGroup` 场景 | `a2dbadcc4b2c5f1783ab13192c23dc6eeeddf14b45a5da8572ca5f11150b6e0d` |
| `Native/project.yml` | 项目包声明及 Info.plist 生成配置 | `9ac8208108a9e5a6e533df67c01dc194da9e48b47bb893550beaab88dc30d33b` |
| `Native/Apps/macOS/Info.plist` | macOS 导出类型和编辑器声明 | `e7e5916a785f0f6893a40640ec1bf4927366b5dfac6cb9c41333833b208f048c` |
| `Native/Apps/iOS/Info.plist` | iOS 导出类型、编辑器及原位打开声明 | `e96fed48dbcc8db569c6d1235cc67243d40c34ce9fd3f18960970fbf63edea59` |
| `Native/LUTCalc.xcodeproj/project.pbxproj` | 生成工程引用新 plist | `7120c086fc55d41357085f02f31a418f4050240aee7e2f9a02d0a799ce00223e` |
| `tools/native-validation/verify-native-document-types.py` | 双端文档元数据契约 | `84d3c90b689f945b439346952be904f51fa91792dfe3ac313276e34687701576` |
| `tools/native-validation/verify-native-subset.sh` | 加入 plist 检查和 macOS App 入口类型检查 | `cbe8ac2dbb9e8b257b1f7745aac082ab6f8e2b0bdce5adb7342c4bae039796e3` |

## 实际验证与能力边界

- Apple Swift 6.2.1，arm64 Command Line Tools；XcodeGen 2.46.0。`xcodegen generate --spec project.yml` 在 `Native/` 退出码 0；`plutil -lint` 对双端 plist 和工程文件均通过；`python3 tools/native-validation/verify-native-document-types.py` 退出码 0。
- `swift build --package-path Native/Packages/LUTKit --target LUTSharedUI` 退出码 0；使用共享包模块路径执行 `swiftc -typecheck -parse-as-library -I Native/Packages/LUTKit/.build/arm64-apple-macosx/debug/Modules Native/Apps/macOS/LUTCalcMacApp.swift`，退出码 0。这是源码类型检查，不是 `.app` 构建或运行。
- `tools/native-validation/verify-native-subset.sh > /tmp/lutcalc-h09-document-group-20260924.log 2>&1` 退出码 0；静态边界覆盖 45 个 Swift 源文件，旧 Node 9/9，通过 Release 包、文档包契约、双端元数据和 macOS App 入口类型检查。文件/界面阶段无新增颜色误差，原有数值阈值未变。
- 实际执行 `xcode-select -p` 为 `/Library/Developer/CommandLineTools`；`xcrun --sdk iphonesimulator --show-sdk-path` 和 `xcodebuild -version` 均退出码 1，缺完整 Xcode/iOS SDK。因此无法运行 iOS 编译、macOS/iOS App 构建、模拟器、真机或 Finder/Files 文档操作。

## 未覆盖范围

`DocumentGroup` 的真实自动保存、文件协调、外部授权失效、同一项目多窗口冲突与 Finder/Files 往返仍需平台验证。项目包内用户 LUT 只可保存、读回并显式拒绝导出，尚未进入变换计划。当前 UI 只覆盖首条草稿链路，没有相机、完整格式、调节、分析与正式设计。旧单文件 `.lutcalc` JSON 与新 package 同扩展名；系统文档入口只接受新 package，旧 App JSON 会被明确拒绝且不进入迁移流程。项目 `FileWrapper` 的资源内存上限不能代替真机预算测量。完整迁移与发布门槛未通过。

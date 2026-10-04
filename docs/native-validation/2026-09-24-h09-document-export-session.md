# H09 文档导出会话阶段验收

日期：2026-09-24。状态：文档场景的导出身份与 17³ CUBE 命令行链路通过；双端 App 运行、文件分享和发布验收未完成。UI 仍是功能草稿。

## 契约先行与实现

先新增 `LUTDocumentExportChecks`，覆盖项目 A 开始导出后改为 B、取消 A 后启动新请求、旧成功晚返回、失败后的部分输出、关闭文档后的晚返回，以及含用户 LUT 的项目必须拒绝导出。首次运行因 `ProjectExportSession` 尚不存在而编译失败；随后实现并接入共享 SwiftUI 草稿。

`ProjectExportSession` 由单个文档窗口持有。开始时生成不可变 `LUTGenerationRequest`，报告使用请求时的设置与修订号；取消后可开始新请求，旧任务即使忽略取消并晚返回也只清理本次输出，不改变新任务状态。关闭窗口使会话失效并取消活动任务。错误和取消路径清理其任务输出。草稿页保留精确曝光输入、撤销/重做和系统分享入口，导出按钮现在调用此会话。

契约还使用真实 `NativeExportService` 写出 17³ CUBE，再由 `CubeParser` 读回 4913 个节点。可控测试服务只用于任务顺序和错误注入；真实链路使用现有 Double 生成器。此阶段没有改变颜色公式、网格尺寸、插值或误差阈值。

## 修改文件与版本

本表记录 H09 阶段当时的源码版本；后续 H13 取样接线更新了其中的界面、包声明与验证入口，见[H13 文档取样记录](2026-09-24-h13-document-sampling.md)。

| 文件 | 内容 | SHA-256 |
| --- | --- | --- |
| `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectExportSession.swift` | 文档窗口导出会话、取消和过期结果清理 | `da9d355518dc17f848182692f4b36da223c77754eefd1f91a914a72cc9b8f8fb` |
| `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift` | 草稿页接入会话 | `c3a974698791bf0cf3c8eeff794dcb09acc83a7911d0387f96d3e750697e598f` |
| `Native/Packages/LUTKit/Sources/LUTDocumentExportChecks/main.swift` | 强制乱序、失败、关闭和真实 CUBE 读回契约 | `5fdfc10fde5948731b75fcb70fbb4f0ed3cc5504f3e645d4dead1b382b544bad` |
| `Native/Packages/LUTKit/Package.swift` | 注册可执行契约 | `5cd33194f0043a9f20d9bf42c4587ce7d0e9a7c28b1b8e86dcfb9e75a847866f` |
| `tools/native-validation/verify-native-subset.sh` | 纳入日常验证入口 | `b16d17383208e9099441815d0d0807cb7b17706b01c94e36dbb2a4d798bf3f86` |

## 实际命令与结果

- 工具链：Apple Swift 6.2.1，arm64 macOS Command Line Tools；`xcode-select -p` 为 `/Library/Developer/CommandLineTools`。
- `swift run -c release --package-path Native/Packages/LUTKit LUTDocumentExportChecks`：先因缺少会话类型而编译失败；实现后退出码 0。验证旧请求不能覆盖新请求、任务输出清理和真实 17³ 写出/4913 节点读回。
- `tools/native-validation/verify-native-subset.sh > /tmp/lutcalc-h09-export-session-20260924.log 2>&1`：退出码 0；静态边界覆盖 47 个 Swift 源文件，旧 Node 与 Release 原生契约通过；macOS App 入口源码类型检查通过。旧数值契约的冻结阈值未变，详见该日志。
- 本阶段 UI 为源码编译与类型检查，未实际启动 `.app`。本机缺完整 Xcode/iOS SDK，无法执行 iOS/iPadOS 构建、模拟器/真机、系统分享、后台与 Finder/Files 验证。

## 未覆盖范围

项目生成的 CUBE 目前先放在任务拥有的临时 URL，再交给 `ShareLink`；真实分享完成时机及临时文件生命周期仍需平台验证。窗口关闭的 `onDisappear` 与系统文档生命周期、自动保存、文件协调及不同 File Provider 尚未实测。更完整的多页面 UI、进度展示和正式设计留在后续 H09/UI 工作；本阶段不能勾选 H09、FLOW-02/03 或发布门槛。

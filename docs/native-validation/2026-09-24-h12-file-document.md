# H12 项目包 FileDocument 适配阶段验收

日期：2026-09-24。状态：包模型阶段通过；`DocumentGroup` 场景已在后续阶段接入但未做双端实际文件交互，H12/APP-04/FLOW-04 未完成。

## 契约与实现

按[原生设计的项目条款](../native-swift-design.md)建立 SwiftUI `FileDocument` 适配，文件类型为 exported `org.lutcalc.project`，父类型为系统 package。先写可执行契约：完整清单和用户 CUBE 资源经 `FileWrapper` 往返，`-0.0` 的 Double 位模式、12-bit 范围与资源字节必须保留；系统 `FileWrapper` 写盘后，既有 `ProjectStore` 必须能打开；从磁盘重建的 `FileWrapper` 也必须能由文档适配读回。未知顶层文件、资源哈希不符及超限清单都应明确失败。契约首次编译因适配类型及 Data 哈希入口缺失而失败。

新增 `LUTProjectDocument`，读取时经现有 `ProjectCodec` 验证算法 ID、版本和数值，严格检查目录条目、资源名、资源类型及 SHA-256；写出前再次验证。内存适配的项目资源总量限定 256 MiB，单个资源沿用既有 256 MiB 上限。清单限制为 8 MiB，`ProjectStore.open` 在读取前检查文件大小，编码/解码也执行相同限制；该限制只保护文件读取，不改变 LUT 生成网格或 Double 精度。

## 修改文件与当时源码版本

| 文件 | 内容 | SHA-256 |
| --- | --- | --- |
| `Native/Packages/LUTKit/Sources/LUTSharedUI/LUTProjectDocument.swift` | `FileDocument`/`FileWrapper` 项目包双向适配 | `21b57f958d94097e297926097094461ef9a09dab3b274c914f2548e594dfc3fd` |
| `Native/Packages/LUTKit/Sources/LUTProject/ProjectManifest.swift` | Data 哈希和清单读取上限 | `c98c64ad184b18504fe2db49214daab4cdb36fe502d10c6c576389169da4d840` |
| `Native/Packages/LUTKit/Sources/LUTDocumentChecks/main.swift` | 包、磁盘互通、篡改和上限契约 | `8889e897a9a44d3df0105e019b2d1a29c72489b35c34f8258c10a0c723b3a4e2` |
| `Native/Packages/LUTKit/Sources/LUTProjectSessionChecks/main.swift` | `ProjectStore` 超限清单契约 | `2fb439213e5b0f924dcdbd27b59e4a4bab659770749bff27ee8b75801802fd7e` |
| `Native/Packages/LUTKit/Package.swift` | 增加文档契约目标 | `ab77c188dbf3e485311ec72e15fcba317f5dba5bf06f88fc31b76e323f45cc45` |
| `tools/native-validation/verify-native-subset.sh` | 新契约纳入 Release 子集 | `461631f5310907c0bb2ed50e7604db329d9b144854a32beeda557045dca96e0f` |

## 实际验证

- 工具链：Apple Swift 6.2.1，arm64 Command Line Tools。`swift build --package-path Native/Packages/LUTKit --product LUTDocumentChecks` 在契约先行时退出码 1，缺少 `LUTProjectDocument` 和 Data 哈希入口；实现后 `swift run --package-path Native/Packages/LUTKit LUTDocumentChecks` 退出码 0。
- `LUTProjectSessionChecks` 的超限清单契约也先因上限类型不存在而编译失败，实施后通过。磁盘互通使用本任务临时目录和原有 `ProjectStore.open`，未触碰用户项目。
- `tools/native-validation/verify-native-subset.sh > /tmp/lutcalc-h12-file-document-20260924.log 2>&1` 退出码 0。静态边界覆盖 44 个 Swift 源文件，旧 Node 9/9 通过，Release 包及既有数值、项目和任务契约通过。本阶段是文件结构与字节往返，无新增颜色数值误差；原有门槛未改。

## 未覆盖范围

当前仍由两个 App 的 `WindowGroup` 显示旧草稿页；系统 `DocumentGroup`、bundle 类型声明、文件协调、外部 URL 授权期、Finder/Files 保存回写和多窗口 UI 尚未接入。`FileWrapper` 适配会把用户资源载入内存，虽然有总量上限，仍需真机内存测量与更大资源的流式方案。旧单文件 `.lutcalc` JSON 设置只读识别，不能作为此 package 打开。XCTest、macOS/iOS App 构建、模拟器/真机和发布验收尚未执行。

本段“未接入”描述该阶段当时状态；后续场景接线见[H09/H12 DocumentGroup 阶段验收](2026-09-24-h09-h12-document-group.md)，仍无实际 App/设备验证。

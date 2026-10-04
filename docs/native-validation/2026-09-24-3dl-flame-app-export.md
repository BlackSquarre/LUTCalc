# `.3dl` Flame/Assimilate App 导出阶段验收

日期：2026-09-24。范围：将已验收的 Flame/Assimilate 整数 `.3dl` 子集接入原生功能草稿的文件导出；不代表 Lustre/Kodak 方言、第三方兼容或 FULL-06 完成。

## 实现与边界

- `ThreeDLWriter` 新增与原整表写出共用的线性 shaper/元数据头，以及 12-bit 固定宽度整数行。沿用 10-bit 输入、12-bit 输出的旧 Flame/Assimilate 默认位宽，half-up 量化，不裁剪负值或超白。
- `FileCubeSink` 新增 `.3dl` 分支。分块生成仍使用 LUTCore 红轴最快顺序；单 writer 将固定宽度行定位到 Flame 文件的红轴外层、蓝轴内层位置。仅在临时文件中定位写入，节点全部写完且字节数核对后才提交；不构造整张 3D 文本或节点数组。非单位输入域、超出 0...1 的输出值会明确失败。
- `NativeExportService` 通过既有扩展名分派识别 `.3dl`；`ProjectExportSession` 形成 `.3dl` 分享文件。`ProjectDocumentView` 的格式选择增加“3DL Flame / Assimilate”，并提示位宽和可表示范围。项目设置和其余格式语义未改变。

## 先失败后通过的契约

先新增 `ThreeDLExportContractsTests.swift` 和 `ThreeDLServiceContractsTests.swift`。首次定向构建因 `FileLUTFormat.threeDL` 不存在而失败；随后修正测试自身的 Swift 并发断言写法，再实现格式分支。最终 `swift test --package-path Native/Packages/LUTKit --filter 'ThreeDL(Export|Service)ContractsTests'`：5 项通过、0 失败。`swift test --package-path Native/Packages/LUTKit`：全包退出码 0。工具链 Apple Swift 6.4，arm64 macOS / Xcode 27.0。

契约覆盖跨块 2³ 非对称节点的文件轴序、half-up 量化与解析读回、非单位域及负输出拒绝、已有文件默认拒绝覆盖、部分写入后取消保留旧目标、导出服务扩展名分派，以及文档会话 17³ 文件生成和解析读回。服务成功用例的输入设置为 video 范围，以避免矩阵往返微小负数触发该有损整数格式的正确拒绝；它不是精度阈值变更。

本次没有在目标 Flame/Assimilate 软件中导入文件，也没有使用真机或系统分享面板实测。其他 `.3dl` 方言、格式位宽选项、65³ 性能、Files/File Provider 事务及完整迁移仍待后续验收。当前功能草稿如果设置产生域外输出，会返回失败而不是静默裁剪。

## 源码指纹

- `Native/Packages/LUTKit/Sources/LUTFormats/ThreeDL.swift`：`b47cfaaf994a6c02de29f4f4ed6ccd03e3eb1d7348f27ba7fdf34172b1b3cc37`
- `Native/Packages/LUTKit/Sources/LUTJobs/FileCubeSink.swift`：`11f54dfae3e5dacdbdd650363a2f32ea54d14f2f42d13a57cbc58cbb2a2e1d67`
- `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift`：`12b4f7b784a25879b4c523b02db206d5ee3f5ad084a7f7d3f3c31df167e0f0eb`
- `Native/Packages/LUTKit/Tests/LUTJobsTests/ThreeDLExportContractsTests.swift`：`d6fbf5fa635b823d13bbc3e2fc620a5e2d507a40e1dda3b6ec3a82bc4f26bd07`
- `Native/Packages/LUTKit/Tests/LUTSharedUITests/ThreeDLServiceContractsTests.swift`：`40f8538829fd30bee111ac67df9ff895efdb267e629cf5d3a43803d9d8516482`

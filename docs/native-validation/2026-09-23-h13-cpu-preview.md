# H13 CPU Double 预览取样基础记录

日期：2026-09-23。此阶段只建立不依赖屏幕截图的 CPU 数值取样内核；图像文件解码、色彩配置、Core Image 显示和完整界面仍未实现。

## 契约先行与实现

先写 `LUTPreviewChecks`，固定 3 个已知 RGBA Double 像素：不透明、半透明预乘、透明但隐藏 RGB 非零。要求负值与超白不被裁剪；输入预乘先解包，计划变换后按请求重新预乘；透明像素最终 RGB 为零；取样坐标、请求版本及 alpha 模式可查询。首次运行按预期因预览类型未实现而编译失败。实施后又用 D-Log2 透明样本发现“只清零输入仍会因 Log 解码产生非零输出”的失败，补充透明像素跳过计划求值且输出零的明确策略，复跑通过。

新增 `LUTPreview/CPUPreview.swift`，定义 `RGBA64`、不可变 `PreviewRequest`、逐像素 `PreviewSample`、`PreviewResult` 和版本接纳门。每像素使用 `TransformPlan` 的 Double 路径；结果保留输入/输出 alpha 模式、设置快照、请求版本以及计划前后数值，避免从 8-bit 屏幕像素推断精确结果。图像宽高与像素数量需一致，乘法溢出和超过 400 万像素的请求会拒绝。`PreviewRevisionGate` 仅接受与最新版本相同的结果，旧版本即使晚到也不能被接纳；实际异步预览任务调度还未接入。

实际运行：

```text
swift run --package-path Native/Packages/LUTKit LUTPreviewChecks
swift run -c release --package-path Native/Packages/LUTKit LUTPreviewChecks
swift build -c release --package-path Native/Packages/LUTKit
```

三条均通过。Double 数值对照：曝光 +1 后输入 `(0.09, 0.18, -0.09)` 得 `(0.18, 0.36, -0.18)`；半透明预乘输入在解包后得到相同计划值，重新预乘时为 `(0.09, 0.18, -0.09)`；透明 D-Log2 样本不会泄漏隐藏 RGB。固定尺度化阈值 `2e-12`，未改动网格/位宽/插值。溢出尺寸、alpha>1 与旧版本拒绝也通过。

源码 SHA-256：`LUTPreview/CPUPreview.swift` 为 `e97322686d4b1f1379c8bf692046552188d2ebc71a739f55ef9beeab29480bb2`；`LUTPreviewChecks/main.swift` 为 `3e1d20f5dd1358bc50d350bd61366d7b0bd8a9bec18df9ee15c17997c85e7786`；`Package.swift` 为 `7c1c4a1bb4af4f3273a1755b7f6cd6f3ab0c562a552202bde6e0fc90f7b9455c`。另增 `Tests/LUTPreviewTests/PreviewContractsTests.swift`，本机缺 XCTest，未执行。

## 未覆盖

请求目前假定调用方已按计划输入曲线/色域提供 RGB Double；尚无 JPEG/PNG/TIFF 解码、ICC/嵌入空间处理、ImageIO 位深对照、显示空间/EDR 映射、Core Image 加速或真实图像样本。版本门只负责判断，异步取消与迟到错误是否丢弃未在 App 集成验证。macOS/iOS `.app` 及真机预览均未验证，H13/FLOW-05 不勾选；UI 保持草稿，等待用户另行设计。

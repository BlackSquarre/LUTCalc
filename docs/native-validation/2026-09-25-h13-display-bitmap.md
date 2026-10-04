# H13 sRGB 显示位图阶段验收

## 实现与边界

上一阶段的 `DisplayPreviewResult` 已有明确的 sRGB 显示数值，本阶段新增独立 `DisplayPreviewBitmap`，并把位图量化移入后台预览任务。它只在显示边界把每通道 Double 值按最近偶数舍入到 RGBA8，并用显式 sRGB `CGColorSpace` 建立 `CGImage`；数值取样、项目设置和文件导出均不读取该位图。SwiftUI 功能草稿直接显示该图像，保留 320 点高度的临时布局，视觉设计后续另做。

## 验证

- `testDisplayPreviewBitmapQuantizesOnlyAtExplicitDisplayBoundary` 固定检查 `0.5/0.25/0` 线性 sRGB 与 `0.5` alpha 显示字节 `[188, 137, 0, 128]`、`CGImage` 创建和原 Double 值保持。
- 定向 Release 契约先加入，再实现并通过；当前 `PreviewContractsTests` 20 项通过。
- 合并 H12 后完整 Swift Release 回归 178 项与 macOS/iOS Simulator/iOS generic Release 构建通过。三个 App 包资源审计已通过；发布门槛仍因全量清单缺失退出 2；不能据此宣称完整 H13 或发布通过。

## 后续

仍需真实屏幕显示核对、色彩管理与 ICC 工作空间边界、HDR/EDR、Core Image/Metal 等价性及真机交互。真机项目按用户要求最后集中处理。

## 集中回归证据

- Swift Release 测试：`/tmp/lutcalc-h13-display-bitmap-swift.log`，退出码 0，SHA-256 `ec487f570788df4dd9e3bca5186c1d8ece375108990206b7779be5c322b3acd2`。
- macOS Release：`/tmp/lutcalc-h13-display-bitmap-mac.log`，退出码 0，SHA-256 `4632f939478b98085731d38ad02d592690a65645fa2dc9d16eacf3ff42897c67`。
- iOS Simulator Release：`/tmp/lutcalc-h13-display-bitmap-iossim.log`，退出码 0，SHA-256 `93be21123238dad287bd5e8178fe02a8f8e97628c5eaec367db68fcba6537be7`。
- iOS generic Release：`/tmp/lutcalc-h13-display-bitmap-ios.log`，退出码 0，SHA-256 `aafdae9d40708bf5ed2813248639b11f0f598e0736897a18935368058edae814`。

App 包资源审计：三个本批 Release App 包退出码 0，未发现列出的 LUT/脚本文件或 WebKit/JavaScriptCore 直接链接；该检查不能证明二进制没有等价采样表。发布证据检查退出码 2，因真实 `docs/native-validation/full-scope-acceptance.json` 尚未建立；日志 `/tmp/lutcalc-h13-display-bitmap-release-gate.log`，SHA-256 `6f53f51342a12077a132f6a477330eeeb0aaac7ab614c30e15363209cff1e86e`。

后台取消补充：显示任务取消时同步取消 detached 渲染任务；CPU Double 整图计算与 RGBA8 量化每 4096 像素检查取消，晚返回继续由四字段身份门控拒绝。该补充后定向 `PreviewContractsTests` Release 20 项通过，日志 `/tmp/lutcalc-h13-display-bitmap-targeted.log`。

性能边界补充：显示路径复用每像素评估逻辑，不再先保存完整 `PreviewResult` 再创建显示位图；整图显示仍保持 Double 计算、分块取消检查和独立 RGBA8 输出。


合并 H12 格式候选后的全包日志见 `/tmp/lutcalc-after-h13-bitmap-h12-full.log`；发布入口结构检查见 `/tmp/lutcalc-after-h13-bitmap-h12-release-gate.log`，因缺少真实全量清单退出 2。

`verify-native-subset.sh` 合并检查通过，包含真实 ImageIO 夹具、LUTDocumentSampleChecks 后台位图生成、批量数值和全部原生子集命令行契约；日志 `/tmp/lutcalc-h13-display-h12-subset.log`，退出码 0，SHA-256 `c6adfc4c1f5aedfb872cbdf32afba15b2967aa2a6b48ad1191673cd10d022fe8`。

H12/H13 合并后的三个 App 构建退出码均为 0：

- macOS Release：`/tmp/lutcalc-h13-display-h12-mac.log`，SHA-256 `58824c001bafbfeb653659686aa2f733f4821cb0a4065841d4dbf4b8bc02e241`
- iOS Simulator Release：`/tmp/lutcalc-h13-display-h12-iossim.log`，SHA-256 `f899a5ff7edeb307d60370bc2b038c3d6695ec2b590be8ecd79a17959f46e960`
- iOS generic Release：`/tmp/lutcalc-h13-display-h12-ios.log`，SHA-256 `890a15c71e50c1a43aa5b1051176f2c3afc315e4c47d2916e3373747fec625a6`

三个 App 包资源审计退出码 0；发布证据门槛仍退出码 2，缺少真实全量验收清单。

alpha 补充契约先出现 1 项预期字节差异（预乘 G 通道应为 68 而非 69），修正量化期望后通过；当前定向 `PreviewContractsTests` 21 项、合并全包 Swift Release 回归 179 项通过。定向日志 `/tmp/lutcalc-h13-premul-targeted-pass.log`，SHA-256 `7bff5b10e0859b84bf1ff8a49f7cc502387b5d2cef1e482661166c8dc006b7cf`；全包日志 `/tmp/lutcalc-after-premul-full.log`，SHA-256 `22d1b014983ef624a8c871d66aafe128fc367eee5675b9f2688653f77da0f99e`。

源解释门控补充：显示预览现在必须先确认按当前项目输入曲线和色域解释图像；未确认时只报告失败状态，不创建后台任务或位图。`LUTDocumentSampleChecks` 已覆盖拒绝和确认后成功，`verify-native-subset.sh` 退出码 0，日志 `/tmp/lutcalc-h13-display-source-gate-subset.log`，SHA-256 `1b184b9f69a32ba8e1fe2e5038ef7b8b92e8dc1fb32e44633a8fc374f707a94d`。三个平台 Release 构建仍通过。

源确认门控后的当前 Swift Release 全量回归仍为 179 项，退出码 0；日志 `/tmp/lutcalc-current-final-swift.log`，SHA-256 `71ae0ba38e8fa1f1f9da99f477b247e7217d678df4209453cb3c84c3757cdcb5`。

源确认门控后的三平台 Release 构建仍退出码 0：macOS 日志 `/tmp/lutcalc-h13-source-gate-mac.log` SHA-256 `8251dc81595a2362fbbd24a883b9a0d5e66d9d24a20c93418cc8a47bcb71e25e`；iOS Simulator `/tmp/lutcalc-h13-source-gate-iossim.log` SHA-256 `5f28b8966a3b708e3f703a6f14e655e3eacb0bab6b472b9b10f5c615903b4601`；iOS generic `/tmp/lutcalc-h13-source-gate-ios.log` SHA-256 `195e227e55e91f5e8283cb2cb0b3d1b82662c62545e4c30ee0abe6c56e604974`。

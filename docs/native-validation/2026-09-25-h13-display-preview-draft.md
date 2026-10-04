# H13 图像显示预览草稿阶段验收

## 范围

本阶段把 H13 的整图 CPU Double 计算与屏幕显示映射接通到功能草稿。数值取样和文件导出继续使用 `PreviewResult`，显示结果使用独立的 `DisplayPreviewResult`，二者不互相回写。

## 实现

- `CPUPreview.renderDisplay(_:)` 先运行既有 `TransformPlan`，再把计划最终输出按其 `outputRange`、`outputTransfer` 和 `outputSpace` 解释回场景线性值。
- 显示工作计划明确转换到线性 sRGB D65，最后使用 W3C extended sRGB OETF 编码。
- 负值和超白值只在显示编码的最后一步夹取到 SDR 显示范围；取样和导出仍保留 Double 参考结果。
- 预乘 alpha 在显示映射后按请求重乘，透明像素不泄漏隐藏 RGB。
- `rec2100HLG` 因缺少 OOTF、峰值亮度和参考白参数暂时返回明确的 `unsupportedDisplayTransfer`，不猜测 SDR 映射。
- `ProjectSampleSession.startDisplayPreview` 使用后台任务、取消检查和文稿 ID/修订/请求/计划版本身份门控；切换图像或文稿、关闭会话会清除或拒绝迟到结果。
- 功能草稿加入“生成屏幕预览”按钮和目标/尺寸状态，不把显示结果作为 LUT 输入。

## 契约与验证

- 新增 `PreviewContractsTests.testDisplayPreviewUsesIndependentLinearSRGBEncodingAndFinalClamp`，覆盖 sRGB 同空间、W3C OETF、负值/超白最终夹取、alpha 保留和身份回传。
- 定向 Release `PreviewContractsTests`：19 项通过。
- 集中 `swift test --list-tests`：174 项；完整 Swift Release XCTest：通过。
- `swift build -c release --package-path Native/Packages/LUTKit`：通过。

## 未完成边界

本阶段尚未接入 Core Image/Metal、HDR/EDR、完整 ICC 工作空间转换、真实屏幕位图创建、Files 往返或真机验证；不能据此勾选完整 H13、FLOW-05、UI-03 或发布门槛。真机 SPI3D 及 Files 项目按用户安排最后集中处理。

完整 Swift Release 日志：`/tmp/lutcalc-h13-display-preview-release-full.log`，退出码 0，SHA-256 `a9953d46379a35a0283d41d541a622eb79df241dc554e2b33aa10f110c26863b`。本次集中入口共 174 项测试；新增 HLG 缺少 HDR 显示参数时拒绝的契约。

补充构建证据：`swift build -c release --package-path Native/Packages/LUTKit` 退出码 0，日志 `/tmp/lutcalc-h13-display-preview-build.log`，SHA-256 `1485238a195e2abe85e4febb92449146773ceac4363f44aab21eeef1488f24d8`。

补充平台构建证据：`LUTCalcMac` macOS Release、`LUTCalcIOS` iOS Simulator Release 和 iOS generic Release 均退出码 0。日志及 SHA-256：

- `/tmp/lutcalc-h13-display-preview-mac-build.log` — `dd766f9d11915d8c50b20cc202be090fa96526a1863fed682f51c0ce54665a1f`
- `/tmp/lutcalc-h13-display-preview-iossim-build.log` — `dac70caf285a6ee9f4136dcf1680576de268d8309b37389bd7d8de7ff0405049`
- `/tmp/lutcalc-h13-display-preview-ios-build.log` — `cab75c12a7ea04fa370059b406ba020bc0980175df2c4fe1c8e082c7049f5b02`

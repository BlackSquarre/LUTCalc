# H13 源文件 ICC 与 ImageIO 色彩空间来源阶段验收

日期：2026-09-24。状态：来源区分契约通过；不执行隐式颜色转换，H13/UI-03 仍未完成。

## 契约先行

先在 `LUTImageChecks` 增加来源契约，要求无 ICC 元数据的 RGB PNG 标为 `sourceICCUnverified`，而不是把 `CGImage.colorSpace` 或 `copyICCData()` 当作源文件嵌入资料；带 PNG `iCCP` 块且 ImageIO 报告 `kCGImagePropertyProfileName` 的样本标为 `sourceEmbeddedICC`。两种样本的原始 RGB/alpha 数值必须完全相同，来源字段不能触发颜色转换。首次运行因 `PreviewImage` 尚无来源字段而按预期编译失败，随后完成实现。

## 实现与边界

`PreviewImage` 新增 `PreviewColorSpaceProvenance`、`sourceEmbeddedICCProfileName`。`PreviewImageDecoder` 仅把 ImageIO 在源属性中返回的 `kCGImagePropertyProfileName` 作为“源文件嵌入 ICC 已被 ImageIO 证实”的证据；没有该键时只报告“源 ICC 未证实”。`decodedICCProfile` 继续表示解码后 `CGColorSpace` 的 ICC 数据，不能据此反推源文件字节，也不启动 `CGColorConversionInfo`、Core Image 或任何隐式转换。方向重排完整保留来源字段。

草稿检查器同时显示“源文件嵌入 ICC”和“解码空间 ICC 资料”，避免把 ImageIO 推断/指定的空间写成已核对的源 ICC。UI 仍是功能草稿。

## 独立夹具与证据

`tools/native-validation/generate-preview-fixtures.py` 使用 macOS `/System/Library/ColorSync/Profiles/sRGB Profile.icc` 构造仅用于研发的 PNG `iCCP` 块；夹具不进入 App。无嵌入样本和嵌入样本的像素相同。ImageIO 实际属性为：嵌入样本 `ProfileName = sRGB IEC61966-2.1`，无嵌入样本不含 `ProfileName`；`sips` 也报告前者 `profile: sRGB IEC61966-2.1`、后者 `profile: <nil>`。

源码 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `Native/Packages/LUTKit/Sources/LUTPreview/PreviewImageDecoder.swift` | `41721bc5265ae4cd0540ee237036daa32f56ce76829387438de251d33cb8cfaf` |
| `Native/Packages/LUTKit/Sources/LUTImageChecks/main.swift` | `7ccc33661a8041af658df53242536aaf1f0ec2a285435362c71674f897fc66f8` |
| `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift` | `2b439036ee15b99643d1652732bf2d61a1d94247dcadbc7ef95e354671be4af8` |
| `tools/native-validation/generate-preview-fixtures.py` | `6a6e67aae8b9316d66240db9ed97ddf0e1e9f1e01c1866b37e88016d7a6ca687` |

临时夹具哈希：嵌入 ICC PNG `a70320c3ba8889a3495d0de8e7afc4228991d76340a6b33dec8a488600f92fd7`；无嵌入对照 PNG `894c9b3888193e859486d2a8766199834135a650236735673577ca16777688b2`。

## 实际验证

- 工具链：Xcode 27.0，Swift 6.4，arm64 macOS；使用 SDK 公开的 `kCGImagePropertyProfileName` 说明作为 API 语义依据。
- `swift build --package-path Native/Packages/LUTKit --product LUTImageChecks`：先因来源字段不存在失败，修改后通过。
- `python3 tools/native-validation/generate-preview-fixtures.py /tmp/lutcalc-h13-provenance-fixtures`：退出码 0。
- `sips -s format jpeg .../rgb8.png --out .../rgb8.jpeg`：退出码 0。
- `swift run -c release --package-path Native/Packages/LUTKit LUTImageChecks /tmp/lutcalc-h13-provenance-fixtures`：退出码 0；PNG 8/16 位、嵌入/未证实来源、TIFF 16 位、JPEG 元数据、alpha、方向和资源限制均通过，原始无损码值归一化误差 0。
- `swift build -c release --package-path Native/Packages/LUTKit --product LUTSharedUI`：退出码 0，草稿检查器的新来源字段可编译。
- `swift run -c release --package-path Native/Packages/LUTKit LUTDocumentSampleChecks /tmp/lutcalc-h13-provenance-fixtures`：退出码 0；显式源解释、Double 取样、项目修订、晚返回与关闭门控继续通过。

## 未完成与阻塞

ImageIO 的 `ProfileName` 是“已知嵌入 ICC”的可用证据，但缺少该键不能证明文件绝无 ICC，因此 API 只输出 `sourceICCUnverified`。尚未实现 ICC profile 字节级解析/校验、显示空间转换、显式 Log 输入、整图显示、Core Image、HDR/EDR、其他像素布局和双端真机验证。不能据此勾选 UI-03 或宣称 H13 完成。

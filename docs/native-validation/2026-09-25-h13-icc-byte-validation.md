# H13 嵌入 ICC 原始字节校验阶段验收

日期：2026-09-25。状态：H13 的一个非真机子集已完成；不代表完整预览、显示空间转换或发布验收完成。

## 先失败的契约

先在 `LUTPreviewTests.PreviewContractsTests` 增加 ICC 头部与摘要契约，要求：

- profile 长度字段必须等于实际字节数；
- profile signature 必须为 `acsp`；
- color space 和 PCS 字段必须是四字节合法签名；
- 校验结果提供固定长度的 SHA-256。

修正测试夹具的 `ArraySlice` 类型后，定向 Release 编译按预期失败，原因是 `ICCProfileValidator` 尚不存在。失败日志：`/tmp/lutcalc-h13-icc-red-20260925.log`；SHA-256：`2324a1973df14a3aaefa382ccae7db173f32e9becdfd71f99c101f9a655e74ff`。

## 实现

- 新增纯 Swift `ICCProfileValidator`，只做字节级来源校验和摘要，不启动任何隐式颜色转换。
- 新增 PNG `iCCP` 读取：校验 PNG chunk 边界、读取 profile 名称、解开 zlib 封装后保留原始 ICC 字节。
- `PreviewImage` 增加源 ICC 原始字节和校验资料；它们与 ImageIO 解码后的 `CGColorSpace` ICC 数据分开保存。
- 当前校验范围为 ICC 固定头部和 SHA-256，不声称完成完整 tag 解析、显示空间转换、Core Image 或 HDR/EDR。
- 后续 tag directory 的结构校验另见 [H13 ICC tag directory 阶段验收](2026-09-25-h13-icc-tag-directory.md)。
- PNG 没有可核对的 `iCCP` 时仍报告 `sourceICCUnverified`；已有的 ImageIO `ProfileName` 不再单独充当原始字节证据。

## 定向验证

- `swift test -c release --package-path Native/Packages/LUTKit --filter LUTPreviewTests.PreviewContractsTests`：3 项通过。
- 研发 PNG 夹具中的嵌入 profile 经过原始字节提取、zlib 解包、ICC 头校验和 SHA-256 记录；无嵌入 PNG、16 位 PNG、TIFF、JPEG、预乘 alpha、方向 1–8、资源预算和符号链接拒绝继续通过。
- `LUTImageChecks` 输出：嵌入 ICC 原始字节与头部校验通过；无损整数码值归一化误差为 0。

## 批量回归与平台构建

执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash tools/native-validation/verify-native-release.sh`。脚本沿用单次 Release 产品目录批量运行方式：

- 本阶段当时的 Swift Release XCTest：152 项通过，0 失败；后续增加 tag directory 契约后，当前总数为 155 项。
- 旧 Node 契约和 Python 资源审计通过；
- 既有 33³/65³ 曲线与格式逐节点检查继续通过；
- macOS、iOS Simulator、iOS generic Release 构建均 `BUILD SUCCEEDED`；
- 3 个 App 包资源审计通过，未发现所列 LUT/脚本资源或 WebKit/JavaScriptCore 直接链接；
- 完整入口最终退出码为 2，唯一直接原因仍是缺少真实 `docs/native-validation/full-scope-acceptance.json`。没有伪造该文件，也没有把本阶段称为完整迁移或发布就绪。

完整日志：`/tmp/lutcalc-h13-icc-release-20260925.log`；SHA-256：`6f1c103bccd8c6d7f3a5d535b66d75681c914d898a51d7ea498a8beb0b7bc87c`。

## 仍未完成

ICC 完整 tag 解析、跨 profile 颜色转换、显示空间和 EDR/HDR、其他像素布局、整图显示、iPad/真机预览、File Provider、Files 独立读回/取消及完整 H13/UI-03 验收仍未完成。真机连接不稳定的项目继续按用户安排最后集中处理。

# H13 ICC `clro` colorant order 阶段验收

日期：2026-09-25。Goal 仍 active。本阶段依据 ICC.1:2022 §10.4 增加 `colorantOrderType` 的只读 metadata 摘要，不执行颜色转换，不保存曲线、LUT 或其他等价采样表。

## 结构与边界

`clro` payload 固定为 8 字节 type/reserved、4 字节 UInt32 colorant count，以及恰好 count 个 UInt8 排列值。实现报告：

- `structureValue`：colorant count；
- `integerValues`：排列顺序；
- `textValue`、`fixedPointValues`、`signatureValue` 保持为空。

首段只校验 payload 自洽：长度恰好匹配、count 为正、排列无重复且每个值小于 count。紧接着按 ICC.1:2022 §10.4 的明确要求，补充与 profile header 设备色彩空间通道数的一致性检查。只对规范列出的 `GRAY`、三通道空间、`CMYK` 和 `2CLR`–`FCLR` 做确定映射；带 `clro` 的未知空间保守拒绝，不猜测通道数。

## 契约先行与验证

先加入 `PreviewContractsTests`，旧实现对正常摘要及五类非法 payload 均按预期暴露失败：截断、多余字节、重复索引、越界索引和零计数。实现后定向 Release 命令：

```text
swift test -c release --package-path Native/Packages/LUTKit \
  --filter LUTPreviewTests.PreviewContractsTests
```

结果：`PreviewContractsTests` 16 项通过，0 失败。

真实 ImageIO 夹具仍通过 `LUTImageChecks`，包含 RGB/灰度 PNG 8/16 位、嵌入 ICC、TIFF、JPEG、方向、预乘 alpha、资源预算、全 chunk CRC 和重复 `iCCP` 拒绝路径。

## 集中 Release 回归

执行 `bash tools/native-validation/verify-native-release.sh`，结果：

- `swift test --list-tests`：171 项；Swift Release XCTest 全部通过。
- 旧 Node/Python 契约、33³/65³ 批量数值生成和独立逐节点读回通过。
- macOS Release、iOS Simulator Release、iOS generic Release 均 `BUILD SUCCEEDED`。
- 3 个 App 包资源审计通过。
- 完整日志：`/tmp/lutcalc-h13-clro-release-full.log`。
- 日志 SHA-256：`fcb1b304e4c78a42470bdbecf4dfbcfad4a7b2716922610ab216858aa15da0d1`。

发布入口仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出 2；没有创建占位清单。其余 ICC 类型、显示色彩管理、整图显示、HDR/EDR、Files/File Provider、真机 SPI3D 读回/取消和完整发布证据仍未完成，Goal 保持 active。

## 后续同日跨字段契约

新增 `PreviewContractsTests` 一项：`5CLR` 配五色排列合法，RGB 配五色排列及 CMYK 配三色排列必须拒绝。契约先红后绿；接入 header 通道数校验后定向 17 项通过。

再次运行完整 Release 入口：`swift test --list-tests` 为 **172 项**，Swift Release XCTest、旧 Node/Python、33³/65³ 批量数值逐节点检查、macOS/iOS Simulator/iOS generic Release 构建和 3 个 App 包审计通过。日志 `/tmp/lutcalc-h13-clro-channel-release-full.log`，SHA-256 `b94b2bf1dc802cd91fab54b3833fcb5acdcaece2aed90cb7587c251069810834`。发布入口仍仅因缺少真实全量清单退出 2；未做真机验证。

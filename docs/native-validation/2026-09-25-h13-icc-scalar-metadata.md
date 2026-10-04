# H13 ICC 标量 metadata 阶段验收

日期：2026-09-25。Goal 仍 active。本阶段继续只读解析 ICC 固定结构 metadata，不做颜色转换，不保存 LUT、曲线或其他等价采样表，不改变最终 Double 生成和冻结精度门槛。

## 本批次范围

在已有 `text`、`desc`、`mluc`、`XYZ `、`sig `、`curv`、`chrm`、`para`、`view`、`meas` 摘要上，批量接入三个标量型 ICC type：

- `cicp`：固定四个 UInt8 code point，报告到 `integerValues`。
- `dtim`：固定年月日时分秒六个 UInt16，报告到 `integerValues`；年份、月份、实际公历月天数、小时、分钟和秒均校验，包含闰年规则。
- `data`：校验 ASCII/binary flag；ASCII payload 只验证 7-bit、NUL 终止和长度，binary payload 不保存内容，只报告 flag 和 payload 字节数。

所有摘要字段仍属于检查资料，不进入 CPU 取样、色彩矩阵、曲线求值或导出路径。

## 契约先行与修正

新增 `PreviewContractsTests` 的正常摘要和边界拒绝契约，覆盖短 `cicp`、2 月 30 日、非法 `data` flag 与未终止 ASCII。首轮测试夹具还暴露了两类独立问题：

1. `XCTAssertThrowsError` 数组/元组括号不平衡；
2. 新增 `UInt16` 大端 helper 后，旧的整数字面量调用出现重载歧义。

两项均只修正测试夹具，不放宽生产校验。随后补充实际公历月天数检查，确保 `dtim` 不接受 2 月 30 日。

定向 Release 命令：

```text
swift test -c release --package-path Native/Packages/LUTKit \
  --filter LUTPreviewTests.PreviewContractsTests
```

结果：`PreviewContractsTests` 14 项通过，0 失败。

## 真实 ImageIO 夹具

按既有批量夹具流程生成临时 PNG/TIFF/JPEG，先由 `sips` 生成 JPEG，再运行 `LUTImageChecks`。结果退出码 0，既有 PNG 8/16 位、嵌入 ICC 原始字节和 ICC tag 摘要、非嵌入来源、TIFF 16 位、JPEG 8 位、方向 1–8、预乘 alpha、资源预算、全 chunk CRC 与重复 `iCCP` 拒绝均保持通过；无损夹具整数码值归一化误差为 0。

## 集中批量 Release 回归

执行：

```text
bash tools/native-validation/verify-native-release.sh
```

结果：

- `swift test --list-tests`：169 项；Swift Release XCTest 全部通过。
- 旧 Node/Python 契约、33³/65³ 批量数值生成与独立逐节点读回全部通过。
- macOS Release、iOS Simulator Release、iOS generic Release 构建全部 `BUILD SUCCEEDED`。
- 3 个 App 包资源审计通过。
- 完整日志：`/tmp/lutcalc-h13-dtim-release-full.log`。
- 日志 SHA-256：`3a9d366e05ab0f49867aa47d8448bc7f6b99b2d109bac66a505bb7158d8117c0`。

发布入口退出码为 2，唯一直接原因仍是缺少真实 `docs/native-validation/full-scope-acceptance.json`；没有创建占位清单，也没有把本阶段成果称为完整迁移。完整 ICC 类型覆盖、显示/工作空间转换、整图显示、HDR/EDR、Files/File Provider、真机 SPI3D 生成/取回和取消仍未完成，Goal 保持 active。

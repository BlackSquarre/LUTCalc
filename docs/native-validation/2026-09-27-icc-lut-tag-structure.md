# 2026-09-27 ICC LUT 标签结构阶段验收

## 范围

本阶段为 ICC profile validator 增加 `mft1`、`mft2`、`mAB `、`mBA ` 标签的结构元数据解析。实现只记录输入/输出通道、网格点、输入/输出表项数、CLUT 字节数及受限偏移关系，不保存或采样 LUT payload，也不把它接入颜色转换路径。因此这不是完整 ICC 色彩管理或 `mAB/mBA` 转换完成证据。

## 实现与契约

- `ICCProfileTagValidation` 新增可选 `lutMetadata`。
- `mft1`/`mft2` 严格检查通道数、网格点、表项数、整数溢出和 payload 总长度。
- `mAB `/`mBA ` 严格检查通道数及 section offset 的范围、排序和重复关系；当前只产生结构摘要。
- 未引入任何厂商 LUT、采样表或研究资源；Double 生成路径不变。
- 新增 2 项测试：结构摘要不暴露样本、维度和偏移错误拒绝。

## 实际命令与结果

- `swift test --package-path Native/Packages/LUTKit -c release --filter PreviewContractsTests`
  - `PreviewContractsTests` 26 项通过、0 失败。
  - 日志：`/tmp/lutcalc-icc-lut-structure-release-20260927.log`
  - SHA-256：`088f8fba3970805ab0d8413bfcc649490115ec1419f8620a95cf4da020a38034`
- Debug 定向 `PreviewContractsTests.testICCProfileLUT*` 2 项通过。
- `git diff --check` 通过。
- `swift test --package-path Native/Packages/LUTKit -c release`
  - 全包 Release 回归通过。
  - 日志：`/tmp/lutcalc-full-swift-release-after-icc-20260927.log`
  - SHA-256：`8cd04320f1fb12e12cc928e0732a52a0b7efe18ebc58d8985dfb3296ddb30ca3`
- macOS、iOS Simulator、generic iOS Release 构建均退出码 `0`；派生数据目录分别为 `/tmp/LUTCalcMacICC-20260927`、`/tmp/LUTCalcSimICC-20260927`、`/tmp/LUTCalcIOSICC-20260927`。

## 未覆盖

仍未实现或验证 `mft/mAB/mBA` 的实际颜色转换、矩阵/曲线/CLUT 组合、渲染意图、LUT profile linking、Core Image/系统色彩管理、HDR/EDR 与真实显示设备。H13、UI-03、UI-06 和完整发布清单仍未完成。

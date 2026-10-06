# Sony S-Log 与 S-Log2 计划色域身份验收

## 范围

`analytic-slog-v1` 与 `analytic-slog2-v1` 原先记录 transfer 对，却没有记录输入/输出 `ColorSpaceID`。published 与 LUTCalc legacy 两个分支都可能在不同 Sony/目标色域矩阵下共享计划身份。本项只补充身份字段，不修改 Sony 公开公式、legacy fixture、缩放边界或 Double 生成路径。

## 契约与实现

- 在 `SonyLegacyLogContractsTests` 新增同一 transfer 下仅改变输入色域、仅改变输出色域的契约，覆盖 S-Log、S-Log2 及两个 legacy ID，共 16 条修复前失败断言。
- 两个 Sony 分支族现记录 input/output transfer 与 `inSpace`/`outSpace`。

## 验证

- 定向 Release：`swift test --package-path Native/Packages/LUTKit -c release --filter SonyLegacyLogContractsTests`，5 项通过，0 失败。
- 同一套测试继续通过 published S-Log/S-Log2 标量参照、legacy 64 位冻结 fixture、目录和 camera route 契约。
- 全量 Release：`swift test --package-path Native/Packages/LUTKit -c release --quiet`，退出码 `0`，SwiftPM 输出 `All tests passed`。工具链 Apple Swift 6.4、`swift-driver` 1.168.6、arm64 macOS 27.0.0。
- `git diff --check` 待文档落盘后执行；SwiftPM 未导出 `.xcresult`。

## 未覆盖范围

本项只关闭 Sony S-Log/S-Log2 计划的双端色域身份别名，不代表完整 Sony 机型/色域工作流、`.labin`/直接查表、tricubic、完整 ICC/HDR、平台或发布验收完成。Goal 保持 `active`。

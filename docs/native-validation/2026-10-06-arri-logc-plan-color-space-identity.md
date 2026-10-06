# ARRI LogC scene 计划色域身份验收

## 范围

`published-logc-scene-plan-v1` 原先只记录 LogC EI payload，未记录输入/输出 `ColorSpaceID`。不同色域矩阵路由可能复用同一计划身份。本项只补充计划身份字段，不改变 LogC scene 公式、EI 语义、Double 路径或范围策略。

## 契约与实现

- 在 `ARRILogCSceneRoutingContractsTests` 新增同一 SUP3/EI800 payload 下的输入色域、输出色域差异契约，并检查身份含双端色域。
- 修复前定向 Release 新契约执行 1 项，4 条断言失败。
- 现有版本前缀和 `input-logc`/`output-logc` EI 字段保留，追加 input/output transfer 与 `inSpace`/`outSpace`。

## 验证

- 修复后定向 Release：`swift test --package-path Native/Packages/LUTKit -c release --filter ARRILogCSceneRoutingContractsTests`，4 项通过，0 失败。
- 同一套测试包含 113080 个独立 Decimal/二进制参照样本，最大相对误差 `1.29121509482886e-14`，RMS `2.5131245865722955e-16`，P99 `8.223777217213309e-16`。
- 全量 Release：`swift test --package-path Native/Packages/LUTKit -c release --quiet`，退出码 `0`，SwiftPM 输出 `All tests passed`。工具链 Apple Swift 6.4、`swift-driver` 1.168.6、arm64 macOS 27.0.0。
- `git diff --check` 待文档落盘后执行；SwiftPM 未导出 `.xcresult`。

## 未覆盖范围

本项只关闭 ARRI LogC scene 计划身份的色域别名，不代表 ARRI 全部 LogC 机型/色域、完整 HDR、LUTAnalyst、`.labin`、直接查表、平台或发布验收完成。Goal 保持 `active`。

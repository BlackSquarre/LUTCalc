# linear scene 计划色域身份验收

## 范围

`minimal-linear-scene-v1` 原先在输入和输出均为 `linear.scene.v1` 时使用固定字符串；即使输入/输出色域不同并触发矩阵转换，计划身份仍不变化。本项只补充计划身份字段，不改变线性路径、色域矩阵、Double 计算或输出规则。

## 契约与实现

- 在 `TransformAlgorithmWiringContractsTests` 新增同 transfer 下仅改变输入色域、仅改变输出色域的契约，并检查双端色域字段。
- 修复前新增契约执行 1 项，4 条断言失败，确认 linear-scene 跨色域计划别名。
- `linearScene` 分支现记录 input/output `TransferID` 和 `inSpace`/`outSpace`；同步 Null transfer、设备性能探针与既有请求 fingerprint 的固定身份断言。

## 验证

- 相关组合 Release：`swift test --package-path Native/Packages/LUTKit -c release --filter 'TransformAlgorithmWiringContractsTests|NullTransferContractsTests|DevicePerformanceProbeContractsTests'`，退出码 `0`。
- 3DL 批次固定 fingerprint 因计划身份字段变化而更新为真实请求 SHA-256：`063239c1008d6e1b01e5ba88677bcded9d767b41611381a47376fe81d557254b`；三种 flavor、17/33/65 网格和恢复契约均通过。
- 整包 Release：`swift test --package-path Native/Packages/LUTKit -c release --quiet`，退出码 `0`，SwiftPM 输出 `All tests passed`。工具链 Apple Swift 6.4、`swift-driver` 1.168.6、arm64 macOS 27.0.0。
- `git diff --check` 待文档落盘后执行；SwiftPM 未导出 `.xcresult`。

## 未覆盖范围

本项只关闭 linear-scene 计划的双端色域身份别名，不代表完整 `TransformSettings` 缓存指纹、所有计划分支、`.labin`/直接查表、tricubic 全根、ICC/HDR、平台或发布验收完成。Goal 保持 `active`。

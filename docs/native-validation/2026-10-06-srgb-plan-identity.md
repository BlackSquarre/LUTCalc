# sRGB 计划身份验收

## 发现与修复

`TransformPlan.basePlanVersion` 原先将 published `srgbW3CExtended` 与 `srgbLUTCalcLegacy` 共用 `minimal-srgb-v1`，且没有表达输入／输出方向。实际执行中两者使用不同公式：输入端由各自 transfer 分支解码，输出端由 `NativeOutputEncoder` 按输出 transfer 编码。因此同侧公式版本、published encode/decode 和 legacy encode/decode 都可能出现版本字符串冲突。

修复仅让 sRGB 分支调用既有 `directional` 身份构造，变化时记录 `inputTransferID` 和 `outputTransferID`；同 transfer 的历史短身份保持不变。没有修改公式、输出、色域矩阵、位深或生成数值路径。

## 契约与验证

- 新增 `SRGBPlanIdentityContractsTests` 三项：published 与 legacy 输入 transfer 分离；published 的输入／输出方向分离；legacy 的输入／输出方向分离。
- 修复前红测：`swift test --package-path Native/Packages/LUTKit -c release --filter SRGBPlanIdentityContractsTests`，3 项测试失败，9 条断言失败，确认原冲突。
- 修复后：相同 Release 命令，3 项通过，0 失败。
- 工具链：Apple Swift 6.4，`swift-driver` 1.168.6，arm64 macOS 27.0.0。
- `git diff --check`：通过。

## 范围

该工作包只处理 sRGB 算法版本身份，不表示完整 LUT 缓存键或请求内容指纹。曝光批次身份仍另外包含完整 `TransformSettings`。其他 transfer 家族的方向和色域身份未在本次修改。

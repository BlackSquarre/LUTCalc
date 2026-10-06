# SMPTE 240M 与 BT.1886 计划身份验收

## 范围

本项只审计 `TransformPlan.basePlanVersion` 的 SMPTE 240M 与 BT.1886 固定身份分支。此前两个分支都只返回常量版本字符串，因此输入/输出方向不同或输入、输出 `ColorSpaceID` 不同时仍可能共享同一 `planVersion`。这会令代表不同传递函数方向或色域矩阵路由的计划拥有相同缓存/批次身份。

## 改动

- SMPTE 240M 与 BT.1886 身份现在都包含 input/output `TransferID`、input/output `ColorSpaceID`。
- 新增 `SMPTE240MBT1886PlanIdentityContractsTests`，每个分支覆盖反向传递方向、仅改变输入色域和仅改变输出色域。测试使用目录中有效的 transfer/color-space ID、`.data` 信号范围、10-bit 范围参数和 0-stop exposure。
- 不改传递函数公式、色彩矩阵、`Double` 计算路径、网格、位宽、插值规则或数值阈值。

## 验证状态

- 修改前失败契约：尚未运行 SwiftPM；根据旧实现两个固定身份字符串，新增的方向及色域差异断言预期失败。
- 统一定向 Release 命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter 'PlanIdentityContractsTests|SMPTE240MBT1886PlanIdentityContractsTests'
```

- 工具链 Apple Swift 6.4，arm64-apple-macosx27.0.0；身份测试共执行 13 项、0 失败。全量 `swift test --package-path Native/Packages/LUTKit -c release --quiet` 最终退出码 `0`，SwiftPM 输出 `All tests passed`。
- SwiftPM 未导出 `.xcresult` 结果包；本验收文档保存命令、工具链、退出码和结果摘要。本契约检查身份差异，不测量公式误差；独立传递函数数值参照仍由现有公式契约承担。
- 未覆盖：全局 `TransformPlan` 参数身份审计、SMPTE 240M／BT.1886 全部信号语义、完整 ICC/HDR、其他算法缺口及平台发布验收。

本项是两个身份分支的局部修复，不代表算法或全 Swift 迁移完成；Goal 继续保持 `active`。

# CIE L* 与 ProPhoto 计划身份验收

## 范围

审计发现 `TransformPlan.basePlanVersion` 中 CIE L* 与 ProPhoto transfer 分支原先分别返回固定字符串。相同固定字符串会掩盖输入/输出方向以及两端 `ColorSpaceID` 的差异，可能令项目缓存和批次身份发生别名。

本工作包只修改计划身份字符串，不改变 CIE L*、ProPhoto 数值公式、计算顺序、位宽、网格或容差。

## 契约与实现

- 新增 `PerceptualTransferPlanIdentityContractsTests`，分别检查两个分支的正反方向身份、输入色域变化、输出色域变化，并确认身份包含两端 transfer 和色域 ID。
- 测试使用现有 `TransferID.cieLStar`、`TransferID.proPhoto`、`TransferID.linearScene` 与 `ColorSpaceID.rec2020`、`ColorSpaceID.displayP3`、`ColorSpaceID.proPhoto`；`exposureStops` 固定为 `0`。
- 两个身份现采用 `minimal-<family>-v1:<inputTransferID>:<outputTransferID>:inSpace:<inputColorSpaceID>:outSpace:<outputColorSpaceID>`。

## 验证状态

- 契约已先于实现加入，但本轮未执行修复前测试，因此没有可报告的红测结果。
- 统一定向命令：`swift test --package-path Native/Packages/LUTKit -c release --filter 'PlanIdentityContractsTests|SMPTE240MBT1886PlanIdentityContractsTests'`；Apple Swift 6.4，arm64-apple-macosx27.0.0。实际执行 13 项身份测试，0 失败。
- 全量回归命令：`swift test --package-path Native/Packages/LUTKit -c release --quiet`；最终退出码 `0`，SwiftPM 输出 `All tests passed`。运行期间先发现目录测试残留的 CIE L* 旧版本字符串断言；更新为检查 transfer 与双端色域字段后，定向检查和整包回归通过。
- SwiftPM 未导出 `.xcresult` 结果包；本验收文档保存了命令、工具链、退出码和观察结果。身份测试不测公式误差；数值路径未改，算法数值准确度未在本工作包重测。

## 未覆盖范围

本项只关闭 CIE L* 与 ProPhoto 的计划身份碰撞子集，不代表其他 transfer 身份族全量审计、ICC、`.labin`、直接查表替代、LUTAnalyst 全根完备性或全 Swift 迁移验收完成。Goal 继续保持 `active`。

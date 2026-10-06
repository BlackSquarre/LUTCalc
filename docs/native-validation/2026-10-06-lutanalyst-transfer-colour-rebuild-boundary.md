# LUTAnalyst transfer／colour 分离与重建边界验收

## 范围

本轮只审计 `ImportedLUTAnalyzer` 的 transfer／colour 分节、显式重建和生成接线。目标是确认是否存在可由公开输入契约安全闭合的子集，不从任意用户 LUT 猜测厂商模型、方向或全局可逆性。

## 当前已闭合的安全子集

- `LUTAnalysisFile` 保持 1D transfer 与可选 3D colour 分节独立；分节元数据分别校验，来源量化语义进入分析结果和反求计划身份。
- 严格单值 1D transfer 可构造 `ImportedLUTInversePlan`。构造时完整检查三通道 cubic 曲线的全域单值性；平段、折返、多根和非法元数据拒绝。计划使用 `Double`，并把实际样本、域、插值和来源语义纳入 `contentFingerprint`。
- 该计划已接入 `LUTGenerationRequest`，在 transform plan 前执行输入 transfer 反求；项目重开、单项生成、曝光批量和 durable checkpoint 均复用同一计划身份。输入 shaper 与 transfer 反求同时存在时显式拒绝，避免重复应用。
- `reconstructionReport(...)` 只接受调用方提供的输入／输出参考对，按显式 transfer → colour 顺序采样，分别使用调用方指定的插值并报告逐样本残差、最大值、RMS 和 P99。它是参考对诊断，不是模型拟合或逆变换证明。
- colour 3D 逆仅接受调用方提供的 `KnownAffine3DTransform`。没有模型时明确返回 `arbitrary3DInverseUnsupported`；模型的条件数、域和前向回放残差由 `KnownAffine3DTransform` 校验。
- tri／tetra／tricubic 和组合 shaper 入口只输出保守诊断。候选单元、奇异单元、Newton 未收敛或 shaper 多根保持 `unresolved`／`multiple`，不会被当作全局唯一或无解。

## 为什么自动分离和完整重建仍不能闭合

1. 一个 3D colour LUT 的节点值不能唯一决定 transfer、输入／输出色域、矩阵、方向或量化来源；不同连续模型可以在同一有限网格上完全一致。
2. 一个 tricubic 候选单元即使找到一个 Newton 根，也不能证明 cell 内没有其他根；需要区间根隔离、奇异集合处理和共享面全根去重。当前实现已记录候选单元计数，但没有把候选误报为全局完备。
3. `reconstructionReport` 的参考对只验证调用方指定的组合。没有独立、足够覆盖的连续参考，不能反向推出厂商模型或生成计划。
4. `.labin` 的量化、方向和旧设备语义，以及 45 个直接查表注册，仍缺少公开连续公式和独立非灰轴参照；不能以重建残差或视觉相似度替代。

## 契约与实际结果

工具链：Swift `6.2.1`，Apple SwiftPM，Release，当前工作区 `/Users/lingru/claude/LUTCalc`。

实际命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter 'ImportedLUTAnalysisContractsTests|CombinedShaperColourInverseContractsTests|TricubicInverseContractsTests|LegacyCubicInverseGenerationContractsTests|UserLUTInverseExportContractsTests|ExposureBatchInverseIdentityContractsTests'
```

结果：退出码 `0`；`LUTAnalysisTests` 38 项通过，`LUTJobsTests` 9 项通过，失败 0。覆盖显式分节与元数据、任意 3D 拒绝、仿射逆、参考对重建统计、cubic 全根诊断、tricubic 候选／共享面／奇异边界、生成接线、1D 导出拒绝、批量身份和取消／上限语义。全程保持生产 `Double`、原插值和阈值。

## 未覆盖与路线状态

本记录不勾选 H07、H10、H14 或 FULL-05。自动 transfer／colour 分离、任意 3D 全局全根证明、完整方向／量化生成接入、目标软件往返、`.labin` 替代和直接查表替代仍未完成。不得据此创建或填充 `full-scope-acceptance.json`，Goal 继续保持 `active`。

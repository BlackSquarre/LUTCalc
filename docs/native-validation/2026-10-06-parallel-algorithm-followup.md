# 2026-10-06 并行算法工作包与 ACES 方向契约

## 并行工作包

- TransformPlan 身份复核发现 F-Log2 C 的 F-Gamut C 输入/输出方向可能共用身份；计划身份现包含输入和输出 `ColorSpaceID`。Release `FLog2ContractsTests` 9 项通过，记录见[F-Log2 C 计划色域方向身份验收](2026-10-06-flog2c-plan-identity.md)。
- research G03 Leica L-Log 与 G04 KineLOG3 公式、注册、计划输入解码和输出编码已存在。本包复核 Release `LLogContractsTests` 3 项和 `KineLog3ContractsTests` 3 项通过；无需新增实现。公式来源、既有独立误差和边界见[research G03/G04 公式闭合核验](2026-10-06-research-g03-g04-formula-closure.md)。
- 后续计划身份审计发现 W3C sRGB 与 LUTCalc legacy sRGB，以及各自的输入／输出方向会共享算法版本身份。先行红测 3 项、9 条断言复现混淆；修复后 Release `SRGBPlanIdentityContractsTests` 3 项通过。详见[sRGB 计划身份验收](2026-10-06-srgb-plan-identity.md)。
- 随后的共享身份审计发现 Rec.709 legacy、Rec.2020 10-bit、Rec.2100 PQ、F-Log2 和 I-Log/V-Log 同样需要明确输入/输出方向与两端色域。Rec/PQ 定向 3 项、F-Log2 定向 11 项、I-Log/V-Log 定向 7 项通过；统一组合契约 30 项通过，整包 Release 回归退出码 `0`。具体修改范围和各自未覆盖项见[Rec/PQ 身份验收](2026-10-06-plan-identity-rec709-rec2020-pq.md)、[F-Log2 身份验收](2026-10-06-flog2-plan-identity.md)及[I-Log/V-Log 身份验收](2026-10-06-ilog-vlog-plan-identity.md)。

## ACES 方向身份契约同步

- 全量 Release 首次运行发现旧 ACES CC、ACES CCT、ACES Proxy 计划字符串断言仍期待常量身份；实际算法身份已纳入输入和输出 `TransferID`。测试预期按现有契约更新，并补充 ACES CC 正反方向计划身份不别名契约。
- 修复前 `LUTCoreTests` 因 4 个过期断言失败；没有发现公式或数值路径失败。定向 Release `ACESCCContractsTests|ACESCCTContractsTests|ACESProxyContractsTests|TransformAlgorithmWiringContractsTests` 执行 18 项、0 失败。
- 全量命令 `swift test --package-path Native/Packages/LUTKit -c release` 在 ACES 契约同步后及 sRGB 生产身份修复后各运行一次，均退出码 `0`。工具链为 Apple Swift 6.4、arm64 macOS 27.0.0。两次全量回归之前的 `git diff --check` 均通过；最后一次 sRGB 工作包也单独通过同一检查。
- 本轮只同步身份契约测试，不改变算法、Double 计算、网格或量化。没有取得全量 `TransformPlan` 参数/色域身份审计结论，也未关闭完整 ICC、HDR/OOTF、任意三维全根反求、自动 transfer/colour 分离、`.labin`、直接查表或发布范围。

## 2026-10-06 身份并行包与算法边界复核

- SMPTE 240M、BT.1886、CIE L*、ProPhoto 身份分支加入方向和输入/输出色域契约；统一身份定向 Release 13 项通过，整包 `swift test --package-path Native/Packages/LUTKit -c release --quiet` 最终退出码 `0`，工具链 Apple Swift 6.4、arm64 macOS 27.0.0。目录测试中一个旧 CIE L* 身份串断言先失败，按新身份契约更新后通过。逐包结果见对应验收文档。
- ICC 并行审计未找到可安全新增且不重复的行为：BPC 多解和通用 gamut mapping 仍缺真实可复现 profile、指定版本独立 CMM 与逐码参照。
- tricubic 并行审计确认有限 Newton seeds 只构成可回放候选，不能证明全根；候选 unresolved 状态是当前正确的保守结果。闭合需要区间根隔离或独立连续参照；本次未改码。

## 仍未完成

`.labin` 替代仍为 `0/9`，直接查表替代仍为 `0/45`；tricubic 区间根隔离、完整 ICC 的 BPC/gamut mapping 与真实第三方逐码参照、PQ OOTF/HDR/EDR 单位及参考白裁决仍未闭合。此记录不表示 Goal 完成；Goal 保持 `active`。

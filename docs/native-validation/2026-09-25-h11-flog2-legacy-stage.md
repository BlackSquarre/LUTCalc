# H11 旧版 F-Log2 兼容候选阶段验收

日期：2026-09-25

## 范围与来源

旧版 `js/gamma.js` 的 F-Log2 注册参数作为独立兼容曲线接入，不覆盖 Fujifilm F-Log2 官方公式。来源为 `js/gamma.js` 的 `LUTGammaLog` 注册与实现（旧文件 SHA-256：`250017d8efe758f3555148ba9fcb923698add0ac7d9380fa290716eb98e0821e`；参数和行号记录见[F-Log2 研究记录](2026-09-25-fuji-flog2-reference-research.md)）。

旧版九参数、`0.000987778`/`0.100686685` 分支和 `scene = 0.9 × legacy` 标度保持独立 `TransferID.fujifilmFLog2LUTCalcLegacy`；计划版本为 `minimal-flog2-legacy-v1`，色域复用 F-Gamut。未加入厂商 LUT、`.labin` 或采样表。

## 先失败后通过的契约

- 新增旧版低段/高段、两个切点相邻值和非有限输入契约；首次运行因缺少独立 API/ID 编译失败，日志 `/tmp/lutcalc-flog2-legacy-red-20260925.log`。
- 实现后 `FLog2ContractsTests` 定向 6 项通过，官方 F-Log2 原有 3 项行为保持通过。
- 注册表独立身份契约通过：旧版别名 `F-Log2 (LUTCalc legacy)`、`.legacyGrey02` 线性参考、独立预设和 F-Gamut 引用均成立。

## 批量数值验证

一次 Release 产品目录复用 33³/65³ 生成并独立逐节点读回，日志 `/tmp/lutcalc-flog2-legacy-subset-20260925.log`；SHA-256：`d1fcfe1e090159a25f569485d5326729deef0369368711333f7225fe3d8b56fa`。

- 33³ 与 65³ 均为 35,937/274,625 个 Double 节点。
- 两个尺寸的最大尺度化误差均低于冻结门槛 `2e-12`；批量入口退出码 0。
- CLI 新增 `flog2-legacy-exposure`，与官方 `flog2-exposure` 分开。

本阶段只证明旧版兼容公式、独立身份和同色域曝光候选；相机范围、跨色域、真机运行、第三方导入、完整 H01–H14 和发布验收仍未完成。

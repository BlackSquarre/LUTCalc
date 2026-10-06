# 旧算法缺口扫描验收

## 扫描范围

本轮检查 `Native/Packages/LUTKit/Sources/LUTCore`、`LUTAnalysis` 以及现有算法台账，逐项核对旧调节链和 cubic/tricubic 诊断是否存在可由公开公式闭合的遗漏。检查范围包括 ASCCDL、Knee、BlackGamma、BlackHighlight、DisplayConversion、GamutLimiter、HighlightGamut、FalseColour、Multitone、SDRSaturation、FinalOutput、LegacyCubicCurve1D、LegacyTricubicVolume3D 与 ImportedLUTAnalysis。

## 结果

- 上述旧调节链均已有对应 Swift 实现和契约测试；LegacyCubicCurve1D 已覆盖完整域 Hermite 采样及域外策略，ImportedLUTAnalysis 已覆盖一维全根、平台区间和域外诊断，LegacyTricubicVolume3D 保留 ghost-node 与域外契约。
- LegacyKnee 第二段导数根检查在旧 `js/gamma.js` 中明确注释停用，Swift 保持旧语义；没有独立公开定义支持擅自改变。
- 尚未闭合的白平衡 501 点 Planck/Duv/Dpl 轨迹和 PSST 四组固定 Ring 映射依赖旧采样数组；当前没有公开连续生成定义、独立逐点参照和完整参数语义，因此禁止复制、拟合或转为 Swift 常量。
- `.labin` 仍为 `0/9`，直接查表仍为 `0/45`；本扫描没有发现安全新增算法子集，也未修改生产代码。

## 未覆盖与结论

本扫描不替代平台、真机、目标软件、完整 ICC/HDR、任意三维全局反求或发布验收。白平衡/PSST、`.labin`、直接查表和完整旧功能继续保持研究阻塞，Goal 保持 `active`。

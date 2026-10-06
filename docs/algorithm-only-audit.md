# 内置 LUT 依赖审计与纯算法约束

## 2026-10-05 LUTAnalyst 旧 tricubic 局部反求诊断

旧 `LegacyTricubicVolume3D` 现提供与生产 sampler 相同 ghost-node、cell 选择和 Catmull-Rom 权重下的解析 Jacobian；单元输出范围先转为 tensor-product Bernstein 系数后取包围盒，因此包含 cubic overshoot。`Tricubic3DInverse` 只在包围盒命中时运行有限 Newton 候选，候选必须经生产 sampler 回放并满足 `2e-12` 阈值；奇异或未能证明的单元报告 `unresolved`，不会猜测为无解。

Debug／Release 定向 7 项、Swift Release 全量回归和 `Scripts/verify-native-numerics.sh` 均退出 0。结果包与未覆盖范围见[旧 tricubic 局部反求验收](native-validation/2026-10-05-lutanalyst-tricubic-inverse.md)。该项只是局部诊断子集，不关闭任意三维 LUT 全局反求、全根完备性、多解证明、组合 shaper、自动 transfer/colour 分离、`.labin` 或直接查表替代。

## 2026-10-05 ICC device-link A2B0

新增用户导入 `link` profile 的单个 `A2B0` 数学执行子集：header rendering intent、`mft1/mft2/mAB` 分派、profile class／维度／方向拒绝和连续 3×3 矩阵后接 3 个 offset 的 ICC 解码均有契约。真实 Little CMS 2.19 `cmsPipelineEvalFloat` 参照与 Swift Double 结果一致，详见[ICC device-link A2B0 验收](native-validation/2026-10-05-icc-device-link.md)。这不关闭完整 ICC、其他 profile class／MPE／intent、ColorSync、HDR/EDR 或 Goal。

## 2026-10-05 BT.2100 HLG reference OOTF extended gamma 数学子集

`BT2100HLGReferenceOOTF` 新增显式 `GammaMode.extended`，按 BT.2100-3 Note 5f 使用 `gamma = 1.2 * 1.111 ^ log2(L_W / 1000)`；默认构造仍只接受通常制作范围 `400...2000 cd/m²`。扩展模式的 90 位 `Decimal` 独立参照最大尺度化误差为 `4.974256639474225e-16`，并以同一模式交叉验证 reference EOTF 的黑位抬升、负 PLUGE 头房、标量逆和 RGB 亮度耦合，最大尺度化误差为 `7.771561172376096e-16`。Debug/Release 定向和快速/原生数值门禁均通过。

该项只关闭 extended system gamma 的可追溯公式和显式选择边界，不接入自动峰值、项目默认策略或 UI；项目字段接线另见 schema 27 的独立验收。四种完整 HDR 变体、PQ OOTF、完整 HDR/EDR、`9/9` `.labin`、`45/45` 直接查表注册、完整 ICC、LUTAnalyst 任意三维反求和 Goal 仍未完成。详见[扩展 gamma 验收](native-validation/2026-10-05-hlg-reference-ootf-extended.md)。

## 2026-10-05 BT.2100 HLG reference OOTF extended gamma 项目持久化子集

`HLGOOTFSettings.referenceGammaMode` 已接入项目 schema `27`。只有 `bt2100.hlg-reference-ootf.v1` 可以保存 `extended`；schema 26 及更早版本携带该字段、legacy HLG 携带该字段或 reference 参数违反 nits／相同峰值／零黑位／关闭 BBC 边界时均拒绝。定向 Debug／Release 各 9 项、完整 Swift Release 896 项和 `Scripts/verify-native-numerics.sh` 均通过，结果包见[HLG extended gamma 项目持久化验收](native-validation/2026-10-05-hlg-reference-ootf-extended-project.md)。

该项只关闭已实现 reference OOTF extended gamma 的项目清单接线，不关闭完整 HDR/OOTF、自动峰值、参考白／黑位策略、四种 HDR 变体、PQ OOTF、UI、真实显示、完整 ICC、LUTAnalyst、`9/9` `.labin`、`45/45` 直接查表注册或 Goal。

## 2026-10-05 ICC 传统任意通道 profile linking

`ICCMFTTransform`、`ICCMABTransform` 及其 XYZ/Lab 适配器现支持用户主动导入的 1...15 通道传统 `mft2`、`mAB`、`mBA` 数组路径；`ICCRGBProfileLink` 对非 RGB 设备接入显式 relative colorimetric linking。固定 3×3／3×4 矩阵边界、CLUT 轴序、方向和 RGB 便利入口均有契约。`mft1`+`XYZ ` 因 ICC 没有定义 8 位 PCSXYZ 编码而明确拒绝。定向 Debug 62 项和独立 `Decimal(90)` 参照通过，详情见[ICC 传统任意通道验收](native-validation/2026-10-05-icc-traditional-arbitrary.md)。

该项只关闭传统 LUT 任意设备通道 relative linking 数学子集，不代表完整 ICC、真实第三方 profile 逐码参照、其他 rendering intent／profile class、black point compensation、gamut mapping、ColorSync、其他 ICC 类型、HDR/EDR、`.labin`、直接查表注册或 Goal 完成。

## 2026-10-05 ICC 任意通道 profile linking

`ICCRGBProfileLink` 现将已有 `ICCMPETransform` 的通用设备数组能力接入成对 `D2B`/`B2D` MPE profile linking。source/target 设备端各自允许 profile 声明的 1...15 通道，PCS 保持同为 `XYZ ` 或 `Lab ` 三通道；generic `[Double]` 入口不会把传统 RGB-only route 隐式解释成任意设备格式。30 项 Debug／Release 定向契约和 Swift Release 全量回归通过，独立 `Decimal(90)` 参照见[ICC 任意通道 profile linking 验收](native-validation/2026-10-05-icc-profile-linking-arbitrary.md)。

该项只关闭 `mpet` 成对路由，不关闭真实 profile 逐码参照、黑点补偿、gamut mapping、ColorSync、HDR/EDR；ICC.1:2022-05 当前定义的 `cvst`、`matf`、`clut`、`bACS`、`eACS` 元素已覆盖，未知未来元素仍拒绝。`parf` 只接受 type 0、1、2，传统 `para` type 3、4 不属于 MPE。`.labin` `0/9`、直接查表注册 `0/45`、LUTAnalyst 任意 3D 反求和 Goal 仍保持未完成。

## 2026-10-05 BT.2100 HLG reference OOTF 数学子集

新增 `BT2100HLGReferenceOOTF`，按 BT.2100-3 (02/2025) Table 5 与 Note 5f 保存参考 HLG OOTF 的可追溯 `Double` 公式，支持 `400...2000 cd/m²` 峰值的标量与 RGB 正逆变换，并接入 `TransformPlan` 的显式 reference 路由。独立 90 位 Decimal 参照、stage 130/stage 13 单位契约、schema 22 严格往返和定向／完整 Swift Release 契约通过。

该路由明确与历史 `HLGOOTF` 分离：历史类型保留 LUTCalc 的场景范围、黑位、BBC 和裁切语义；reference 路由只接受 nits、相同输入／输出峰值、零黑位和关闭 BBC。schema 22 保留基础 reference 算法身份和参数，扩展 gamma 的项目字段在后续 schema 27 独立验收中接线，尚未接入默认路由或 UI。自动峰值、参考白／黑位策略、四种 HDR 变体、PQ OOTF、完整 HDR/EDR 和真实显示参照仍未闭合。详见[BT.2100 HLG reference OOTF 验收](native-validation/2026-10-05-hlg-reference-ootf.md)。

同日补齐该 reference 路由的 BT.2100-3 Table 5 黑位抬升 EOTF 数学子集：`beta`、负 `E'` 头房、RGB 亮度耦合和零显示非唯一逆均有独立 90 位 Decimal 参照与快速/数值门禁。黑位仍是显式调用参数，未接入默认项目策略；完整 HDR 变体和设备参照不因本项关闭。

## 2026-10-05 ACES 1.3 Reference Gamut Compression 数学子集

新增 `ACESReferenceGamutCompression` 纯 Swift `Double` 内核，按仓库保存的 ACES 1.3 RGC 规范逐步实现 `TRA1`、`TRA2`、`A`、`d_n` 和 `l/t/p` 压缩公式及闭式逆向 decompression。5,069 个 90 位 Decimal 独立正向/逆向样本、各 15,207 个通道的正向最大尺度化误差为 `4.4408920981579213e-16`，逆向最大尺度化误差为 `1.0058398558498993e-11`；定向 Debug／Release 各 7 项、Swift Release 全量 `847/847` 和 Node 22.21.0 下 66 项原生数值总门禁通过。实现不读取或打包 LUT、`.labin` 或采样数组。

该记录只关闭 RGC 静态数学子集以及显式线性 AP0 的 `TransformPlan`／schema 26 接线子集，不等于完整 ACES 工作流、旧调节链或项目功能完成。RGC 不提供默认相机路由、自动旧调节链组合或 UI；9 个 `.labin` 与 45 个直接查表注册仍保持 `0/9`、`0/45`，完整 ICC、HDR/EDR/OOTF、白平衡/PSST、任意三维反求、相机模型和 Goal 仍未完成。详情见[ACES RGC 数学子集验收](native-validation/2026-10-05-aces-rgc.md)与[计划和项目接线验收](native-validation/2026-10-05-aces-rgc-plan.md)。

## 2026-10-05 ICC 传统 Lab PCS absolute colorimetric 子集

传统 RGB/Lab profile 的 `mft1`/`mft2`/`mAB`/`mBA` relative 标签现在可在没有 `D2B3`/`B2D3` MPE 对时参与 absolute colorimetric linking。实现按 ICC.1:2022-05 §6.3.2.2 的 media-relative PCS XYZ 比例和 §6.3.2.3 的 Lab 编解码运行时推导，不保存 profile、厂商 LUT、旧 `.labin` 或等价采样表。两侧 `wtpt` 缺失或非法时拒绝，避免猜测媒体白点。

传统 `mft2` 与 `mAB/mBA` synthetic 路由、不同媒体白点和缺失 `wtpt` 契约通过；独立 90 位 Decimal 结果见[ICC 传统 Lab PCS absolute 验收](native-validation/2026-10-05-icc-absolute-lab.md)。该项只关闭三通道 Lab PCS absolute 数学子集，不代表完整 ICC；任意通道、所有传统标签变体、真实 profile 逐码参照、黑点补偿、gamut mapping、ColorSync、HDR/EDR 和第三方往返仍未闭合。

## 2026-10-05 ICC `D2B`/`B2D` float32 PCSLAB MPE 子集

现有 `ICCMPETransform` 与 `ICCRGBProfileLink` 已按 ICC.1:2022-05 的 float32 PCS 编码支持 RGB/`Lab ` profile 成对的 `D2B0`/`B2D0`、`D2B1`/`B2D1`、`D2B2`/`B2D2` 和 `D2B3`/`B2D3` 三通道 `mpet`。`Lab ` 浮点值直接表示 `L*`、`a*`、`b*`，不误用 unsigned normalized LUT 编码，也不在 PCS 端做裁切；内部仅转换项目的归一化 `L*` 表示。实现只保留用户 profile 解码后的 `Double` 参数，不打包 profile、厂商 LUT、旧 `.labin` 或等价采样数据。

定向 Debug／Release 各 40 项通过；独立 90 位 Decimal 参照和未覆盖范围见[ICC MPE PCSLAB 验收](native-validation/2026-10-05-icc-mpet-lab.md)。该项只关闭 RGB/`Lab ` 三通道 MPE 子集，不代表完整 ICC：任意通道、其他 MPE 元素、传统 Lab absolute 的全部合法变体、真实 profile 逐码参照、黑点补偿、gamut mapping、ColorSync、HDR/EDR 和完整 Goal 仍未完成。

## 2026-10-05 公开 CAT 白点适应矩阵子集

`ChromaticAdaptation` 现补齐旧实现已经声明的 CIE CAT97s、Von Kries、Sharp、CMCCAT2000、Bianco-S、Bianco-S-PC 和 XYZ Scaling 七个锥响应模型；CIE CAT02 与 Bradford 的现有矩阵保持不变。实现只保存公开 3×3 常数，并按源／目标白点锥响应比例运行时推导适应矩阵，不读取旧 JavaScript、`.labin`、厂商 LUT 或等价采样数据。

契约先行在旧枚举上因缺少成员编译失败；实现后 Debug／Release 定向各 2 项通过。独立 90 位 Decimal 参照覆盖 9 个模型的 D65→D50 矩阵和非中性样本，结果与哈希见[公开 CAT 白点适应验收](native-validation/2026-10-05-chromatic-adaptation.md)。该项只关闭 CAT 矩阵数学分派，不把 CAT 基础能力冒充完整白平衡：501 点 Planck 轨迹、Duv/Dpl、PSST、自定义色域和完整调节链仍未闭合。

## 2026-10-05 CIELAB CIE 1976 Delta E

现有 `CIELABColor` 新增公开 CIE 1976 `Delta E*ab` 欧氏距离，按项目的归一化 L* 约定在计算时转换到标准 0...100。独立 80 位 Decimal 参照和 Debug/Release 契约通过；该方法只接受调用方已经统一白点和观察条件的 Lab 值，不执行隐式适应或色域处理。它不减少 `.labin`／直接查表台账，也不等于完整 CIELAB、CAM、ICC 或 HDR。详见[CIELAB Delta E 验收](native-validation/2026-10-05-cielab-deltae76.md)。

## 2026-10-05 旧 PQ OOTF 兼容内核

旧 `LUTGammaOOTFPQ` 的分段计算已在 `LegacyPQOOTF` 中以纯 Swift `Double` 独立复现，并由 80 位 Decimal 输出和定向 Debug/Release 契约固定。由于输入单位、`Lw` 和 `scale` 的标准语义仍未决，该内核不注册为标准 `PQTransfer`，也不接入 `TransformPlan`；它只保存历史兼容身份，不减少 `9/9` `.labin` 与 `45/45` 直接查表替代计数。完整 PQ OOTF、HDR/EDR、ICC、LUTAnalyst 和资料阻塞仍按未完成状态记录。详见[旧 PQ OOTF 兼容内核验收](native-validation/2026-10-05-legacy-pq-ootf-algorithm.md)。

## 2026-10-05 ICC 四种 rendering intent 的三通道 MPE 子集

新增 `ICCMPETransform`，按 ICC.1:2022-05 §10.16 解析和执行 RGB/`XYZ ` profile 成对的 `D2B0`/`B2D0` perceptual、`D2B1`/`B2D1` relative、`D2B2`/`B2D2` saturation 与 `D2B3`/`B2D3` absolute 三通道 `mpet`：公式曲线、中间曲线段 `samf`、矩阵、float32 CLUT 和 ACS 占位元素。四条 MPE 路径均不读取 `mediaWhitePointTag`，实现只保留解码后的 Double 参数，不打包 profile、厂商 LUT、旧 `.labin` 或等价采样数据。共享数据区间、breakpoint 边界和非有限浮点均有拒绝或 pass-through 契约。

定向 MPE 与 profile route 契约通过；最终完整 Swift/Node/三平台结果见[ICC MPE 验收](native-validation/2026-10-05-icc-mpet-absolute.md)。该子集不减少 9 个 `.labin` 或 45 个直接查表注册项。

该项不等于完整 ICC：真实 profile 独立参照、黑点补偿、gamut mapping、ColorSync 和完整 profile 路由仍未闭合；ICC.1:2022-05 当前 MPE 元素集合已覆盖，未知未来元素仍按规范拒绝，`parf` type 3/4 明确属于传统 `para`。`samf` 只支持中间曲线段，首尾段仍拒绝。

## 2026-10-05 ICC absolute 不同媒体白点 matrix/TRC 子集

`ICCMatrixTRCProfileLink` 现在按 ICC.1:2022-05 §6.3.2.2 公式 (1)–(6) 和 Annex D §D.6.1 公式 (D.6)–(D.7)，将源 media-relative PCS XYZ 转为 absolute，再按目标媒体白点转回目标 relative PCS。不同 `mediaWhitePointTag` 的 absolute matrix/TRC linking 已由 synthetic 独立平方/比例预期核对；relative intent 的白点一致拒绝和 XYZ LUT absolute 拒绝保持不变。传统 Lab PCS absolute 的比例路由见本文件顶部验收记录。实现没有加入 ICC profile、厂商 LUT、旧 `.labin` 或等价采样数据。

该项只关闭 ICC absolute 不同媒体白点比例的数学子集；`DToB3`/`BToD3`、完整 profile 类型／通道／intent、perceptual/saturation、黑点补偿、gamut mapping、系统 ColorSync、真实非 synthetic profile 逐码参照、HDR/EDR 和第三方往返仍未闭合。验收见[ICC absolute 不同媒体白点验收](native-validation/2026-10-05-icc-different-whitepoint-absolute.md)。

## 2026-10-05 原生算法数值入口与目录契约复验

原生数值入口首次运行发现目录检查仍冻结为旧的 76/20/72 计数；当前 `AlgorithmCatalog.builtIn()` 实际为 79 条 transfer、20 个色域、75 个预设。只更新 `LUTCatalogChecks` 的契约计数，稳定 ID、来源、别名、66 个相机身份和预设引用拒绝保持不变。修复后 66 项静态/公式检查、Node 11 项、Swift 命令行算法/格式/LUTAnalysis 检查和目录检查均通过，退出码 0。该修复不减少 9 个 `.labin` 或 45 个直接查表注册，不扩大算法范围。证据见[原生算法数值入口与目录契约复验](native-validation/2026-10-05-algorithm-numerics-gate.md)。

## 2026-10-05 LUTAnalyst 三线性解析 Jacobian 复验

三线性单元候选求解现使用多项式解析 Jacobian，并以强缩放仿射契约独立核对输入坐标。定向 Debug／Release 各 10 项通过；Swift Release 全量 8 个测试包、793 项执行、0 失败，`LUTFormats` 仍有 2 项既有外部夹具跳过，三平台 Release 构建通过。该项只改善已有三线性诊断的数值稳定性，不减少 9 个 `.labin` 或 45 个直接查表注册，也不关闭任意 3D 逆、tricubic、自动分离或完整重建。证据见[LUTAnalyst 三线性三维反求诊断验收](native-validation/2026-10-04-lutanalyst-trilinear-inverse.md)。

## 2026-10-05 LUTAnalyst tetrahedral 生产回放收紧

`Tetrahedral3DInverse` 现在把仿射解视为候选，并用生产 tetrahedral sampler 回放后才接受；新增边界根去重和非单位输入域回映射契约。当前源码复验定向 Debug／Release 各 9 项通过；最近 Swift Release 全量 793 项、0 失败，其中 `LUTAnalysis` 66 项包含四面体 9 项，三平台 Release 构建通过。该收紧不扩大为任意 3D LUT 全局反求；tricubic、组合 shaper、自动分离与完整重建仍未闭合。证据见[四面体反求生产回放收紧验收](native-validation/2026-10-05-lutanalyst-tetrahedral-replay.md)。

## 2026-10-04 LUTAnalyst 三线性三维反求诊断

`Trilinear3DInverse` 只对现有生产三线性网格逐单元求候选，并用生产采样回放确认残差；折叠映射保留多个根，奇异或求解器未能证明的包围盒命中报告 `unresolved`。恒等、双分支、无解、包围盒未决、退化、相邻单元边界根去重、非单位域坐标回映射和拒绝边界契约及 Swift Release 全量回归均通过，详见[LUTAnalyst 三线性三维反求诊断验收](native-validation/2026-10-04-lutanalyst-trilinear-inverse.md)。该子集不推断连续厂商函数，不证明任意 3D LUT 全局唯一性；tricubic、组合 shaper、自动 transfer／colour 分离、生成接线及旧 tricubic 红轴研究阻塞仍未闭合。

## 2026-10-06 LUTAnalyst 三线性严格仿射完备性收紧

三线性报告新增空间单元枚举数、候选单元数和 `isGloballyComplete`。当单元四个混合项严格为零时，使用矩阵反解完整分类唯一解、单元外无解或奇异未决；分段仿射折叠网格因此可以证明全部多根。含任意混合项的单元即使有限 Newton 种子找到并回放验证了根，也强制保留 `unresolved`，因为有限种子不构成全根证明。Release `TrilinearInverseContractsTests` 14 项通过，完整 LUTKit Release 回归通过。详情见[LUTAnalyst 三线性严格仿射单元完备性验收](native-validation/2026-10-06-lutanalyst-trilinear-affine-completeness.md)。该收紧不关闭含混合项三线性、tricubic、任意 3D 全局反求、自动 transfer／colour 分离或完整重建。

## 2026-10-04 HLG OOTF 标量峰值裁切边界

`HLGOOTF.displayToScene` 对等于显示峰值的标量输入返回 `invalidDomain`，因为正向峰值裁切会合并多个场景值。nits 与 `normalizedBy1000` 均有契约和 Release 回归证据；该边界修正不改变合法峰值以下的 Double 公式。详见[HLG OOTF 标量峰值裁切逆向边界验收](native-validation/2026-10-04-hlg-ootf-scalar-clipped-inverse.md)。自动峰值、完整 HDR/OOTF、PQ OOTF 和 EDR 仍未完成。

## 2026-10-04 LUTAnalyst tetrahedral 3D 反求子集

新增的 `Tetrahedral3DInverse` 只诊断现有 tetrahedral 插值的分段仿射数学：穷举每个网格四面体并返回所有满足重投影残差的输入根；折叠映射报告全部分支，奇异／病态候选单元则报告 unresolved。验证覆盖 identity、非对称仿射参照、折叠双根、无解、退化、shaper／插值拒绝。命令、结果包和精度边界见[LUTAnalyst tetrahedral 三维反求诊断验收](native-validation/2026-10-04-lutanalyst-tetrahedral-inverse.md)。

这不是旧版基于逆向采样 LUT 的经验外插，也不把一组有限采样推断为连续厂商函数。trilinear／tricubic 反求、带 shaper 反求和导出生成接线、非 tetrahedral 模式全局多解仍未闭合；旧 `.labin`、直接查表注册和资料不足的厂商算法状态不变。

## 2026-10-04 求根容差有限性边界

LUTAnalyst 求根入口统一拒绝无限或负容差，防止无效 Double 在调用用户函数后被当作立即收敛条件。Brent、二分、Legacy cubic inverse 与全根诊断共用有限性检查；合法参数路径保持不变。定向契约和 Swift Release 全量回归通过，详见[求根容差有限性验收](native-validation/2026-10-04-root-tolerance-finite.md)。该项不减少 9 个 `.labin` 或 45 个查表注册的阻塞计数，也不完成任意 3D 逆。


## 2026-10-04 LUTAnalyst cubic 平台区间诊断补充

在已有一维 cubic 全域多根诊断上，补充恒值平台的连续非唯一区间报告。`LegacyCubicCurve1D.allInverseRoots` 识别整个 cubic 子区间恒等于目标值的情况，并合并相邻区间；`TransferInverseRootDiagnostic` 通过 `nonUniqueBrackets` 保留区间，孤立根仍单独报告。该修正不推断三维逆、不改变采样值，也不把平台压成任意单点。契约先行后实现，平台、孤立根和旧 hump 多根均通过；Release 全量回归 8 个测试包、0 失败，LUTAnalysis 46 项通过。证据见[LUTAnalyst 平台区间诊断验收](native-validation/2026-10-04-lutanalyst-plateau-roots.md)。

## 2026-10-04 后续核验

1D LUT 分析的三通道聚合可逆性契约已补齐；现有 Swift Release 回归和 7 项解析式独立检查通过。查表资源替代仍为 `0/9` 与 `0/45`，完整结果见[算法闭合后续核验](native-validation/2026-10-04-algorithm-closure-followup.md)与[查表替代台账](native-validation/2026-10-04-lut-replacement-inventory.md)。

## 2026-10-04 Fujifilm F-Log legacy 算法补充

旧 `Fujifilm F-Log` 已按 `js/gamma.js` 的九参数 `LUTGammaLog` 实际执行结果建立独立 Swift `Double` 身份，并通过分界、非有限值、legacy 相机路由和 17³/33³/65³ 独立 Decimal CUBE 核对。实现只保存公式常数，不读取或打包 LUT。该补充不等于官方 F-Log 完整设备模型，也不关闭 F-Log2、F-Gamut C、完整 F-Log 相机行为或其他查表台账。证据见[F-Log legacy 验收](native-validation/2026-10-04-flog-legacy-algorithms.md)。

## 2026-10-04 Blackmagic Pocket Film legacy 算法补充

旧 `BMD Pocket Film` 已按 `js/gamma.js` 的九参数 `LUTGammaLog` 实际执行结果建立独立 Swift `Double` 身份，并通过分界、非有限值、计划边界和 17³/33³/65³ 独立 Decimal CUBE 核对。实现只保存公式常数，不读取或打包 LUT。Blackmagic Pocket 的 `Passthrough` 色域没有足够证据推导真实色域，因此未新增公开色域或默认相机路由。其余 45 个直接查表注册项、9 个 `.labin`、DRAGONColor 和完整相机范围仍按逐项台账处理。证据见[Blackmagic Pocket Film 验收](native-validation/2026-10-04-bmd-pocket-film-algorithms.md)。

## 2026-10-04 Canon C-Log 算法补充

旧注册表 C-Log 已按可追溯九参数式建立独立 legacy 解析身份；CP IDT 的 `cpoutdaylight.labin`、`cpouttungsten.labin` 和完整 Canon 官方连续定义仍阻塞，未将查表拟合为算法。证据见[Canon C-Log 验收](native-validation/2026-10-04-canon-clog-algorithms.md)。

## 2026-10-04 REDLogFilm 算法补充

REDLogFilm 已按旧注册表的 Cineon 参数元组建立独立解析身份，REDWideGamutRGB 原色用 Double 矩阵推导；Epic DRAGON 的 DRAGONColor2 默认相机仍阻塞，未将共享公式扩大为完整 RED 支持。证据见[REDLogFilm 验收](native-validation/2026-10-04-red-logfilm-algorithms.md)。这不会减少 45 个查表注册项或 9 个 `.labin` 资源的替代台账。

## 2026-10-04 Sony S-Log／S-Log2 算法补充

旧清单中的 Sony `S-Log`、`S-Log2` 已按解析式接入四个独立身份：公开反射率域与 LUTCalc legacy 灰 0.2 域分别保存，Sony S-Gamut 也单独登记。来源、Double 契约、12 个完整网格和 App 资源审计见[Sony S-Log／S-Log2 验收](native-validation/2026-10-04-sony-log-algorithms.md)。这只关闭两条一维曲线及其默认路由；S-Log3、Sony 风格输出、色温特定 IDT、Venice 专用矩阵和完整 ACES 工作流仍按各自证据管理。45 个查表注册项、9 个 `.labin` 与其他未闭合曲线没有因本补充而减少。

## 2026-10-04 既有 N-Log／Cineon 算法补充

Nikon N-Log 按官方反射率公式与旧 LUTCalc 兼容公式使用不同身份，保留官方分段舍入差异；Cineon 依据公开 Sony Imageworks／Colour Science 公式及旧线性 toe 实现。四条路径只保存公式常数，不读取研发源码、PDF、JSON 或任何 LUT。Z6/Z7 和 Generic 默认按已验收策略接线；资料、单位、分界最小复现、独立误差和实际构建见[相机传递算法验收](native-validation/2026-10-04-camera-transfer-algorithms.md)。9 个资源和 45 个查表注册项的全量替代台账仍未闭合，不把两条曲线登记计为全部算法完成。

## 2026-10-02 Blackmagic Gen5 来源补充

公开 Gen5 采用固定 ACES 官方 CTL 的分段公式、原色和白点，产品只保存可追溯参数，不打包 CTL 或采样表。旧 BMDFilm Gen5 保留独立 legacy 算法身份，避免把历史系数误称为官方公式。四个对应相机默认只在已验证策略下选择，其他 Pocket Film 模型拒绝；完整采样资源替代与全部相机仍未闭合。

## 2026-10-02 相机目录纯算法边界补充

66项相机目录保存旧注册元数据和稳定身份，不含颜色采样节点，运行时不读取旧JS／fixture。曝光由Swift Double和明确舍入算法求值，黑白辅助量由stop推导；baseISO／clipStops仅为旧元数据报告，不能称独立实测。默认resolver仅引用已验收算法身份，公开27／66、旧兼容18／66，其余拒绝而不替换。缺失默认按项待实现／研究，不笼统视为研究阻塞。

本包133个Swift源码边界及三个实际App包审计通过，仍不独自证明全部等价采样表与间接依赖合规。完整厂商风格／直接和间接采样替代及最终依赖审计继续待完成；详见[相机阶段](native-validation/2026-10-02-camera-state.md)。

## 2026-10-02 AWG3 补充

AWG3 的公开原色／D65以Double推导矩阵，SUP3 scene预设显式使用EI公式；不读取研发参照或PDF，不打包CTL、厂商LUT或采样表。CTL仅用于独立参照核对D-Gamut2来源，三平台App资源／直接链接与源码边界审计通过。公开原色推导和六位XYZ舍入差异分开记录，结果见[AWG3验收](native-validation/2026-10-02-awg3.md)。SUP2 raw具有不同光源／目标语义，P3标题冲突按项阻塞；不能以AWG3完成完整相机或全部查表资源替代。

## 2026-10-02 Log C scene 接线补充

两条公开 scene 曲线使用 `ARRILogCCompact` 的公开解析系数和 Double 分段 log／幂／仿射式，EI 显式配置并严格拒绝未知值。产品不读取研发参照／PDF或旧引擎，不打包厂商 LUT或采样表；系数是公开公式的校准参数。scene 路由和原始 sensor API分开；没有把 SUP 2 raw RGB 默认归到 AWG3／AWG4，也未新增相机默认预设。源码、三平台 App 审计及独立数值证据见[接线验收](native-validation/2026-10-02-logc-scene-routing.md)。实际高 EI shoulder、完整相机和厂商风格算法替代仍欠，不能由两条新增曲线关闭完整旧依赖台账。

日期：2026-09-23。范围：当前 JavaScript 实现，以及计划中的全 Swift 原生版本。

## 2026-10-05 LUTAnalyst 组合 shaper 与三维 colour 局部反求

新增 `shaper -> colour` 显式诊断入口：颜色候选和 shaper 逐通道根均须经完整生产 sampler 回放，有限候选遗漏、奇异单元和平段保留为 `unresolved`。Debug／Release 定向、Swift Release 全量、原生数值门禁和三平台 Release 构建均通过。该项只闭合组合接线子集，不关闭任意 3D LUT 全局反求、完整重建、自动分离、查表替代、完整 HDR/ICC 或 Goal。详情见[组合 shaper 与三维 colour 局部反求验收](native-validation/2026-10-05-lutanalyst-combined-shaper-inverse.md)。

随后补充资源边界：四面体诊断在遍历前检查网格四面体总数的溢出和 `maxTetrahedra` 上限，组合 tetrahedral 路径沿用 `maxCells`；超限明确返回错误，不把资源耗尽误报为无解。该修复仍只属于局部诊断安全性，任意三维 LUT 全局反求、全根完备性、自动分离和完整重建保持未闭合。

三线性诊断同步使用溢出安全的 `(size - 1)^3` 盒子计数，并在遍历前检查 `maxBoxes`；这只收紧资源边界，不改变候选根、插值规则或误差阈值。

## 2026-10-04 HLG OOTF 峰值裁切逆向定义域

现有 HLG OOTF RGB 正向逐通道峰值裁切会使到达峰值的通道失去唯一原像；`displayRGBToScene` 现对此类输入返回 `invalidDomain`，不再给出非唯一逆值。契约和全量 Release 证据见[验收记录](native-validation/2026-10-04-hlg-ootf-clipped-inverse.md)。此项只闭合已声明 OOTF 子集的逆域边界，不代表完整 HDR/OOTF、PQ OOTF 或 EDR 完成。

## 1. 结论

**当前实现包含预先采样的 LUT 数据，尚不是全部由公式计算。** 有两种形式：根目录的 9 个 `.labin` 二进制文件，以及 `js/gamma.js` 中直接嵌入采样数组的曲线。这些 `.labin` 是应用使用的加工后资源；不能仅凭文件名认定它们就是厂商未经修改的原始 `.cube`。

2026-10-04 已建立[查表替代台账](native-validation/2026-10-04-lut-replacement-inventory.md)，逐项冻结 9 个资源和 45 个直接查表注册的 SHA-256、旧来源、原生状态与关闭条件。当前没有任何一项满足公开连续定义、适用范围和独立参照的完整关闭条件，因此台账计数保持 `0/9` 与 `0/45`，不得从 App 资源或源码中复制等价采样数据。

本轮只完成审计、资料收集与原生方案修订，尚未替换旧引擎。旧资源保留用于冻结旧行为与验证迁移；新下载的官方 LUT 位于 `research/`，用途也是研发参照。

可重跑的盘点命令：

```sh
node tools/research/snapshot-colour-inventory.js
```

结果见[机器可读快照](../research/colour/2026-09-23/current-inventory.json)：当前执行注册表有 **114 个 gamma 注册项、43 个矩阵色域、66 个相机预设**，包含别名、重复定义和 Generic，不能等同于独立算法或实际机型数。旧静态调查的 118/67 计数不作为迁移验收依据。

## 2. 二进制 LUT

`js/lutmessage.js` 的 `loadGamutLUTs`（当前第 882 行起）通过请求加载以下文件；`js/colourspace.js` 的 `loadColourSpaces`、`defLUTs` 将其用于相应输出变换。

| 文件 | 对应内置变换 |
| --- | --- |
| `LC709.labin` | Sony LC709 |
| `LC709A.labin` | Sony LC709A |
| `s709.labin` | Sony s709 |
| `Cine709.labin` | Sony Cine+709 |
| `Amira709.labin` | ARRI Amira709 |
| `AlexaX2.labin` | ARRI Alexa-X-2 |
| `V709.labin` | Panasonic Varicam V709 |
| `cpoutdaylight.labin` | Canon CP IDT Daylight 对应输出变换 |
| `cpouttungsten.labin` | Canon CP IDT Tungsten 对应输出变换 |

输入端的 `CSCanonIDT` 与输出端的查表资源需要分别审计，不能把整个 Canon IDT 都概括为同一种实现。文件大小与 SHA-256 已保存在快照中。`.labin` 的当前读写代码包含缩放 `Int32` 存储，内存计算再转成 Float64；它不是简单的原始 Float64 文件。

## 3. 隐藏在代码里的查表

已明确识别 **45 个注册项**直接落在以下四类。将数组改写成 Swift 常量、压缩字符串、Base64、纹理或其他文件格式，仍然是内置 LUT，不能满足本次要求。

| 实现类 | 注册数 | 当前名称 |
| --- | ---: | --- |
| `LUTGammaDLog` | 1 | DJI DLog-M |
| `LUTGammaIOLUT` | 9 | DJI Mini 2、s709、Rec709 (800%)、Nikon Standard、Nikon Neutral、Nikon Vivid、Nikon Monochrome、Nikon Portrait、Nikon Landscape |
| `LUTGammaLUTSL3` | 10 | Amira709、Alexa-X-2、LC709A、LC709、Sony Cine+709、Varicam V709、REDGamma、REDGamma2、REDGamma3、REDGamma4 |
| `LUTGammaLUTSimple` | 25 | EOS Standard、EOS Standard (Legal)、Canon Normal 1、Canon Normal 2、Canon Normal 3、Canon Normal 4、HG3250G36 (HG1)、HG4600G30 (HG2)、HG3259G40 (HG3)、HG4609G33 (HG4)、HG8000G36 (HG5)、HG8000G30 (HG6)、HG8009G40 (HG7)、HG8009G33 (HG8)、Cinegamma1、Cinegamma2、Cinegamma3、Cinegamma4、Sony STD1、Sony STD2 - x4.5、Sony STD3 - x3.5、Sony STD4 - SMPTE240M、Sony STD5 - Rec709、Sony STD6 - x5、Canon WideDR |

实现位置：`LUTGammaLUTSL3`、`LUTGammaLUTSimple`、`LUTGammaIOLUT`、`LUTGammaDLog`，位于 `js/gamma.js` 第 5012 行附近及之后。`DJI DLog-M` 使用样条采样表；它不能直接复用已按公式实现的 `DJI D-Log2`。45 是注册项数，不是 45 个独立物理曲线，也不与前述 9 个资源简单相加。

其余条目尚未全部完成纯算法证明。后续还要追踪间接依赖、生成缓存、调节样条、旧 bundle 镜像和特殊输出色域。快照的 `sampleTableBased: false` 只表示未命中这四类，不能解释成“已通过纯算法验收”。

## 4. 原生版本的强制规则

### 4.1 内置颜色变换

- 用 Swift `Double` 实现可追溯的解析函数、分段函数、矩阵、白点适应、色域压缩及有明确数值误差控制的求解器。
- 可以保存规范定义的常量、原色色度坐标、白点、矩阵和模型参数；必须记录来源和版本。
- 不随 App 分发原始或加工后的 `.cube`、`.labin` 等厂商 LUT；不将其节点转存为代码数组、模型权重、贴图或加密资源。
- 不把“将 LUT 全部节点拟合成高阶多项式”或“将每个节点变成样条控制点”称为算法替换。由采样数据估计的低参数模型也需要单独披露，未经来源与误差验收不能作为正式等价实现。
- 在没有用户导入 LUT 的情况下，所有内置变换应能从公式和参数完整重建；导出节点直接求值，不经过预览 LUT。
- 允许运行时从公式生成可丢弃的预览缓存；缓存不得成为计算真值、内置原始资源或导出捷径。

### 4.2 文件功能和研究资料

用户生成的 LUT 是本 App 的产品输出。用户主动导入 LUT、LUTAnalyst 分析、旧格式读写属于处理用户数据的功能，和“内置变换依赖原始 LUT”分别管理。本轮按此理解保留这些功能。

`research/`、原引擎基线和测试夹具可以保存官方 LUT，以便独立比对；它们不得加入 App target、Swift Package 运行资源、安装包或在线下载依赖。预览照片可以作为普通图像资源，但不得利用图像像素偷偷携带颜色查表数据。

### 4.3 精度与功能覆盖

纯算法和“精度不低于现在”同时是约束。对于公开公式，比较旧实现、Swift 实现和独立公式参照。对于只有官方风格 LUT 的项目，目前不能保证存在可精确恢复的公开算法；有限网格不能唯一确定连续色彩映射。

这类项目标记为“公式缺失／待研究”，保留在迁移清单中，不能悄悄删掉后宣布全量完成，也不能用相似观感或拟合误差较小代替等价证明。若最终需要改变该功能的产品范围，必须单独列明并由用户决定。本轮不宣称已经解决这些项目。

## 5. 实施与发布检查

1. 对 9 个二进制资源、45 个直接查表注册项及其他间接依赖建立逐项替代台账。
2. 为每项记录原行为、公开公式来源、适用设备/固件、场景标度、信号范围、拟采用算法及未解决问题。
3. 算法进入产品前冻结定义域、最大/RMS/P99 误差、分段边界与非灰轴样本，再运行独立参照和旧版回归。
4. 使用资源允许列表构建；检查 App archive、Package resources、Copy Bundle Resources、源码内采样数组与变换依赖图。扩展名扫描仅作为辅助，不能单独证明没有查表。
5. 在不提供 `research/` 和旧 `.labin` 的环境中构建并运行内置转换；研究下载器不得参与 App 构建。

## 6. 2026-10-04 RED Log3G10 台账补记

旧注册项 `LUTGammaLogLog RED Log3G10` 已完成公式替代子集：参数、分支、`0.9` legacy-grey 边界及合法数据包装均来自旧源码并以直接 JavaScript 执行参照冻结；Swift 运行时不携带源码、采样节点或厂商 LUT。17³／33³／65³ 独立 Decimal 读回最大通道误差低于 `2.3e-16`，定向和全量 Swift 契约通过。

这不减少四类直接查表注册项的台账数量，也不替代 REDWideGamutRGB 的 DRAGONColor2／IPP2 完整模型；其余查表、`.labin`、完整相机和资料冲突仍必须逐项保留并验收。

## 7. 2026-10-04 Blackmagic Film legacy 台账补记

旧 `BMD Film`、`BMD Film4k`、`BMD Film4.6k` 均为旧 `LUTGammaLog` 解析注册，不属于四类直接查表项。三条曲线已以独立 Swift `Double` 参数实现，并用旧 JavaScript 执行参照和独立 Decimal 全网格读回闭合。它们没有减少 DJI DLog-M、其他 `LUTGammaIOLUT`／`LUTGammaLUTSL3`／`LUTGammaLUTSimple` 查表注册项，也不证明 Blackmagic 真实色域或完整相机工作流已完成。

## 8. 2026-10-04 Bolex/Panalog/DJI X5 台账补记

旧 `Bolex Log`、`Panalog`、`DJI X5/X7/X9 DLog` 同样属于可追溯的 `LUTGammaLog` 解析注册，已分别实现并通过旧 JavaScript 参照和独立 Decimal 网格读回。它们不减少 DJI DLog-M、其他 LUT-only 注册项或九个 `.labin` 资源的替代台账；旧注册表中的色域字符串也没有被当作完整相机/矩阵算法。

配套：[新覆盖调查](colour-research-2026-09-23.md)、[原生设计](native-swift-design.md)、[精度规范](native-swift-precision.md)、[任务清单](native-swift-roadmap.md)。

## 2026-10-05 CIE94 算法边界补记

`CIELABColor.deltaE94(to:application:)` 已按 CIE 116-1995 的 CIE94 公式实现为 Swift `Double` 数学子集，支持图形艺术（`K_L=1, K_1=0.045, K_2=0.015`）和纺织（`K_L=2, K_1=0.048, K_2=0.014`）权重。实现只使用 Lab 数值，不读取旧 JavaScript、`.labin`、厂商 LUT 或采样数组；归一化 `L*` 在指标内部转换到标准 `0...100`。

公开样例、零色度和有限性契约已通过；独立 Python 90 位 `Decimal` 参照记录在[CIE94 验收](native-validation/2026-10-05-cielab-deltae94.md)。该项只证明同一白点／观察条件的 CIE94 距离，不证明白点适应、完整色貌模型、ICC 全量或显示/HDR 路由。其余 `9/9` `.labin`、`45/45` 直接查表、资料冲突和全量迁移状态不变。

## 2026-10-05 CIEDE2000 算法边界补记

`CIELABColor.deltaE2000(to:)` 已按 Sharma、Wu、Dalal（2005）的 CIEDE2000 公开定义实现为 Swift `Double` 数学子集。实现只使用 CIELAB 数值，不读取旧 JavaScript、`.labin`、厂商 LUT 或采样数组；归一化 `L*` 在指标内部转换到标准 `0...100`，不改变 CIELAB 存储和任何 RGB 变换计划。

四组公开参考对、零色度和色相 0/360 度环绕有契约覆盖；独立 Python 90 位 `Decimal` 参照自行实现角度、三角函数和指数。该项只证明同一白点／观察条件的 CIEDE2000 距离，不证明白点适应、完整 CIELAB、CAM、ICC 全量或显示/HDR 路由。其余 `9/9` `.labin`、`45/45` 直接查表、资料冲突和全量迁移状态不变。

## 9. 2026-10-04 DaVinci Intermediate legacy 台账补记

旧 `DaVinci Intermediate` 已按 `js/gamma.js` 的 `LUTGammaDaVinci` 公式完成 Swift `Double` 解析替代，并通过旧 JavaScript 参照和独立 Decimal 17³／33³／65³ CUBE 全点核对。独立校验器曾把 `(log2(x+a)+b)*c` 误写成 `log2(x+a)*c+b`，已修正并保留纠错记录。该项不减少 45 个直接查表注册项、9 个 `.labin` 资源或完整 DaVinci/Resolve 工作流的未闭合范围。

## 10. 2026-10-04 GoPro Protune legacy 台账补记

旧 `Protune` 是 `LUTGammaLog` 九参数注册，已按实际参数式接入 Swift `Double`，包括非十进制对数底 113 和零斜率的固定 `1e-15` 近零分支；17³／33³／65³ 独立 Decimal 全点核对通过。旧元数据中的 `Protune Native` 仍没有公开连续色域定义，因此未补造色域或完整 GoPro 相机模型。该项不减少 LUT-only 注册项和 `.labin` 资源的未闭合台账。详见[GoPro Protune legacy 算法验收](native-validation/2026-10-04-gopro-protune-algorithms.md)。
## 11. 2026-10-04 DJI X3 D-Log legacy 台账补记

旧 `DJI X3 DLog` 是带软肩部的 `LUTGammaLogClip` 解析注册，已按旧参数和分段顺序建立独立 Swift `Double` 身份，并通过旧 JavaScript 参照和独立 Decimal 17³／33³／65³ 全点读回。独立校验器的肩部参数顺序错误已修正；生产实现未改变，也未放宽阈值。该项不减少 DJI DLog-M、其他查表注册项、9 个 `.labin` 资源或完整 DJI 相机／色域台账。详见[DJI X3 D-Log legacy 算法验收](native-validation/2026-10-04-dji-x3-dlog-algorithms.md)。

## 12. 2026-10-04 Null legacy 台账补记

旧 `LUTGammaNull` 不是查表项，而是线性恒等与共享 Legal/Data 包装。已按旧 `linToData`／`linFromData` 接入独立 Swift `Double` 身份，并以独立 Decimal 17³／33³／65³ 逐节点核对。该项不减少 45 个直接查表注册项、9 个 `.labin` 资源或完整旧调节链台账；具体未覆盖范围见[Null legacy 算法验收](native-validation/2026-10-04-null-algorithm.md)。

## 2026-10-06 D-Log2 与 Null legacy 计划身份

默认 DJI D-Log2 和 Null legacy 计划原先可能因只保留固定算法名或 transfer 对而合并不同方向、输入色域和输出色域。`TransformPlan` 现在在这两个分支记录 input/output `TransferID` 与 `ColorSpaceID`；先行红测复现别名，修复后 `NullTransferContractsTests` 及相关计划身份回归通过。解码、编码、矩阵、量化和 Double 数值路径没有改变。

本项只修复缓存/批次身份边界，不减少 DJI DLog-M 等直接查表注册或 `.labin` 台账，也不代表完整 DJI 工作流、ICC/HDR、LUTAnalyst 或平台发布验收完成。详情见[D-Log2 与 Null legacy 计划身份验收](native-validation/2026-10-06-dlog2-plan-identity.md)。

## 13. 2026-10-04 LUTAnalyst 一维 cubic 多根诊断

`LegacyCubicCurve1D` 现在可以在完整定义域内按导数临界点切分并报告所有 inverse roots，`ImportedLUTAnalyzer` 对独立 transfer 的 R/G/B 通道保留多根状态和候选根。该能力只服务用户导入的一维分析数据，不穿越任意三维 colour LUT，也不把有限采样推断成唯一连续模型。定向 Debug／Release 各 18 项、全量 Swift Release 8 个测试包均通过；hump 示例两根的残差不超过 `2e-12`。证据见[一维 cubic 全局多根诊断验收](native-validation/2026-10-04-lutanalyst-global-roots.md)。

该子集不减少 9 个 `.labin` 资源或 45 个直接查表注册项的台账数量；任意三维逆、自动 transfer／colour 分离、完整重建、全局三维多解证明、厂商资料冲突和目标软件往返仍未闭合。

## 14. 2026-10-04 LUTAnalyst 显式仿射 3D 反求生成

`KnownAffine3DTransform` 已由 `KnownAffine3DInversePlan` 显式带入生成请求，冻结矩阵、平移和输入／输出域并生成稳定内容指纹。该逆不从用户 LUT 样本推断；域越界、奇异模型和与其他输入逆组合均拒绝。3³ CUBE 写出后以独立伴随矩阵公式逐通道核对，Debug／Release 最大绝对误差均为 `2.220446049250313e-16`。本项不完成任意 3D LUT 反求、全局多根／唯一性证明或自动 TF／颜色分离重建，FULL-05/H10 继续保持未完成；命令和结果见[LUTAnalyst 显式仿射 3D 反求生成验收](native-validation/2026-10-04-lutanalyst-affine-inverse.md)。

## 15. 2026-10-05 ICC mpet 任意设备通道执行子集

`ICCMPETransform` 已按 ICC.1:2022-05 §10.16.2.1–§10.16.2.4 将设备端执行从 RGB 三通道扩展为 profile color-space signature 声明的 1...15 通道。`matf` 使用 `q × (p+1)` 参数，`clut` 使用 p 维网格和 q 通道输出，`cvst` 可在任意相同输入／输出通道数上串接；PCS 仍严格为三通道 `XYZ `/`Lab `。4 通道 CMYK 动态矩阵、曲线和 4D CLUT 均有契约及 Decimal(90) 参照，定向 22 项和 Swift Release 全量测试通过。

这只是直接用户导入 `mpet` 的通道维度数学闭合，不等同任意通道 ICC profile linking，也没有把 RGB linker、传统 `mft`/`mAB`/`mBA`、未来 MPE 元素、黑点补偿、gamut mapping 或 ColorSync 扩大到已完成。`.labin` `0/9`、直接查表注册 `0/45`、LUTAnalyst 任意 3D 反求和 Goal 状态不变。详情见[ICC mpet 任意设备通道验收](native-validation/2026-10-05-icc-mpet-arbitrary.md)。

## 16. 2026-10-05 ICC 传统任意通道 profile linking

`ICCMFTTransform`、`ICCMABTransform` 及其 XYZ/Lab 适配器现支持用户主动导入的 1...15 通道传统 `mft2`、`mAB`、`mBA` 数组路径；`mft1` 仍作为通用数组执行器保留，但与 `XYZ ` PCS 的 linking 因 ICC 没有定义 8 位 PCSXYZ 编码而明确拒绝。`ICCRGBProfileLink` 对非 RGB 设备使用显式 `[Double]` 相对色度入口，`mAB/mBA` 可选矩阵按连续 3×3 系数后接 3 个 offset 解码，RGB 便利入口和固定 3×3／3×4 矩阵边界不被隐式扩展。定向 Debug／Release 共 62 项、完整 Swift Release 869 项和原生数值门禁均通过，独立 `Decimal(90)` 参照与日志哈希见[ICC 传统任意通道验收](native-validation/2026-10-05-icc-traditional-arbitrary.md)。

该项只关闭传统 LUT profile linking 的任意设备通道相对色度数学子集，不代表真实第三方 profile 逐码参照、所有 profile class 与 rendering intent、传统 `mft1` Lab 真实夹具、black point compensation、gamut mapping、ColorSync、其他 ICC 类型和 MPE 元素、HDR/EDR、目标软件往返、`.labin` `0/9`、直接查表注册 `0/45`、LUTAnalyst 全局 3D 反求或 Goal 完成。

2026-10-06，用户导入 `mpet` 解析器的元素表、矩阵、曲线、采样段整数边界采用溢出安全加乘，并拒绝超过 ICC CLUT 网格头容量的 17 通道输入。Debug／Release 各 25 项定向契约及原生数值门禁通过；这只是解析资源安全修复，不扩大 ICC 功能覆盖。详见[ICC MPE 资源边界验收](native-validation/2026-10-06-icc-mpet-resource-safety.md)。

## 2026-10-06 目录当前计数校准

当前 `AlgorithmCatalog.builtIn()` 与 Release `LUTCatalogChecks` 的实际计数为 82 条 transfer、23 个色域、76 个预设；`swift run --package-path Native/Packages/LUTKit -c release LUTCatalogChecks` 退出码为 `0`。文档中较早的 79/20/75 或 81/23/76 记录保留为对应阶段的历史快照，不作为当前目录状态。
## 2026-10-06 LUTAnalyst tricubic 全局完备性状态收紧

`Tricubic3DInverseReport` 新增 `isGloballyComplete`。由于当前只有有限 Newton 种子和输出包围盒，任何候选 tricubic 单元即使已有生产回放根，也统一保持 `unresolved`；没有候选单元时才可证明无解并报告全局完备。Release 定向 12 项通过。该项不关闭 tricubic 全根隔离、任意 3D 全局反求或完整 LUTAnalyst 重建。

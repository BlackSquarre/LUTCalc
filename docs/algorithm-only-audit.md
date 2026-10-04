# 内置 LUT 依赖审计与纯算法约束

## 2026-10-04 LUTAnalyst 三线性三维反求诊断

`Trilinear3DInverse` 只对现有生产三线性网格逐单元求候选，并用生产采样回放确认残差；折叠映射保留多个根，奇异或求解器未能证明的包围盒命中报告 `unresolved`。恒等、双分支、无解、包围盒未决、退化和拒绝边界契约及 Swift Release 全量回归均通过，详见[LUTAnalyst 三线性三维反求诊断验收](native-validation/2026-10-04-lutanalyst-trilinear-inverse.md)。该子集不推断连续厂商函数，不证明任意 3D LUT 全局唯一性；tricubic、组合 shaper、自动 transfer／colour 分离、生成接线及旧 tricubic 红轴研究阻塞仍未闭合。

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

## 9. 2026-10-04 DaVinci Intermediate legacy 台账补记

旧 `DaVinci Intermediate` 已按 `js/gamma.js` 的 `LUTGammaDaVinci` 公式完成 Swift `Double` 解析替代，并通过旧 JavaScript 参照和独立 Decimal 17³／33³／65³ CUBE 全点核对。独立校验器曾把 `(log2(x+a)+b)*c` 误写成 `log2(x+a)*c+b`，已修正并保留纠错记录。该项不减少 45 个直接查表注册项、9 个 `.labin` 资源或完整 DaVinci/Resolve 工作流的未闭合范围。

## 10. 2026-10-04 GoPro Protune legacy 台账补记

旧 `Protune` 是 `LUTGammaLog` 九参数注册，已按实际参数式接入 Swift `Double`，包括非十进制对数底 113 和零斜率的固定 `1e-15` 近零分支；17³／33³／65³ 独立 Decimal 全点核对通过。旧元数据中的 `Protune Native` 仍没有公开连续色域定义，因此未补造色域或完整 GoPro 相机模型。该项不减少 LUT-only 注册项和 `.labin` 资源的未闭合台账。详见[GoPro Protune legacy 算法验收](native-validation/2026-10-04-gopro-protune-algorithms.md)。
## 11. 2026-10-04 DJI X3 D-Log legacy 台账补记

旧 `DJI X3 DLog` 是带软肩部的 `LUTGammaLogClip` 解析注册，已按旧参数和分段顺序建立独立 Swift `Double` 身份，并通过旧 JavaScript 参照和独立 Decimal 17³／33³／65³ 全点读回。独立校验器的肩部参数顺序错误已修正；生产实现未改变，也未放宽阈值。该项不减少 DJI DLog-M、其他查表注册项、9 个 `.labin` 资源或完整 DJI 相机／色域台账。详见[DJI X3 D-Log legacy 算法验收](native-validation/2026-10-04-dji-x3-dlog-algorithms.md)。

## 12. 2026-10-04 Null legacy 台账补记

旧 `LUTGammaNull` 不是查表项，而是线性恒等与共享 Legal/Data 包装。已按旧 `linToData`／`linFromData` 接入独立 Swift `Double` 身份，并以独立 Decimal 17³／33³／65³ 逐节点核对。该项不减少 45 个直接查表注册项、9 个 `.labin` 资源或完整旧调节链台账；具体未覆盖范围见[Null legacy 算法验收](native-validation/2026-10-04-null-algorithm.md)。

## 13. 2026-10-04 LUTAnalyst 一维 cubic 多根诊断

`LegacyCubicCurve1D` 现在可以在完整定义域内按导数临界点切分并报告所有 inverse roots，`ImportedLUTAnalyzer` 对独立 transfer 的 R/G/B 通道保留多根状态和候选根。该能力只服务用户导入的一维分析数据，不穿越任意三维 colour LUT，也不把有限采样推断成唯一连续模型。定向 Debug／Release 各 18 项、全量 Swift Release 8 个测试包均通过；hump 示例两根的残差不超过 `2e-12`。证据见[一维 cubic 全局多根诊断验收](native-validation/2026-10-04-lutanalyst-global-roots.md)。

该子集不减少 9 个 `.labin` 资源或 45 个直接查表注册项的台账数量；任意三维逆、自动 transfer／colour 分离、完整重建、全局三维多解证明、厂商资料冲突和目标软件往返仍未闭合。

## 14. 2026-10-04 LUTAnalyst 显式仿射 3D 反求生成

`KnownAffine3DTransform` 已由 `KnownAffine3DInversePlan` 显式带入生成请求，冻结矩阵、平移和输入／输出域并生成稳定内容指纹。该逆不从用户 LUT 样本推断；域越界、奇异模型和与其他输入逆组合均拒绝。3³ CUBE 写出后以独立伴随矩阵公式逐通道核对，Debug／Release 最大绝对误差均为 `2.220446049250313e-16`。本项不完成任意 3D LUT 反求、全局多根／唯一性证明或自动 TF／颜色分离重建，FULL-05/H10 继续保持未完成；命令和结果见[LUTAnalyst 显式仿射 3D 反求生成验收](native-validation/2026-10-04-lutanalyst-affine-inverse.md)。

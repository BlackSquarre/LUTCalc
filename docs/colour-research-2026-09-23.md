# 色彩空间、曲线与设备覆盖补充调查

调查日期：2026-09-23。基线：[当前运行注册表快照](../research/colour/2026-09-23/current-inventory.json)。这是一份待实现列表，不是已支持列表；本轮未改动颜色计算代码。

资料归档见[本地资料索引](../research/colour/2026-09-23/README.md)。可直接下载的官方 PDF、代码、LUT 已归档；受登录或网络限制的项目保留入口与失败记录。本文中的“未找到”仅指本轮检索结果，不表示厂商一定没有公开资料。

## 1. 优先补充的曲线与色域

优先级表示后续研究与实现顺序。资料状态分为：**公式可用**、**资料冲突**、**仅参考转换**、**待取得公式**；均须通过精度验收才能进入原生 App。

| ID / 优先级 | 缺少的项目 | 当前已有部分与准确分类 | 官方证据、资料状态与实施边界 |
| --- | --- | --- | --- |
| G01 / P1 | **Apple Log 2 + Apple Wide Gamut** | 已有 Apple Log 和 BT.2020；不能用它们冒充 Log 2 的颜色定义 | [Apple API](https://developer.apple.com/documentation/avfoundation/avcapturecolorspace/applelog2)、[iPhone 17 Pro 规格](https://www.apple.com/iphone-17-pro/specs/)。API 文本已归档；[Developer Downloads](https://developer.apple.com/download/all/?q=Apple%20Log)白皮书尚未取得，**待取得公式**；暂不判断两代曲线能否共享同一函数。 |
| G02 / P1 | **F-Log2 C / F-Gamut C** | 已有 F-Log2；主要新增色域及配对预设，**F-Log2 C 与 F-Log2 使用相同传递函数** | [富士技术资料](https://www.fujifilm-x.com/global/support/download/technical-data/)。已下载数据表 1.0、F-Log2 数据表 1.1、CTL/CLF 1.10；**公式可用**。新色域不能与原 F-Gamut/BT.2020 合并。 |
| G03 / P1 | **Leica L-Log** | 曲线缺失；现有 BT.2020/BT.709 色域可复用，未发现应新增“L-Gamut”的依据 | [L-Log 手册 1.9](https://leica-camera.com/sites/default/files/pm-37826-L-Log_Reference_Manual_V1.9.pdf)，已落盘，**公式可用**。SL（Typ 601）用 BT.709，手册其余相应用例用 BT.2020；ProRes 内录范围与其他编码区别必须保留。 |
| G04 / P1 | **KineLOG3 + Kinefinity Wide Gamut** | 两者均缺失 | [Kinefinity 技术规范](https://kinefinity.com/support/guides/kinelog3-technical-specifications)，已存网页，给出分段公式、原色/白点和矩阵；**公式可用**。页面列出的设备适用性不能外推到所有旧款 KineLOG。 |
| G05 / P1 | **Insta360 10-bit I-Log** | 缺曲线，BT.2020 已有 | [官方白皮书](https://wassets.insta360.com/common/31f0330509384b7b8ba0a07f4ff4eb13/Insta360_10-bit_I-Log_White_Paper.pdf)，已下载，**公式可用**。文档包含 2025 曲线更新及 2026 修订；旧 8-bit I-Log、不同机型不能直接归入同一版本。 |
| G06 / P1 | **Xiaomi / Mi-Log** | 缺曲线，BT.2020 已有 | [小米 ACES 入口](https://www.mi.com/global/product/aces/)，资料包已下载：白皮书、可读 DCTL、工作流 PDF、官方 LUT；**公式可用**。先核对资料版本适用机型，不把所有小米手机 Log 一概同化。 |
| G07 / P1 | **OPPO O-Log、O-Log2** | 两代曲线均缺失；两份白皮书采用 BT.2020 | [官方入口](https://www.oppo.com/cn/log-to-rec709-download/)。白皮书、O-Log2 CTL/DCTL、SDR/HDR LUT 已归档；**资料冲突**：O-Log2 白皮书的低段与官方代码不一致，须先裁决。 |
| G08 / P1 | **Samsung Log** | 缺少专用曲线和准确配对定义 | [Samsung 开发者入口](https://developer.samsung.com/mobile/samsung-log-video.html)。网页已保存，白皮书、Log→Linear 1D LUT、Log→Rec.709 3D LUT 的链接已登记；下载跳转登录，**待取得公式**。不把登录 HTML 当下载成功。 |
| G09 / P1 | **GP-Log、GP-Log2** | 当前 Protune 不能代表现代 GP-Log；需要分代、固件/参数建模 | [GoPro Labs 说明](https://gopro.github.io/labs/log/)、[官方 GP-Log2 生成器](https://gopro.github.io/labs/gplog2/)，已归档。GP-Log2 的 base 600、BT.2020 算法可见；负值延拓与曝光/显示风格还需审计。第一代 GP-Log 单独补资料，不照搬 GP-Log2。 |
| G10 / P2 | **OM-Log400** | 曲线缺失；P3-D65、BT.2020 已有 | [OM 官方表](https://support.jp.omsystem.com/jp/support/cs/soft/3dlut/3dlutdl.html)。两种色域版本 LUT 和 OM-1 II 数据表已下载；当前为**仅参考转换**，未找到完整解析曲线。不是新增“OM-Gamut”。 |
| G11 / P2 | **vivo Log** | 曲线与完整输入颜色定义缺失 | [官方支持入口](https://www.vivo.com/my/support/questionList?categoryId=10906)，官方 ACES 资料包已下载。包含流程 PDF、技术 LUT、风格 LUT 和 `.dctle`；代码为加密形式，**仅参考转换**，不等于已经拿到可移植公式。 |
| G12 / P2 | **Honor Magic-Log 两代/组别** | 缺曲线与对应输入色彩定义 | [荣耀官方页面](https://www.honor.com/cn/phones/rec-lut-download/)。两组官方 `.cube` 已下载；**仅参考转换**。机型适用列表不同，不依据机型编号猜代际；文件名中的 v1/v2 不作为正式公开数学规范名称。 |
| G13 / P2 | **Z CAM Z-Log2** | 缺曲线与准确色域定义 | [官方资源页](https://www.z-cam.com/resources/)、[E2 Mark II 手册](https://www.z-cam.com/wp-content/uploads/2025/11/Z-CAM-E2-Mark-II-series-_-User-Manual-Draft-V1.0.pdf)。资料证明模式存在；资源页本地请求 403，**待取得公式**。ZlogColor 插件是参考工作流，不能直接成为 Swift 算法依赖。 |
| G14 / P2 | **Sigma BF 的 L-Log 设备配对** | BF 相机预设与 L-Log 缺失；不是凭名称再造一套 Sigma Log | [Sigma BF 官方规格](https://www.sigma-global.com/en/cameras/bf)，网页已保存。规格确认 L-Log，但其色域、范围与 Leica 公式版本对应关系尚需设备资料确认。 |

## 2. 标准、显示及完整工作流

| ID / 优先级 | 项目 | 当前状态与要补的内容 | 官方依据 |
| --- | --- | --- | --- |
| S01 / P1 | **ACEScct** | 已有 ACEScc/AP0/AP1，缺带线性趾部的 ACEScct；按公开分段公式实现 | [ACEScct 规范](https://docs.acescentral.com/encodings/acescct/)，网页已存 |
| S02 / P1 | **BT.1886** | γ2.4 只有在特定黑位条件下才等价；需完整黑/白亮度参数 EOTF 与逆映射 | [ITU-R BT.1886](https://www.itu.int/rec/R-REC-BT.1886-0-201103-I)，PDF 已存 |
| S03 / P1 | **BT.2020 10-bit 与精确连续形式** | 已有名为 Rec2020 12-bit 的项。10-bit 的实用 OETF 常数可复用 BT.709 数学，但需明确配对 BT.2020、范围与版本；精确连续形式单独标识 | [BT.2020-2](https://www.itu.int/rec/R-REC-BT.2020)，PDF 已存；不得只改 UI 名称忽略常数选择 |
| S04 / P1 | **Display P3 完整配置** | P3-D65 原色与 sRGB 曲线均已有，主要补组合配置、颜色元数据和预览；不是新原色三角形 | [Apple Display P3](https://developer.apple.com/documentation/coregraphics/cgcolorspace/displayp3)，官方文本已存 |
| S05 / P2 | **BT.601 525 / 625 原色** | 补 SMPTE-C 对应 525 和 EBU 对应 625 的原色定义；两者都不能直接别名为 Rec.709 | [ITU-R BT.2380 色度报告](https://www.itu.int/dms_pub/itu-r/opb/rep/R-REP-BT.2380-2015-PDF-E.pdf)，PDF 已存 |
| S06 / P2 | **SMPTE 240M 独立配置** | 已有 Sony STD4 的采样曲线，不代表标准的原色、OETF 与范围已独立实现；偏历史兼容用途 | 同上色度报告；传递函数及标准版本需继续补齐 |
| W01 / P2 | **ACES 1.3 Reference Gamut Compression** | 当前自定义 gamut limiter 不等于 ACES RGC；补独立算法与参数约定 | [RGC 规范](https://docs.acescentral.com/rgc/specification/)，网页已存 |
| W02 / P2 | **ACES 2 Output Transform** | 新增完整输出渲染链：色调、色度、色域压缩与显示编码，不能当作一个 gamma 项 | [ACES 输出架构](https://docs.acescentral.com/system-components/output-transforms/)，网页已存；参考实现仍需锁定版本、完整获取与比对 |

以上共 **22 组核心候选**：14 组设备/曲线方向、8 组标准/工作流方向。组别包含多代或多项，并非新增独立函数数量。scRGB、Rec.709-A 等可继续补充工作流调查；前者涉及扩展范围/编码配置，后者不能在没有软件语义证据时假定为统一国际标准 gamma。

## 3. 厂商风格与设备模式：单独研究，不伪装成 Log

| 候选 | 缺口与研究边界 | 官方依据 |
| --- | --- | --- |
| Sony S-Cinetone | 与现有 s709/LC709A 不同，涉及 gamma 和 Color Mode；暂无本轮可直接移植的完整解析模型 | [Sony Picture Profile](https://helpguide.sony.net/ilc/2410/v1/en/contents/0412D_picture_profile.html)，网页已存 |
| Sony HLG1/HLG2/HLG3 | 已有标准 HLG，但相机模式的最大输出电平、范围与处理设置需补；不武断认定是三个全新基础函数 | 同上，官方明确不同模式的动态范围/噪声平衡及最大输出差异 |
| Panasonic Cinelike D2/V2/A2、Like709 等 | V-Log 已有；机内风格未覆盖，必须区分机型、参数与不可逆处理 | [S1II 手册](https://help.na.panasonic.com/wp-content/uploads/2025/06/DCS1M2_OperatingInstructions_ENG.pdf)，记录官方入口，本轮未下载整本 |
| Blackmagic Video / Extended Video | Film Gen5、Blackmagic Wide Gamut 已有；Video 系列属于显示风格，不能只用 Rec.709 替代 | [官方相机手册](https://documents.blackmagicdesign.com/UserManuals/BlackmagicCinemaCameraManual.pdf)、[产品说明](https://www.blackmagicdesign.com/ca/products/blackmagicpocketcinemacamera)，记录入口 |
| DJI 不同设备 D-Log M 输出风格 | 当前 DLog-M 是遗留采样实现，不代表现代全部机型/摄像头；官方按设备分别提供 LUT，要逐代核验 | [DJI 官方 LUT 总表](https://www.dji.com/lut)，网页已存，包含 Mini 4 Pro、Air 3/3S、Avata 2、Pocket 3、Action 系列等 |
| RED IPP2 输出渲染 | REDWideGamutRGB/Log3G10 已有；完整色调映射、highlight roll-off、输出风格另算工作流 | [RED 官方输出颜色说明](https://docs.red.com/955-0190_v1.3/955-0190_v1.3_REV-1.3_RED_PS_KOMODO_Operation_Guide/Content/4_Menus/Image_LUT/OutputColorSpace.htm)，详细公式/参照待补 |

普通照片风格、胶片模拟、锐化、降噪、局部色调处理不能都建模为一条一维 gamma，部分也不能由单个像素的 RGB→RGB LUT 完整表达。

## 4. 主要缺少相机预设的方向

算法已存在不代表预设准确；加入设备必须补 ISO/EI、范围、固件、曝光标度与高光裁剪证据。下列先列代表性机型，不声称遍历全部市场产品。

| 设备方向 | 可复用的现有基础 | 还需核验的预设信息 |
| --- | --- | --- |
| Sony VENICE 2、BURANO、α7S III 等新 Alpha | S-Log3 与 S-Gamut3/Cine | 与旧 VENICE 修正矩阵是否相同、双原生 ISO、Cine EI；[Sony 工作流指南](https://pro.sony/s3/2024/11/29133636/Sony_CineAlta_WF_Guide_v1.0.pdf)下载请求 403，保留入口 |
| Canon C400、C80，以及更新的 Cinema EOS | Canon Log2/3、Cinema Gamut | 模式与多档原生 ISO；[C400 官方规格](https://s7d1.scene7.com/is/content/canon/EOSC400_full_specificationspdf)。当前 `C500mkIII` 标签另列为待核实，不据此猜测真实机型 |
| Panasonic GH6/GH7、S1II/S1IIE/S1RII 等 | V-Log/V-Gamut；部分可用已有 LogC3 | [官方 LogC3 扩展说明](https://av.jpn.support.panasonic.com/support/global/cs/dsc/download/fts/enhance/gh6_gh7/index.html)已归档；激活条件、EI 固定策略和实际模式另核验 |
| Nikon Z8/Z9/Z6III、ZR | N-Log 已有；ZR 的 REDWideGamutRGB/Log3G10 也已有 | [ZR 官方页面](https://www.nikonusa.com/p/zr/2006/overview)已存；各编码模式分开。开发预告中的固件特性不可作为已发布能力登记 |
| 新 RED KOMODO / V-RAPTOR 系列 | REDWideGamutRGB / Log3G10 | 按传感器、固件和 RAW 解码输出确定参数；不能把所有传感器都套用 Epic Dragon 裁剪 |
| 新 Fuji X / GFX 机型 | F-Log / F-Log2；新增 F-Gamut C 后可配 F-Log2 C | 具体模式、固件与基准 ISO，按富士各机型官方技术资料映射 |
| iPhone 16 Pro / 17 Pro 等 | 第一代 Apple Log 已有；Log 2 待实现 | 曲线代际与录制 API/编码方式，不能单按机型强制选择一条曲线 |
| DJI Mavic 3 系列、Mini 4 Pro、Air 3/3S、Pocket 3、Action/Avata 等 | 标准 HLG、部分 D-Log 基础已有 | D-Log M 需要补算法和代际验证，不能归为“只加一个设备名称” |
| 新 Blackmagic 型号/模式 | BWG/Film Gen5 已有；快照中已含 URSA Cine、PYXIS | 优先检查现有预设正确性和变体，不把整个系列重复列为完全缺失 |

## 5. 已发现的资料问题与裁决要求

1. **OPPO O-Log2：白皮书与 CTL/DCTL 冲突。** 白皮书给出低段二次函数及平方根逆函数；官方 ACES 包中的 V2 代码只使用对数/指数段，并采用更粗的常数。两者不能作为可互换的唯一真值。应分别锁定资料版本，制作暗部/负值/分段邻域对照，确认实际素材与适用范围后再决定实现版本。
2. **O-Log2 表格与公式也需复核。** 表格将 1600% 反射率的 Linear Signal 写为 1，按同页公式直接令输入为 1 并不会输出 1；需确认表格标度/笔误。不能用“官方”二字跳过一致性检查。
3. **OPPO O-Log 第一代：** 白皮书编解码描述涉及额外标度，需核对编码与解码是否采用相同的场景归一化后再做 round-trip；不直接机械拼成互逆函数。
4. **小米：** 白皮书段落有自然对数措辞，但公式明确 `log2`，可读 DCTL 也使用底数 2。以一致的公式/参考代码建模并记录文字歧义；不要误用 `ln`。参考 DCTL 的矩阵有小数截断，原生版应从规范原色推导 Double 矩阵后独立验证。
5. **GoPro GP-Log2：** 官方网页生成器对负输入的编码做符号延拓，而解码函数未呈现相同的负半轴镜像。先限定官方定义域；负值扩展必须单独规定，不声称全域自动可逆。生成器还含曝光/显示调整，不应全部混入基础 Log 曲线。
6. **vivo：** `.dctle` 是加密参考实现，本轮没有公开可读公式；ACES 工作流文档不是解析曲线规范。
7. **OM：** 数据表给出几个曝光点及色域，足以校验标度，不足以唯一恢复整条曲线；Log→WDR Rec.709 LUT 也包含输出渲染，不能直接倒推成纯 Log 解码。
8. **源资料精度：** PDF 中取整的码值、四位小数矩阵、LUT 的节点量化与插值都必须单列误差。仅提高 Swift 的小数打印位数不能解决这些问题。

## 6. 对旧覆盖调查的更正

保留旧英文文件作为历史记录，当前决策以本调查和运行快照为准：

- 118 个曲线/67 个相机的静态计数改为运行注册项 114/66；43 是矩阵条目数，特殊变换另计。
- BT.601 的 525/625 原色不等于 Rec.709；Display P3 是原色、白点和传递函数组合，不能只写成 P3-D65 的无条件同义词。
- Leica L-Log 不应先假定搭配独立 L-Gamut；OM-Log400 不应假定搭配 OM-Gamut。
- 本轮无依据把 Leica M11 列为 Log 视频相机；移出待实现设备清单。
- DaVinci Wide Gamut/Intermediate、ARRI LogC4/AWG4、N-Log、D-Log2/D-Gamut2、Blackmagic Film Gen5 已在当前注册表，不能再列为全新缺失算法。

## 7. 后续任务

- [x] 运行现有注册表，归档清单与源码/旧资源哈希。
- [x] 区分内置二进制 LUT、代码采样表、解析算法和设备预设。
- [x] 搜索主要设备/标准缺口，保存可取得的官方技术材料与下载状态。
- [ ] 取得 Samsung Log 的完整公式资料及 Apple Log 2 的原厂白皮书/设备适用说明；继续寻找 OM、vivo、Honor、Z CAM、D-Log M 的公开数学定义。Apple Log 2 的 ACES CTL 解析式已于 2026-09-24 取得，见下方更新。
- [ ] 裁决 OPPO 等冲突，建立版本化公式台账与独立夹具。
- [ ] 按纯算法要求实现并逐项验收；尚无任何本表新增项目在产品中完成。

新增覆盖与旧功能的纯算法替换独立跟踪，不能用新增数量抵消旧功能缺失。详细工程任务见[原生迁移任务清单](native-swift-roadmap.md)。

## 2026-09-24 资料更新：G01 Apple Log 2

[ACES Apple 输入转换仓库](https://github.com/aces-aswf/aces-input-and-colorspaces/tree/main/apple)新增可公开取得的 Apple Log 2 正反向 CTL。其输入 CTL 与原始 Apple Log CTL 使用同一解析曲线和常数，但 Log 2 输入原色为 Apple Wide Gamut，而原始版为 Rec.2020。两份正反向 CTL 已归档于 `research/colour/2026-09-24/`，文件哈希和数值验收见[H11 Apple Log 阶段验收](native-validation/2026-09-24-h11-applelog.md)。因此上表 G01 的“待取得公式”是 **2026-09-23 调查时的状态**，现更新为“ACES CTL 公式可用，原厂白皮书和设备适用范围仍待核实”。新增能力继续独立记账，不能据此把旧功能覆盖标记完成。

## 2026-10-03 资料更新：Display P3 D65

历史表中的 Display P3 “主要补组合配置、颜色元数据和预览”仍保留当时语义。原生后端现已登记 `display.p3-d65.v1`，采用 Apple Display P3 公开原色与 D65 白点，并以独立 Double 矩阵参照验收。屏幕色彩管理、EDR/HDR 和 UI 预览仍未完成，详见[Display P3 D65 色域后端验收](native-validation/2026-10-03-display-p3.md)。

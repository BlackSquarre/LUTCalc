# LUTCalc 原生功能覆盖报告

## 2026-10-02 Blackmagic Gen5 阶段

公开／legacy Blackmagic Gen5 transfer 与 Wide Gamut Gen5 已接入，四个对应相机默认可选择；独立 scalar、矩阵和完整文件误差均低于 `2e-12`，Release519项和三平台新构建通过。当前公开相机默认31／66、旧兼容22／66；Pocket Film、完整相机实测／sensor／shoulder仍欠。详见[Gen5验收](native-validation/2026-10-02-bmdgen5.md)。

## 2026-10-02 当前非 UI 覆盖：相机后端阶段

当前schema19，46曲线／15色域／42转换预设，另有66稳定相机身份及曝光三类政策。完整Release512项／0失败／2项既有夹具跳过、三平台新未签名构建和数值／源码／App审计通过；完整文件和独立误差见[相机后端验收](native-validation/2026-10-02-camera-state.md)。公开默认可选择31／66、旧兼容22／66，剩余35／44项明确拒绝；不能把身份数量当成全部相机转换完成，不能全部称研究阻塞。

暂缓所有UI；其余算法、完整默认／Generic／camClip／sensor、白平衡／PSST／HDR／ICC、LUTAnalyst／格式、来源重发现／提供商／后台、性能和签名发布仍欠，见[非UI最新清单](native-validation/2026-10-02-non-ui-remaining-current.md)。真实全量清单缺失，检查退出2，Goal active。下文旧状态保留其当时语义。

## 此前归档：2026-10-02 AWG3 阶段

schema18、46曲线／15色域／42预设，AWG3与11个SUP3 scene显式EI预设及本地文稿／文件接线已验收；8项Debug／502项Release、三平台未签名构建、独立全码／完整网格和源码／App审计通过。详见[阶段证据](native-validation/2026-10-02-awg3.md)。完整相机、实际shoulder、旧算法完整覆盖、ICC/HDR、分析／格式、提供商／后台、性能／签名仍未完成。UI暂缓，真实全量清单缺失，检查退出2，不计算完成率。

更新：2026-10-02。UI 相关工作按用户要求暂缓，后续重做。当前非 UI 范围与源码核对见[最新审计](native-validation/2026-10-02-non-ui-scope-audit.md)。

## 已有实现和证据

最新接续为[Log C scene 非 UI 接线](native-validation/2026-10-02-logc-scene-routing.md)：SUP 2／3 scene exposure 的 22 配置、显式 EI、计划／输出锚点、schema 17、后端编辑、项目重开和真实 CUBE／SPI1D 路由已通过阶段验证。8 项 Debug／494 项 Release（0 失败、2 跳过），三平台构建／数值子集／源码与实际 App 包审计通过；最终原字节留存、退出等待观察修复及 Debug 存储／进程 11 项复验通过，见结果包。当前实际目录 **46 曲线、14 色域、31 预设**。sensor 生成单位、AWG3 默认映射和完整相机模型继续待完成，下段保留前一内核包的历史范围。

此前非 UI 归档为 Log C 公开公式内核：3 项定向 Debug／485 项 Release（0 失败、2 跳过）、三平台构建和审计、44 配置的独立全码及四配置完整网格通过，尚未接入计划／项目／App 生成路由，不计为新增注册项或完整相机迁移。来源、公开接缝／旧高 EI 差异与边界见[内核验收](native-validation/2026-10-02-logc-compact.md)。当前目录实际为 44 曲线、14 色域、31 预设，此前 CLI 输出的 30 已修正为实际集合数量。

schema 16 批次预设的保存／重开／显式请求重建仍保留[其验收](native-validation/2026-10-02-batch-project-preset.md)，不证明自动重发现、提供商授权恢复、全部格式批量或完整相机模型。

| 范围 | 当前状态 | 证据 |
| --- | --- | --- |
| 共用 Swift 数值内核、注册表和项目模型 | 已实现并通过子集契约 | `Scripts/verify-native-numerics.sh` |
| D-Log2/D-Gamut2 → Double → CUBE | 已通过独立参照 | H05/H06 验收记录 |
| Log C 公开紧凑公式内核 | SUP 2／3、sensor／scene、11 EI 共 44 解析配置，独立全码／边界及四配置完整网格通过；尚未接入计划／项目／App 生成；实际高 EI shoulder 与连续模型仍研究阻塞 | `2026-10-02-logc-compact.md`、`2026-10-02-logc3-shoulder-research.md` |
| ASC-CDL 旧工作空间版本 | SOP／工作空间 Y 饱和度、独立 1D 语义、schema 4／快照及程序化 CUBE/SPI1D 子集通过；完整调节链未完成 | `2026-10-02-asc-cdl.md` |
| SDR Saturation 旧输出线性版本 | 阶段 11、schema 5／快照、程序化 CUBE、1D 耦合拒绝和旧解码／色域／曝光／CDL／SDR 17³ 组合子集通过；完整 HDR/OOTF 未完成 | `2026-10-02-sdr-saturation.md` |
| Multitone 旧工作空间版本 | 阶段 9、schema 6／快照、程序化文稿重开／CUBE、1D 耦合拒绝、独立 Decimal 全网格及旧 CDL／Multitone／SDR 组合子集通过；完整调节链与全部色域／CAT 未完成 | `2026-10-02-multitone.md` |
| Black Gamma 输出编码版本 | 阶段 15、schema 7、默认稳定／旧兼容版本、1D/3D、程序化磁盘保存与导出子集通过；Knee 锚点准备已补；完整 HDR 参数与全部输出变体仍缺，旧兼容次正规边界不符合连续公式精度 | `2026-10-02-black-gamma.md` |
| 黑白电平 Legal 仿射版本 | 阶段 14、schema 8、默认值／锁定规则、Black Gamma 阈值联动、1D/3D 与程序化文稿／文件子集通过；Knee 锚点准备已补；完整 HDR 准备与全部变体仍未完成 | `2026-10-02-black-highlight.md` |
| Knee 输出 Hermite 旧兼容版本 | 阶段 13、黑白电平／Black Gamma 锚点、schema 9、程序化保存／导出、独立全网格及旧组合链子集通过；旧第二段有非单调边界，完整输出变体／HDR 仍缺 | `2026-10-02-knee.md` |
| Highlight Gamut 输出混合旧兼容版本 | 阶段 10、两种过渡、schema 10、1D 耦合拒绝、独立原色/CAT/Decimal及四个全网格、旧组合链与程序化文件子集通过；其余旧空间／CAT／全参数和设备验收仍缺 | `2026-10-02-highlight-gamut.md` |
| Gamut Limiter 双阶段旧兼容版本 | 阶段 12／17、Linear／Post Gamma、主／次级／同时保护、schema 11、独立四个全网格、两条旧组合链与程序化文件子集通过；阶段 16 的 SDR 主／次级依赖现已补齐；HDR 显示依赖、其余空间／CAT／全参数与设备验收仍缺 | `2026-10-02-gamut-limiter.md` |
| 输出码值单位身份与修复 | 19 个实际 Data 包装的曲线元数据修复、complete v2／历史 partial v1、schema 12、独立全网格与程序化 CUBE／1024 点 SPI1D 通过；partial v1 仅重现已知旧缺陷；后续 SDR 显示转换见下行 | `2026-10-02-output-code-units.md` |
| CUBE、SPI1D、SPI3D 及若干严格格式子集 | 子集通过 | H04/FULL-06 阶段记录 |
| SDR 显示转换 | 阶段 16、23 曲线／7 显示色域、固定 CAT02、1D 跳矩阵、主／次级显示依赖、schema 13／快照／磁盘项目、独立四个全网格、两条旧 17³ 组合链及 CUBE／1024 点 SPI1D 子集通过；4 个 HDR 变体、完整调节链及设备数值仍缺 | `2026-10-02-display-conversion.md` |
| False Colour 导出原生阈值版本 | 阶段 05 快照／18 覆盖、schema 14、显式 exportLUT、128 开关组合、四个独立全网格、两条旧组合链、磁盘／CUBE／1D 拒绝／任务子集通过；192 个 V8 边界差异保留，逐位旧兼容、完整限幅及跨设备仍欠 | `2026-10-02-false-colour.md` |
| Final Output 显式格式边界／用户限幅 | 阶段 19、schema 15、四模式／959 上限／反转上下限、独立四个完整网格、两条实际旧限幅子链、磁盘项目／CUBE／SPI1D／任务子集通过；完整 HDR 自动峰值、独立限制模型／统计、全部格式联动和设备仍欠 | `2026-10-02-final-output.md` |
| 精确曝光批量 | 64 组序列／864 点、逐文件事务／覆盖／取消、报告磁盘显式恢复、文稿快照、七个 17³／八个完整 33³/65³ CUBE、SPI1D 子集通过；自动检查点／进程恢复／项目预设／完整相机／全部格式仍欠；单通道调度接通见后续行 | `2026-10-02-exposure-batch.md` |
| 单通道服务调度参数 | 四条路由显式传递 worker／blockNodes、固定长度保留；32 个实际文件字节确定性、独立恒等全点、强制乱序窗口与真实取消、用户 LUT／批次接线定向契约通过；设备预算与真实提供商仍欠 | `2026-10-02-oned-scheduling.md` |
| 批量自动检查点／本地进程恢复 | generating／prepared／completed 原子持久化、lease、目标／staging 身份、六个真实 SIGKILL／独立重启、取消和独立文件子集通过；设备后台／提供商、资产重发现、项目预设与全部格式仍欠 | `2026-10-02-batch-checkpoint.md` |
| 批次项目预设 | schema 16、8 格式预设身份、严格字段、原生 schema 1–15 明确迁移与磁盘原字节不改写；后端编辑／撤销／自包含用户资源重开／指纹／显式 checkpoint 恢复和 CUBE／SPI1D 子集通过；来源自动发现、授权、全部格式批量与完整相机仍欠 | `2026-10-02-batch-project-preset.md` |
| 用户 LUT 导入、取样、生成后置阶段和基础分析 | 线性／四面体／域内 tricubic、1D cubic／组合 shaper前向，schema 3配置与原始资产持久化子集通过 | H07/H10阶段记录、`2026-10-02-user-lut-post-stage.md` |
| ImageIO 原始样本、ICC metadata、CPU 预览 | 子集通过 | H13 阶段记录 |
| macOS 项目保存重开 | 系统保存及一次Finder直接双击冷启动与字段恢复已有证据；后续UI工作暂缓 | `2026-10-02-macos-finder-schema3.md` |
| iPhone 11 原生 UI | 6 项 UI 测试通过 | `2026-09-26-iphone11-device.md` |

## 尚未达到完整迁移

- 全部旧曲线、相机预设和官方风格 LUT 的纯算法替代。
- 完整旧调节链、cubic反求／旧3D域外、完整LUTAnalyst和任意3D反求；已完成前向cubic不再列为整体未实现。
- 白平衡 Planck 轨迹与 PSST 四组固定映射的生成来源尚未闭合，实际最小复现已归档；不能将表直接搬入产品。
- 全部格式方言、目标软件往返和 `.lacube/.labin` 全量兼容。
- File Provider/iCloud真实授权失效、替换竞争和故障恢复；已有本地Files保存与部分项目重开证据。UI、iPad交互、多窗口及后续Finder/Files界面验收暂缓。
- 完整 ICC 工作空间/显示转换、Core Image/Metal 等价、HDR/EDR 屏幕验证。
- 性能预算、发行签名、安装升级和全量发布清单。

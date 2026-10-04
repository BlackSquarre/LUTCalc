# 2026-10-02 非 UI 剩余范围最新核对

## 2026-10-03 Display P3 D65 补记

- 已新增 `display.p3-d65.v1` 色域身份、Display P3 D65 原色和目录来源；独立 Decimal RGB→XYZ 参照最大绝对误差低于 `2e-15`，Debug/Release 定向契约和当前 Release 全量回归通过。详见[Display P3 D65 色域后端验收](2026-10-03-display-p3.md)。
- 这只闭合色域身份和 CPU 矩阵，不闭合真实显示色彩管理、EDR/HDR、ICC 嵌入与 linking、项目 schema 或 UI；这些缺口继续保留。

## 2026-10-03 ICC RGB profile linking 统一入口补记

- `ICCRGBProfileLink` 已把已有 matrix/TRC 与有限 LUT linking 子集统一到显式分派入口；混合类型和 unsupported intent 拒绝契约、当前 Swift Release 全量 610 项和三平台构建均通过。
- 这只改善调用边界，不扩大 ICC 算法覆盖；完整 profile 类型／PCS／intent、黑点补偿、gamut mapping、系统色彩管理、项目接入和跨平台参照仍未完成。详见[ICC RGB profile linking 统一分派验收](2026-10-03-icc-rgb-profile-link.md)。

## 2026-10-03 QA-01 性能基线复跑补记

- 当前 macOS arm64 Swift Release 的 17³/33³/65³ 标量 `CubeGenerator` 五次复跑中位耗时为 `0.000373292`／`0.002521625`／`0.018510042` 秒，Double 位模式校验和与既有基线一致。
- 同一进程的 `/usr/bin/time -l` 最大常驻集观测为 `16,236,544` 字节；它包含 Swift 运行时和启动开销，只作 Mac 上界，不替代 iPhone/iPad 峰值预算。
- 这只新增一台 Mac 的可重复基线，不关闭峰值内存、批量／分析／图像／文件写出、取消延迟、实体 iPhone 11、iPad 模拟器或发布性能缺口。完整记录见[QA-01 macOS Double 性能基线复跑](2026-10-03-qa01-macos-performance-rerun.md)。

## 2026-10-03 本地来源身份与自动重发现补记

- 已完成本地、调用方已授权目录内的来源身份保存与自动重发现子集：SHA-256 匹配，原始文件名消歧，缺失／歧义／非法根／符号链接／重复资产路径显式失败。6 项定向契约、Release 全量 597 项和三平台 Release 构建及原生边界审计通过。
- 这不证明安全书签生成与失效恢复、真实 iCloud/File Provider 授权撤销、跨进程 provider、目标替换竞争、磁盘故障或 iPhone 11 后台恢复。完整范围仍按下表和后续研究记录保留。

## 2026-10-03 安全书签与并发错误定位补记

- 已新增独立的 Foundation bookmark 后端：macOS 使用 security scope，iOS 因 SDK 明确 unavailable 改用普通 bookmark data；解析结果报告 stale，非法来源 fail closed。完整 Release 600 项、三平台构建和原生边界审计通过。
- 同轮修复并发生成错误定位，避免多 worker 完成顺序改变最早失败的 `sampleIndex`。这只闭合错误定位契约，不等于 provider 撤权、stale 续期、后台恢复或目标替换竞争已经通过。

## 2026-10-03 项目包目标替换竞争补记

- `ProjectStore.saveExisting` 已在 `NSFileCoordinator` 协调回调内检查 manifest 字节和项目目录身份，目标在发布边界被替换时拒绝并保留竞争者；2 项定向契约、Release 全量 602 项和三平台构建通过。
- 这只覆盖本地 Foundation 协调写入路径；真实 iCloud/File Provider provider 事务、跨进程不合作写入者、授权撤销、stale 续期、磁盘故障和后台恢复仍未证明。

## 2026-10-02 设置派生路径静态审计补记

- 审计范围为 `Native/Packages/LUTKit/Sources` 中生产 Swift 路径的 `TransformSettings` 手工构造，重点检查 HLG OOTF schema 22 新字段在预览、文稿、会话、相机、批次和导出快照中的保留行为。
- `TransformPlan.swift` 的全部 `with...` 派生方法均继续传递 `hlgOOTF`；切换输出 transfer 时按既有契约仅在输出 transfer 改变时清除 OOTF。相机、批次、项目资产和文稿包装路径均沿用完整 settings 快照。
- `CPUPreview.renderDisplay` 对 HLG/PQ 显示输出明确抛出 `unsupportedDisplayTransfer`；其独立 SDR 显示设置不携带 OOTF 是隔离显示预览与数值/导出计划的既定行为，不计为字段丢失。
- 新增 `HLGOOTFContractsTests.testDerivedSettingsPreserveHLGOOTFUntilOutputTransferChanges`，覆盖 22 个设置派生入口和一次输出 transfer 切换。定向命令 `swift test --package-path Native/Packages/LUTKit --filter HLGOOTFContractsTests` 实际执行 7 项、0 失败。
- 审计期间修复 `LUTDocumentExportChecks.changed` 的手工设置重建：改用 `old.settings.withExposureStops(exposure)`，避免导出检查路径丢失 HLG OOTF 及其他可选阶段。该修复保持检查工具与生产复制语义一致；不扩大 HLG OOTF 的算法覆盖范围，也不改变 UI 暂缓或 Goal active 状态。

## 2026-10-03 HLG OOTF 与一维输出边界修复

- 发现 `LUT1DGenerationRequest` 的降维守卫未检查启用的 HLG OOTF。该算子按输出亮度耦合 RGB 三通道，将其写入独立通道的 SPI1D 会改变定义，因此属于有损表示。
- 已在一维请求构造处拒绝 `hlgOOTF.enabled == true`，错误为既有 `SPI1DFailure(.lossyRepresentation, line: 0)`；不改变三维 CUBE 的 HLG 计划路径。
- 先补契约再修改实现：`SPI1DGenerationContractsTests.testOneDGenerationRejectsHLGOOTFBecauseItIsRGBCoupled` 与同套 11 项定向测试实际通过，退出码 0。完整回归仍需在本轮改动后重新执行。
- 修复后的完整命令 `swift test --package-path Native/Packages/LUTKit` 于 2026-10-03 实际通过：8 个测试包共执行 535 项、0 失败；LUTFormats 的旧 `.labin` 与 NCP 外部夹具各 1 项跳过。完整日志为 `/tmp/lutcalc-settings-audit-full-20261002.log`。外层 shell 曾因使用 zsh 保留变量名 `status` 未打印退出码，但日志已到达全部测试包 `All tests passed`；随后以测试结果确认 Swift 命令本身完成且无失败。

## 当前基准与用户范围

## 2026-10-03 ICC profile class 与通道元数据补记

- ICC 头部 profile/device class 与 color space 通道数现有受验证的只读摘要；零填充历史夹具保持未知，非法填充 class 显式失败。Debug/Release 定向、Release 全量回归、三平台 Release 构建及源码/App 审计均通过，详见[ICC profile class 与通道元数据验收](2026-10-03-icc-header-class.md)。
- 该补记不扩大 ICC 转换、profile linking 或显示色彩管理范围；完整 PCS、profile 类型、其他 intent、黑点补偿、gamut mapping、多通道、跨平台参照和 UI 仍按下表保留。

## 2026-10-03 ICC 头部语义枚举补记

- 已知 profile class 与 `XYZ `/`Lab ` PCS 现有可追溯语义枚举；未知未来签名和历史零填充夹具保持 fail-closed。Debug/Release 定向、Release 全量、三平台未签名 Release 构建及源码/App 审计通过，详见[ICC 头部语义枚举验收](2026-10-03-icc-header-semantics.md)。
- 该子集不扩大 ICC 转换覆盖；完整 ICC profile 类型／通道／intent、黑点补偿、gamut mapping、系统色彩管理、跨平台参照、项目接入和第三方往返仍未完成。

## 2026-10-03 PQ OOTF 研究阻塞补记

- 旧 PQ OOTF 在 `input≈0.03024` 的分段阈值两侧约有 `1.78e-3` nits 跳变，且 `Lw`、`scale` 与输入单位无法从现有资料唯一解释；来源、旧源码哈希和最小复现见[PQ OOTF 公式冲突研究阻塞](2026-10-03-pq-ootf-research.md)。
- 因此不猜公式、不把旧路径伪装成 BT.2100 标准实现；PQ OOTF、自动峰值／参考白／黑位、四种 HDR 显示变体和真实 HDR/EDR 仍未完成。

## 2026-10-03 Canon C-Log3 非 UI 子集补记

- 已接入 ACES 固定提交中的 Canon C-Log3 三段 `Double` 传递、Canon Cinema Gamut 目录描述、C-Log3 → linear AP0 预设和 schema 21 门槛；Cinema Gamut 单独使用不会误选 C-Log3 计划。定向 Debug/Release、项目 schema 契约、全量 Swift Release、三平台未签名 Release 构建和源码/App 边界审计通过。
- 该子集不等于 Canon 全机型迁移：C-Log、CP IDT、连续 EI、raw 校准、高 EI shoulder、相机默认覆盖、设备数值和发布验收仍欠。完整记录见[Canon C-Log3 验收](2026-10-03-canon-clog3.md)。

按用户要求暂缓全部 UI：界面、布局、控件、无障碍、旋转、多窗口、交互预览，以及依赖 Finder／Files／目标软件界面的操作验收均留到后续。已有代码与真实证据保留。计算、解析、调度、存储、文件后端、来源、性能和发布继续属于当前范围；原 H01–H14／FULL-01 至 FULL-08 最终范围不缩减。

最新归档为[Blackmagic Gen5](2026-10-02-bmdgen5.md)：schema20，48曲线、16色域、44转换预设，另有66个相机身份。相机状态基础见[相机身份与曝光后端](2026-10-02-camera-state.md)。Gen5最终Release519项，完整文件独立读回最大1.3828205532518545e-12，三平台新路径构建、数值、源码和App审计通过；完整相机状态仍按相机记录保留。

66项身份／曝光三类政策现已接通，公开默认可选择31／66、旧兼容22／66，其余明确拒绝。不能再把全部相机模型写成“没有实现”，也不能把这轮通过算成完整相机完成。

## 非 UI 未完成清单

2026-10-02 已完成一个有来源的 Canon C-Log2/Cinema Gamut 非 UI 子包：新增公开/legacy TransferID、Cinema Gamut 原色、CAT02 矩阵、三个 C-Log2 相机默认、schema21 门槛，并完成 33³/65³ CUBE 独立逐点比较。证据见[Canon C-Log2 验收](2026-10-02-canon-clog2.md)。随后已补 C-Log3 的标量／目录／计划／schema 子集，当前仍不覆盖 C-Log、CP IDT、连续 EI、shoulder 或全部 Canon 相机，因此 FULL-02 仍未完成。

Canon 包随后补齐了 90 位 `Decimal` 矩阵和四个实际 CUBE 的逐点独立重读，并重新跑通完整 Swift 回归（526 项执行、0 失败、2 项既有夹具跳过）；这只闭合该子包的数值参照和回归证据，不扩大算法覆盖范围。

2026-10-02 又补齐 HLG 显示 OOTF 的独立 Swift `Double` 标量/RGB 内核、严格域检查和 80 位 Decimal 参照；随后接入 `HLGOOTFSettings`、项目 schema 22、算法版本登记和 `TransformPlan` 的显式 130 子阶段。2026-10-03 已补齐 nits 计划在 stage 13 HLG OETF 边界的归一化，stage 130 仍保留 nits 显示单位；这只是 HLG OOTF 计划子集，不等于完整 HDR/OOTF 或屏幕显示完成。详细证据见[HLG OOTF nits 计划验收](2026-10-03-hlg-ootf-nits-plan.md)和[HLG OOTF schema22 阶段](2026-10-02-hlg-ootf-schema22.md)。

2026-10-03 又补齐严格单值 1D cubic 的逐段导数检查和 Brent 反求，并接入用户 1D LUT 分析入口；hump、常值段和任意三维 LUT 仍拒绝。随后把该能力接入 schema 23 项目清单、用户资产重开、曝光批次和 1D/3D 导出边界；1D 导出遇到该 3D 输入反求明确拒绝。完整证据见[旧 1D cubic 反求验收](2026-10-03-legacy-cubic-inverse.md)和[项目持久化与导出传播验收](2026-10-03-cubic-inverse-project-persistence.md)。这仍不代表完整 LUTAnalyst、任意 3D 逆或 FULL-05/FULL-07 完成。

| 原范围 | 已有阶段 | 仍未完成 |
| --- | --- | --- |
| FULL-01／H03／H11／H14 算法 | 有来源的曲线、16色域、CAT02／Bradford及独立公式批次 | 全部旧有效曲线／色域／特殊空间的逐项映射；其他CAT、自定义空间、全部参数域及算法版本／来源／旧差异闭合。注册数包含别名和新增版本，不能相减算完成率。 |
| FULL-02 相机 | 66稳定身份、ISO／曝光政策、公开SUP2／3 scene显式EI、AWG3、项目及批次后端 | 公开默认仍缺35项、旧兼容44项；Generic完整Cineon／Rec.709、Venice特殊色域、Canon／BMD／DJI／Nikon／RED等。完整camClip辅助分析、sensor生成单位、SUP2 raw校准、连续EI和实际高EI shoulder仍欠。元数据不是全部相机独立实测。 |
| FULL-03／04 调节与HDR | ASC-CDL、Multitone、SDR Saturation、Black Gamma、黑白电平、Knee、Highlight Gamut、Gamut Limiter、SDR显示转换、False Colour、Final Output已验收子集；HLG OOTF 数学、schema 22 和 nits 归一化计划子集已新增 | 白平衡、PSST-CDL的来源／算子／持久化；完整原顺序和组合；4个HDR显示变体、PQ/HLG峰值／参考白／黑位自动准备、HDR/EDR屏幕与完整裁剪统计仍欠；旧Null、相机／用户／格式独立限制、全部格式联动。 |
| H13 ICC与图像数学 | matrix/TRC、三通道 mft／mAB／mBA 的 PCS Lab 与 16 位 PCS XYZ CPU 子集；ICC `u1Fixed15` 编解码；ImageIO、原始码值、alpha与方向基础；RGB matrix/TRC 的 PCS XYZ relative colorimetric linking 子集；profile class／PCS 语义与 color space 通道数只读摘要 | 完整 ICC 类型、通道、PCS、profile linking 的其他渲染意图及独立参照；黑点补偿、gamut mapping、其他像素布局和跨平台数值。现有 CPU 子集不等于完整 ICC；显示与图表暂缓。详见 `2026-10-03-icc-header-class.md`、`2026-10-03-icc-header-semantics.md`、`2026-10-03-icc-pcs-xyz.md`。 |
| FULL-05／07 LUTAnalyst与资源 | 线性单调1D反求、严格单值用户 1D cubic 反求、组合 shaper 独立一维 cubic 反求、用户cubic前向、用户.lacube／.labin读写及 shaper 子集；3D `LUTGenerationRequest`、schema 23 项目清单、曝光批次和导出边界已接入严格 1D cubic 反求 | 病态／多解的完整报告、完整 TF／颜色分离与重建、分析元数据／方向／量化兼容；任意 3D 逆仍显式拒绝。9 个内置资源、45 个直接查表项及间接依赖的逐项算法替代／研究台账仍须闭合；项目接线子集不把 FULL-05／FULL-07 勾选完成。 |
| FULL-06 格式 | CUBE／SPI1D／SPI3D／VLT等已实现格式各有子集；实体iPhone11已有本地文件证据；`.3dl` Lustre/Kodak 已有纯 Swift 流式写出，线性及可量化非线性 shaper 已接入解析、直接序列化和流式生成 | 其他设备布局；NCP 写出和机型验证；全参数、独立互操作和全部格式批量覆盖。两个既有夹具跳过不能算全格式通过。依赖目标软件界面的往返暂缓。 |
| FULL-08／H08／H12 文件后端 | 精确曝光批量、1D调度提示、批次项目预设、自动检查点、本地真实SIGKILL恢复；项目打开、新建／覆盖保存及导出启动边界按 3600 秒宽限期回收旧 `.lutcalc-*.staging`／`.backup`／`.tmp`；本地来源身份、哈希自动重发现、Foundation bookmark 后端和本地协调目标替换契约 | 真实 iCloud／File Provider 授权撤销、iOS Files 生命周期与 stale 续期、provider 目标替换竞争、iPhone11后台恢复、磁盘故障矩阵、跨进程提供商行为、全部格式批量。显式请求重建和本地恢复不证明 iCloud 或后台自动恢复。 |
| QA／REL 性能与发布 | 已有子集Release、三平台未签名构建、源码／App资源扫描 | CPU、峰值内存、流式写出、取消延迟及批量／cubic／shaper／分析／图像预算；实体iPhone11、iPad模拟器计算基线；完整跨平台数值、源码等价采样表与依赖审计；签名、归档、公证／渠道、安装升级、最终文档及真实逐项全量验收。 |

## 研究阻塞与普通待实现的区别

白平衡轨迹、PSST固定映射、厂商风格公开公式、旧域外tricubic、任意3D逆多解、NCP资料和实际高EI shoulder有按项研究记录。缺失相机默认不全部属于研究阻塞；有公开可追溯公式的项继续落实契约／实现／独立验证。

SUP2 raw已有按光源／目标区分的公开矩阵，末尾两个不同P3表标题重复tungsten，需来源和语义复核，不可猜第二项为daylight，也不可统称无公开矩阵。来源与最小复现见[SUP2记录](2026-10-02-sup2-raw-matrix-research.md)和[shoulder记录](2026-10-02-logc3-shoulder-research.md)。公开compact LogC不证明完整相机shoulder。

## 已完成子集与推进建议

曝光批量、1D调度、批次项目预设、本地检查点／真实进程恢复、LogC scene接线、AWG3及相机身份／曝光后端不再列为完全未实现。对应历史状态与日志见[范围历史审计](2026-10-02-non-ui-scope-audit.md)，旧冻结包不回写。

下一优先工作为明确有来源的缺失曲线／色域与相机默认，其次HDR数学／ICC／明确可证明的格式分析模型，以及来源恢复／磁盘故障。数值闭合后补设备性能与签名发布。每包先契约、再实现和实际验收；独立阈值不放宽。

本包再次实际运行全量证据检查，退出 **2**：真实 `docs/native-validation/full-scope-acceptance.json` 缺失，未创建清单。当前阶段证据见 `artifacts/2026-10-02-camera-state/`。本轮没有设备、UI或签名发行操作，Goal **active**。

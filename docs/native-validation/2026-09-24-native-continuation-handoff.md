# 原生迁移续接记录

日期：2026-09-24。用户要求本轮当前工作结束后停止，下一对话继续同一目标；Goal **尚未完成**。

## 当前可核验状态

- 范围与硬性边界以根目录 `AGENTS.md`、如存在的 `codex.md`，以及 `docs/native-swift-handoff.md`、`docs/native-swift-design.md`、`docs/native-swift-numeric-contracts.md`、`docs/native-swift-runtime-contracts.md`、`docs/native-swift-precision.md`、`docs/native-swift-roadmap.md`、`docs/algorithm-only-audit.md`、`docs/colour-research-2026-09-23.md` 为准。新增文档用中文；UI 仅做功能草稿，用户会单独设计。
- 本轮新完成 `.spi1d`/`.spi3d` 的纯 Swift 格式解析/写出、用户主动只读 LUT 数值导入草稿，以及 SPI3D 通过既有 Double 分块任务、临时文件事务、文档会话导出的路径。阶段详情见[格式记录](2026-09-24-spi1d-format.md)、[SPI3D 格式记录](2026-09-24-spi3d-format.md)、[用户导入记录](2026-09-24-user-lut-import-draft.md)、[SPI3D 流式导出记录](2026-09-24-spi3d-stream-export.md)。这些是子集，FULL-06/H04/H07/H08/H09 均未全量完成。
- 本轮最终源码在 Xcode 27.0 / Swift 6.4 下实际运行 `bash tools/native-validation/verify-native-release.sh`：旧 Node 9 项、Python 资源审计 3 项、Swift Release XCTest 52 项通过；macOS、iOS Simulator、iOS generic 三个 Release 构建成功，三个包审计通过。日志 `/tmp/lutcalc-spi3d-stream-release-20260924.log`。发布入口退出码 2，因缺少真实全量验收清单 `docs/native-validation/full-scope-acceptance.json`；**不得伪造该文件或宣称发布就绪**。
- iPhone Air 真机上此前版本的 17³ D-Log2→线性 AP0 CUBE 已逐节点对独立参照通过，最大缩放误差约 `3.0642e-14`；macOS 真实系统文件面板的 SPI1D 数值导入已核对。**本轮最新版 SPI3D 导出未在真机运行**：当前 `devicectl` 列该机 `unavailable`，指定设备的构建失败（目标不可用）。iPhone Air 模拟器本版安装启动并显示原生文档浏览器，尚未实际点选 SPI3D 导出。
- 当前 Git 仓库没有 `HEAD`，`git status --short` 显示项目文件为未跟踪；保留所有用户文件和改动，不执行清理、重置或覆盖。不要将旧 `.labin`、厂商 LUT、旧引擎或测试夹具加入 App 包。

## 下次优先动作

1. 先读上述规则和路线图，检查工作区实际状态与最新源码，不把本记录当成无需复核的实时状态。当前源码基准可用 `ProjectDocumentView.swift` SHA-256 `41ac9ad343626cd5e0b8581535428147e00e03cc63831996388ca34ffd8f8c1c` 核对。
2. 若 iPhone Air 恢复可用，构建/安装当前版本，在真机草稿里选择 SPI3D 并生成 17³；仅从本 App 容器取回自身导出的文件，独立按显式坐标与冻结 D-Log2 参照逐节点比较，同时检查取消和系统分享实际结果。若仍不可用，记录具体状态，推进不依赖设备的规范完整工作。
3. 继续 H01–H14 的第一个前置条件已满足且尚未完成项。优先补 FULL-06 剩余格式和 SPI1D 生成、H13 图像/平台路径及 H08 File Provider/设备事务；旧 App 设置迁移已明确取消，不再安排。每一小段先契约测试，再实现、验证、及时写入 `docs/native-validation/` 并更新路线图。遇到公式或资料阻塞，保留最小复现与误差并转向其他已授权任务。
4. 代码、编译、数值、真机、发布分别判断。不要修改冻结预期、降低 Double 精度/网格/位宽或放宽阈值。Goal 仅在 H01–H14 与全量验收真正完成后标记完成。

## 2026-09-25 状态补记

- iPhone Air 已恢复连接并保持解锁。当前 iOS Debug 版本在实体设备上生成 17³ SPI3D，从本 App 容器取回 314,850 字节文件；SHA-256 为 `3be602340ee14790104bfeb3d85a84920d54906b293085908a523eeea64bef2c`。4,913 个节点按显式坐标独立比较通过，最大尺度化误差 `3.064215547965432e-14`，阈值 `2e-12`，详见[真机 SPI3D 验收](2026-09-24-spi3d-device-export.md)。
- 文稿中的系统分享面板已实际打开，显示约 315 KB SPI3D 和“保存到‘文件’”。进入该入口后设备镜像连接中断，未取得 Files 最终保存或取消后的应用状态，因此这两项仍未验收。
- 旧设备不可用记录仍是历史状态，不覆盖上述当前真机证据；Goal 仍未完成，发布门槛仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 未通过。

## 2026-09-25 续接收尾补记

- 最新 `bash tools/native-validation/verify-native-release.sh` 已完成：静态边界、旧 Node 11 项、Python 审计 3 项、Swift Release 构建/测试、macOS/iOS Simulator/iOS generic Release 构建和 3 个 App 包资源审计均通过；入口最终退出码为 2，唯一发布门槛失败仍是缺少真实 `docs/native-validation/full-scope-acceptance.json`，未伪造清单。
- 独立 `swift test -c release --package-path Native/Packages/LUTKit` 的 8 个测试目标合计 117 项 XCTest、0 失败（按各目标最终 `All tests` 汇总，日志 `/tmp/lutcalc-swift-release-20260925.log`）。这只说明当前代码与契约回归通过，不代表完整迁移或发布就绪。
- 按用户要求锁屏后设备镜像恢复；在 Files 面板选择“我的 iPhone”并点击“保存”，随后返回 LUTCalc 文稿且继续显示生成成功与分享入口，构成一次系统保存提交后的界面证据。第二次进入 Files 时镜像再次中断，取消后的应用状态和 Files 中目标文件的独立读回仍未验收。真机 SPI3D 生成、容器取回和逐节点比较的已通过证据不变，详情见[真机 SPI3D 验收](2026-09-24-spi3d-device-export.md)。
- ILUT/OLUT 1D 导出的符号零输入域边界已先写契约、确认失败、实现并通过当前 120 项 Swift Release 回归及三平台构建；详情见[阶段验收](2026-09-25-ilut-olut-signed-zero-domain.md)。发布入口仍因真实全量清单缺失退出 2。
- 用户最新要求：真机连接不稳定的剩余测试暂缓，最后集中执行；后续先推进不依赖真机的工作包，不再为当前 Files 读回/取消请求用户操作。

## 2026-09-25 非真机工作补记

- H04 CUBE 样本首通道 `NaN`/`Infinity` 的错误类别已按契约修正为带行号的 `nonFiniteValue`，先失败后通过的定向契约见[阶段验收](2026-09-25-h04-cube-leading-nonfinite.md)。H13 文稿 ID 切换现撤销图像源解释确认、清除旧图像/取样，并丢弃旧加载的迟到结果，先失败后通过的命令行契约见[阶段验收](2026-09-25-h13-document-switch-image-gate.md)。
- 两项整合后的当前源码已执行 `bash tools/native-validation/verify-native-release.sh`：Node 11 项、Python 审计 3 项、Swift Release XCTest 121 项、macOS/iOS Simulator/iOS generic 三个 Release 构建及三个 App 包资源审计通过；日志 `/tmp/lutcalc-h04-h13-integrated-release-20260925.log`。发布入口仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出 2。此前 117/120 项数字只对应各自历史源码状态。
- 真机 Files 独立读回与取消、其他曲线真机数值、完整 H01–H14 及发布验收仍未完成；按用户安排暂缓连接不稳的真机工作，继续非设备工作包。

## 2026-09-25 L-Log 与批量回归补记

- Leica L-Log V1.9 BT.2020 相机子集已接入，明确排除 SL（Typ 601）BT.709 设备范围；公式、来源和独立读回见[H11 Leica L-Log 阶段验收](2026-09-25-h11-llog-stage.md)。
- L-Log 33³/65³ CUBE 独立逐节点检查均通过，最大尺度化误差 `3.049417739399331e-16`，门槛 `2e-12`。本轮 `swift test --list-tests` 为 141 项，三平台 Release 构建和三包资源审计通过；完整入口日志为 `/tmp/lutcalc-llog-release-20260925.log`。
- 发布入口仍退出 2，唯一直接原因是缺少真实 `docs/native-validation/full-scope-acceptance.json`；未伪造清单。真机新增曲线、Files 独立读回/取消及其他连接不稳项目继续按用户要求最后集中执行。

## 2026-09-25 KineLOG3 阶段补记

- KineLOG3 与 Kinefinity Wide Gamut 官方同色域子集已接入，先失败后通过的定向契约为 3 项，目录身份契约为 1 项；阶段详情见[H11 KineLOG3 阶段验收](2026-09-25-h11-kinelog3-stage.md)。
- 33³/65³ 独立 CUBE 读回通过，最大尺度化误差均为 `1.1150635581761299e-15`，阈值 `2e-12`。CLI 与批量入口已接线；跨色域矩阵、设备全范围和真机验证未宣称完成。
- 当前完整 Release 回归已完成：`swift test --list-tests` 为 145 项，三平台 Release 构建和三包资源审计通过；完整证据见[145 项 Swift 回归与发布门槛记录](2026-09-25-after-kinelog3-release-gate.md)。发布清单缺失和真机暂缓状态不变。

- 旧版 F-Log2 兼容候选已按独立 ID 接入，官方 F-Log2 路径未改；定向 6 项曲线契约、注册表身份契约和 33³/65³ 批量逐节点检查通过，阶段详情见[H11 旧版 F-Log2 阶段记录](2026-09-25-h11-flog2-legacy-stage.md)。
- 旧版 F-Log2 接线后的完整 Release 回归为 151 项，三平台 Release 构建与三个 App 包资源审计通过；日志 `/tmp/lutcalc-flog2-legacy-release-20260925.log`，SHA-256 为 `0b4543c988ab685393a325d8d1189e0ba094962dee1dbe7daa51b1963cea70c2`。发布入口仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出 2，真机新增曲线及其余发布证据保持未完成。

## 2026-09-25 H13 ICC 字节校验补记

- H13 新增 PNG `iCCP` 原始 profile 读取、zlib 解包、ICC 长度/`acsp`/色空间/PCS 固定头校验和 SHA-256；源文件 ICC 字节与 ImageIO 解码空间继续分开记录，不触发隐式转换。
- 先失败后通过的定向 `PreviewContractsTests` 为 3 项；`LUTImageChecks` 的嵌入 ICC 原始字节、无嵌入来源、PNG/TIFF/JPEG、方向、预乘 alpha 和资源限制检查通过。阶段详情见[H13 ICC 字节校验记录](2026-09-25-h13-icc-byte-validation.md)。
- 集中 Release 回归为 152 项 Swift 测试，旧 Node/Python 契约、既有 33³/65³ 数值逐节点检查、macOS/iOS Simulator/iOS generic Release 构建和 3 个 App 包资源审计均通过。日志 `/tmp/lutcalc-h13-icc-release-20260925.log`，SHA-256 为 `6f1c103bccd8c6d7f3a5d535b66d75681c914d898a51d7ea498a8beb0b7bc87c`。
- 发布入口仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出 2；ICC 完整 tag 解析、显示/工作空间转换、整图显示、HDR/EDR、双端运行、真机和 Files 读回/取消仍未完成。Goal 保持 active。

## 2026-09-25 H13 ICC tag directory 补记

- 在 PNG `iCCP` 原始字节校验基础上，新增 ICC tag count、tag signature、偏移/长度、重复 tag 和表边界检查；不执行 tag payload 语义解析或颜色转换。详情见[H13 ICC tag directory 阶段验收](2026-09-25-h13-icc-tag-directory.md)。
- 先失败后通过的 `PreviewContractsTests` 为 4 项；`LUTImageChecks` 的真实 sRGB profile tag directory 通过。
- 集中 Release 回归当前为 155 项 Swift 测试，旧 Node/Python 契约、既有 33³/65³ 数值逐节点检查、三平台 Release 构建和 3 个 App 包资源审计均通过。日志 `/tmp/lutcalc-h13-icc-tags-release-20260925.log`，SHA-256 为 `592c27a98ac2326ef1ee21a71c21792889038b2caea729c47c16ceedd2ab815e`。
- 发布入口仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出 2；ICC tag payload、显示/工作空间转换、整图显示、HDR/EDR、双端运行、真机和 Files 读回/取消仍未完成。Goal 保持 active。

## 2026-09-25 H13 ICC payload 补记

- ICC tag payload 只读摘要已接入：`text`、`desc`、`mluc` 分别按 ASCII、长度/NUL 和 UTF-16BE 约束解码；未知及采样型 payload 只记录 type、偏移和字节数，不保存等价采样表，也不执行颜色转换。payload 固定头至少 8 字节，真实 sRGB 三条共享 `curv` 范围继续允许。
- 先失败后通过的 `PreviewContractsTests` 为 7 项；最初崩溃是测试夹具的 `UInt32`→`UInt8` 非截断转换，已修正并补齐短头、畸形 UTF-16 契约。真实图像夹具 `LUTImageChecks` 退出码 0。
- 批量 Release 回归日志为 `/tmp/lutcalc-h13-icc-payload-release-20260925-rerun.log`，SHA-256 为 `3fce335b0059f62ebcf3f4573b27b705f2204d9fb47862f95feedc5018a7a8d1`；`swift test --list-tests` 为 160 项，旧 Node/Python、三平台 Release 构建和 App 包资源审计通过。发布入口退出码为 2，直接原因仍是缺少真实 `docs/native-validation/full-scope-acceptance.json`。
- 完整 ICC tag 类型覆盖、显示/工作空间转换、整图显示、HDR/EDR、双端运行、真机和 Files 独立读回/取消仍未完成；Goal 保持 active。后续继续按批量验证推进不依赖真机的工作包，连接不稳的真机项目最后集中执行。

## 2026-09-25 H13 ICC 固定点补记

- 在 `text`/`desc`/`mluc` 摘要基础上，新增 `XYZ ` 有符号 s15Fixed16 和 `sig ` 四字节签名的只读 metadata 摘要；摘要不参与任何矩阵、白点适应、曲线或显示转换。
- 先失败后通过的 Preview 定向 Release 契约为 9 项；真实 macOS sRGB 夹具的 `XYZ ` tag 和 `tech:sig ` (`CRT `) 摘要通过，`curv` 共享 payload 和既有逐码值结果不变。阶段详情见[H13 ICC 固定点记录](2026-09-25-h13-icc-fixed-point.md)。
- `curv`、`mft1`、`mft2`、`mAB`、`mBA` 等采样/处理 payload 仍 opaque；ICC 完整类型覆盖、显示/工作空间转换、整图显示、Core Image、HDR/EDR、真机和 Files 读回/取消仍未完成。Goal 保持 active。

## 2026-09-25 H13 ICC 固定点回归补记

- 固定点及 `mluc` 记录表边界阶段完整入口日志为 `/tmp/lutcalc-h13-icc-mluc-boundary-release-20260925.log`，SHA-256 为 `98614ded95b857a7cdae3693e9eed77a962f431e1a97132ec090e590af868a3c`；`swift test --list-tests` 为 163 项，Swift Release XCTest、旧 Node/Python、三平台 Release 构建和 App 包审计通过。
- 发布入口退出码 2，唯一直接原因仍是缺少真实 `docs/native-validation/full-scope-acceptance.json`。ICC 完整类型覆盖、显示/工作空间转换、整图显示、Core Image、HDR/EDR、真机和 Files 读回/取消保持未完成；Goal 继续 active。

## 2026-09-25 H13 PNG iCCP CRC 补记

- `SourceICCReader` 现在校验 `iCCP` chunk 的 PNG CRC-32；损坏 CRC 不再被当作有效源 profile。先失败后通过的 `LUTImageChecks` 损坏 CRC 契约和正常 sRGB/ICC metadata 检查均通过。
- 最新完整入口日志为 `/tmp/lutcalc-h13-icc-crc-release-20260925.log`，SHA-256 为 `6b51b1362368aa56a7602b0be3ecaec73dd6797e027eae6014535d599beacef5`；163 项 Swift Release XCTest、旧 Node/Python、三平台构建和 App 包审计通过，发布入口退出码 2，仍因缺少真实全量验收清单。
- 仅校验 iCCP chunk；其他 PNG chunk 的完整 CRC 审计、完整 ICC 类型覆盖、显示转换、整图显示、真机和 Files 读回/取消仍未完成，Goal 保持 active。

## 2026-09-25 H13 PNG 重复 iCCP 补记

- `SourceICCReader` 现在扫描完整 PNG chunk 序列：首个 `iCCP` 解压并完成 ICC 校验后暂存，第二个 `iCCP` 返回 `invalidPNG`。先失败后通过的真实嵌入 ICC 图像夹具契约见[重复 iCCP 阶段验收](2026-09-25-h13-icc-duplicate-iccp.md)，`verify-native-subset.sh` 退出码 0。
- 其他 PNG chunk CRC、完整 ICC tag 类型、显示/工作空间转换、整图显示、HDR/EDR、双端运行、真机和 Files 读回/取消仍未完成；Goal 保持 active。
- 重复 `iCCP` 接线后的完整 Release 回归为 165 项 Swift 测试，旧 Node/Python 契约、macOS/iOS Simulator/iOS generic Release 构建及 3 个 App 包资源审计通过；日志 `/tmp/lutcalc-h13-duplicate-iccp-release-20260925.log`，SHA-256 为 `9fe80a68a4804661b419b256744b4f7e13abc17ba670a3a65c5796a7ebab0ee2`。发布证据检查仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出码 2。

## 2026-09-25 H13 PNG 全 chunk CRC 补记

- `SourceICCReader` 现在对每个 PNG chunk 校验 CRC-32；损坏的非 ICC ancillary `tEXt`、损坏 `iCCP` 和重复 `iCCP` 均拒绝，正常 ImageIO 取样和 ICC metadata 摘要不变。阶段详情见[PNG 全 chunk CRC 阶段验收](2026-09-25-h13-png-all-crc.md)。
- 完整 Release 回归为 165 项 Swift 测试，三平台 Release 构建及 3 个 App 包资源审计通过；日志 `/tmp/lutcalc-h13-png-all-crc-release-20260925.log`，SHA-256 为 `838b6d208fb81774abdd4f739082936628533e241a3927d72c83078183fce325`。发布证据检查仍因缺少真实全量清单退出码 2；ICC 完整类型、显示转换、真机和 Files 读回/取消仍未完成。

## 2026-09-25 H13 ICC 固定结构 tag 非真机补记

- 在既有 `text`/`desc`/`mluc`/`XYZ `/`sig ` 只读摘要之上，新增 `curv` entry count、`chrm` 通道/色彩剂及 fixed-point 值、`para` function type/参数、`view` 六项 XYZ 与 illuminant word、`meas` backing/flare 与三个 word；实现依据 ICC 公开规范入口及本机 ExifTool `ICC_Profile.pm` 的固定偏移表，可追溯记录见[固定结构 tag 阶段验收](2026-09-25-h13-icc-fixed-structure-tags.md)。不保存曲线或 LUT 采样表，不做颜色转换。
- 先失败后通过的固定结构边界契约已加入；当前定向 `PreviewContractsTests` Release 为 12 项通过，真实 ImageIO 夹具 `LUTImageChecks` 退出码 0。定向日志 `/tmp/lutcalc-h13-icc-fixed-structure-release-20260925.log`，SHA-256 `5f81d64227e1bca71479221740ce43bfb1c19c172aae6c541b516f0c428bf4ca`。
- 本轮未运行全量发布门槛、未创建 `full-scope-acceptance.json`、未做真机工作；完整 ICC 类型覆盖、显示/工作空间转换、整图显示、HDR/EDR、双端运行、真机和 Files 读回/取消仍未完成，Goal 保持 active。

## 2026-09-25 H13 固定结构 tag 批次补记

- 在既有 ICC `text`/`desc`/`mluc`/`XYZ `/`sig ` 只读摘要基础上，新增 `curv` entry count、`chrm` 通道与 x/y 16.16 值、`para` function type/参数、`view` 六项 XYZ 与 illuminant word、`meas` backing/flare 与三个 word；不保存曲线或 LUT 采样表，不做颜色转换。
- 定向 `PreviewContractsTests` Release 12 项通过，真实 ImageIO 夹具 `LUTImageChecks` 退出 0。集中入口 `swift test --list-tests` 为 167 项，三平台 Release 构建与 App 包审计通过；日志 `/tmp/lutcalc-h13-fixed-structure-release-full.log`，SHA-256 `362db274dc63c2545ca436d83f4c26cb69a634d3649e4b2943ad6e82363534fb`。
- 发布证据检查仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出 2；未伪造清单。真机 Files 读回/取消、其他连接不稳项目继续按用户安排最后集中处理，Goal 保持 active。

## 2026-09-25 H13 ICC 标量 metadata 批次补记

- 在既有 ICC 固定结构只读摘要上，新增 `cicp` 四个 UInt8 code point、`dtim` 年月日时分秒六个 UInt16 和 `data` ASCII/binary flag 与 payload 字节数；`dtim` 额外拒绝实际不存在的公历日期，所有字段仍只用于 metadata 检查，不参与颜色转换或 LUT/曲线采样。
- 先失败后通过的定向 `PreviewContractsTests` 为 14 项，覆盖短 payload、2 月 30 日、非法 `data` flag 和未终止 ASCII；真实 ImageIO 夹具 `LUTImageChecks` 退出码 0。阶段详情见[H13 ICC 标量 metadata 阶段验收](2026-09-25-h13-icc-scalar-metadata.md)。
- 集中批量 Release 回归为 169 项 Swift 测试，旧 Node/Python 契约、33³/65³ 数值逐节点检查、macOS/iOS Simulator/iOS generic Release 构建和 3 个 App 包资源审计通过；日志 `/tmp/lutcalc-h13-dtim-release-full.log`，SHA-256 `3a9d366e05ab0f49867aa47d8448bc7f6b99b2d109bac66a505bb7158d8117c0`。
- 发布入口仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出 2；未伪造清单。完整 ICC 类型覆盖、显示/工作空间转换、整图显示、HDR/EDR、Files/File Provider、真机 SPI3D 生成/取回和取消仍未完成，Goal 保持 active。

## 2026-09-25 H13 ImageIO 灰度布局批次补记

- `PreviewImageDecoder` 现在接受 `.monochrome` ImageIO 色彩模型：灰度 8/16 位单通道复制到 RGB Double，灰度+alpha 保留独立 alpha，16 位大端/小端和预乘 alpha 边界保持显式；不做隐式色彩转换。阶段详情见[H13 ImageIO 灰度像素布局阶段验收](2026-09-25-h13-grayscale-layout.md)。
- 先失败后通过的真实灰度 PNG 夹具检查覆盖 8 位、16 位和灰度+alpha；`LUTImageChecks` 退出码 0，既有 RGB、ICC、TIFF、JPEG、方向、预算、CRC 和重复 `iCCP` 检查保持通过。
- 集中批量 Release 回归仍为 169 项 Swift 测试，旧 Node/Python 契约、33³/65³ 数值逐节点检查、macOS/iOS Simulator/iOS generic Release 构建和 3 个 App 包资源审计通过；日志 `/tmp/lutcalc-h13-grayscale-release-full.log`，SHA-256 `c1cae3b1566b08cc24c186242d0d57aae026115bb3eee6a2ec0b2e1d1f8d42b4`。
- 发布入口仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出 2；其他像素布局、完整 ICC/显示色彩管理、Files/File Provider 和真机 SPI3D 读回/取消仍未完成，Goal 保持 active。

## 2026-09-25 H13 ICC clro colorant order 批次补记

- 依据 ICC.1:2022 §10.4 接入 `clro` 的只读 count 与排列摘要，校验 payload 长度、正计数、索引范围和无重复；不保存 payload、曲线或 LUT 采样，不做颜色转换。阶段详情见[H13 ICC clro colorant order 阶段验收](2026-09-25-h13-icc-colorant-order.md)。
- 先失败后通过的 `PreviewContractsTests` 16 项，真实 ImageIO `LUTImageChecks` 通过。集中 Release 回归为 171 项 Swift 测试，旧 Node/Python、33³/65³ 数值逐节点检查、macOS/iOS Simulator/iOS generic Release 构建和 3 个 App 包资源审计通过；日志 `/tmp/lutcalc-h13-clro-release-full.log`，SHA-256 `fcb1b304e4c78a42470bdbecf4dfbcfad4a7b2716922610ab216858aa15da0d1`。
- 发布入口仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出 2；未伪造清单。`clro` 与 header 通道数的跨字段一致性、完整 ICC 类型、显示色彩管理、Files/File Provider 和真机读回/取消仍未完成，Goal 保持 active。

## 2026-09-25 H13 clro 通道数一致性补记

- 按 ICC.1:2022 §10.4 补充 `clro` count 与 profile header 设备色彩空间通道数的一致性检查。`GRAY`、三通道空间、`CMYK` 及 `2CLR`–`FCLR` 有确定通道数；带 `clro` 的未知空间保守拒绝。`5CLR` 五色合法，RGB 五色与 CMYK 三色拒绝，先失败后通过的定向 `PreviewContractsTests` 为 17 项。
- 最新完整 Release 回归为 172 项 Swift 测试，旧 Node/Python、33³/65³ 数值逐节点检查、macOS/iOS Simulator/iOS generic Release 构建及 3 个 App 包资源审计通过；日志 `/tmp/lutcalc-h13-clro-channel-release-full.log`，SHA-256 `b94b2bf1dc802cd91fab54b3833fcb5acdcaece2aed90cb7587c251069810834`。发布入口仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出 2，Goal 保持 active。

## 2026-09-25 H13 图像显示预览草稿补记

- `CPUPreview.renderDisplay` 新增独立显示路径：计划输出按显式 transfer、色域和范围解释回线性 sRGB，再以 W3C extended sRGB 编码；数值取样和导出结果不被显示 8 位夹取改写。`rec2100HLG` 在缺少 OOTF/峰值/参考白参数时明确拒绝。
- `ProjectSampleSession` 新增整图后台预览、取消和 documentID/revision/requestID/planVersion 门控；功能草稿新增“生成屏幕预览”按钮和目标/尺寸状态。阶段记录见[H13 图像显示预览草稿阶段验收](2026-09-25-h13-display-preview-draft.md)。
- 定向 `PreviewContractsTests` 19 项通过，`swift test --list-tests` 为 174 项，Swift Release 测试、LUTKit Release 构建及 macOS/iOS Simulator/iOS generic Release 构建通过。Core Image/Metal、HDR/EDR、完整 ICC/工作空间转换、真实位图、Files 和真机仍未完成，Goal 保持 active。

## 2026-09-25 H13 显示位图补记

- `DisplayPreviewBitmap` 仅在显示边界量化为 RGBA8，并显式用 sRGB `CGColorSpace` 建立 `CGImage`；SwiftUI 功能草稿显示图像。Double 数值取样与导出不经过该位图。
- 固定字节定向 Release 契约通过，详情见[H13 sRGB 显示位图阶段验收](2026-09-25-h13-display-bitmap.md)。集中 Swift Release 回归 175 项及 macOS/iOS Simulator/iOS generic Release 构建通过；三个 App 包资源审计通过；发布门槛因真实全量验收清单缺失退出 2，Goal 保持 active。

## 2026-09-25 H13/H12 合并回归补记

- 三个平台 Release 构建和三个 App 包资源审计通过；完整发布入口退出码 2，原因仍是缺少真实 `docs/native-validation/full-scope-acceptance.json`，日志 `/tmp/lutcalc-after-h13-bitmap-h12-release-gate.log`，SHA-256 `d3d234c25587ce930e74703ac2c71631ea24560c45896a314aba4671f750521e`。Goal 保持 active。

## 2026-09-25 H13 后台显示位图命令行补记

- `LUTDocumentSampleChecks` 现在实际加载 ImageIO 夹具、启动后台整图预览，等待 `DisplayPreviewBitmap` 完成并检查 2×1 RGBA8 和 `CGImage` 创建；`verify-native-subset.sh` 退出码 0。
- 日志 `/tmp/lutcalc-h13-display-h12-subset.log`，SHA-256 `c6adfc4c1f5aedfb872cbdf32afba15b2967aa2a6b48ad1191673cd10d022fe8`。这仍是原生子集证据，不替代真机、完整色彩管理或发布验收。

## 2026-09-25 H13 显示位图 alpha 补记

- 新增 premultiplied alpha RGBA8 固定字节契约；一次预期舍入差异已按实际最近偶数规则修正，定向 21 项通过。
- 合并全包 Swift Release 回归为 179 项，日志 `/tmp/lutcalc-after-premul-full.log`，SHA-256 `22d1b014983ef624a8c871d66aafe128fc367eee5675b9f2688653f77da0f99e`。Goal 保持 active。

## 2026-09-25 H13 显示源解释门控补记

- “生成屏幕预览”现在要求用户先确认当前项目输入曲线与色域；未确认只返回失败状态，不创建后台渲染或 RGBA8 位图。真实 ImageIO 夹具与 `LUTDocumentSampleChecks` 通过，日志见[H13 sRGB 显示位图阶段验收](2026-09-25-h13-display-bitmap.md)。
- macOS、iOS Simulator、iOS generic Release 构建均通过；真机、完整色彩管理与发布清单仍未完成，Goal 保持 active。

## 2026-09-25 H11 Rec.2100 PQ 补记

- 纯 Swift `PQTransfer` 已按公开 ST 2084/BT.2100 常数接入归一化绝对亮度 Double 编解码，10/12-bit 码值批次、边界和同空间计划契约通过；显示峰值、OOTF 与 HDR/EDR 仍未推断。阶段记录见[H11 PQ 阶段验收](2026-09-25-h11-pq-transfer.md)。
- 合并 Release 回归中的 Swift 测试、批量数值检查、三平台构建和 App 包审计通过；发布入口仍只因缺少真实全量清单退出码 2，Goal 保持 active。
- 显示预览对 PQ 与 HLG 一样要求后续 HDR 显示参数；缺少参数时拒绝，不隐式映射为 sRGB。完整 HDR/EDR 和真机显示仍未完成。

## 2026-09-25 H13 ICC rendering intent 补记

- ICC profile header 的 offset 64 rendering intent 现按大端 UInt32 严格读取，仅接受 0–3；未知值拒绝，摘要不参与显示或 LUT 计算。定向 `PreviewContractsTests` 通过，详情见[H13 ICC rendering intent 头部元数据阶段验收](2026-09-25-h13-icc-rendering-intent.md)。
- 该项不等于完整 ICC 类型覆盖、工作空间/显示转换、Core Image/Metal、HDR/EDR、真机或发布完成；H13 继续不勾选。

## 2026-09-25 H13 rendering intent 后完整回归补记

- ICC rendering intent 接线后，`swift test --list-tests` 为 **206 项**；Swift Release XCTest 通过，公开 NCP 实样因未设置路径按设计跳过 1 项。
- 6 个批量公式检查、36 对 33³/65³ CUBE 生成与独立读回、macOS/iOS Simulator/iOS generic Release 构建及 3 个 App 包资源审计通过。
- 最新完整入口日志为 `/tmp/lutcalc-h13-rendering-intent-release-20260925.log`，SHA-256 为 `b41d7d356ef351050394ef2ed74bd52f13054a506c3fb4887db3753306264d5c`；发布证据检查仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出码 2，Goal 保持 active。

## 2026-09-25 H08/H12 合并完整回归补记

- 日志 `/tmp/lutcalc-after-h08-h12clip-release-20260925.log`，SHA-256 `e0828fe76a523e761648542810f309c58d447ba8531149d163ce65dc32df42c5`。入口退出码 2 的唯一直接原因仍是缺少真实全量验收清单；未伪造清单。
- 本轮没有新增真机动作；File Provider/iCloud、系统分享保存提交、真机取消、完整 H12/FULL-08 与发布条件仍保持未完成。

## 2026-09-25 H11 简单 Conventional Gamma 批次补记

- 旧 `js/gamma.js:LUTGammaGam` 的简单“Linear / γ”公式已以纯 Swift `Double` 接入 γ1.5–γ2.6 共 12 条稳定曲线，含来源、别名、输入输出计划和 legacy 0.2 灰标度；不引入采样表或旧资源。阶段记录见[H11 简单 Conventional Gamma 批次验收](2026-09-25-h11-conventional-gamma-stage.md)。
- 定向 4 项公式契约和 1 项注册表契约通过；`swift test --list-tests` 为 222 项。完整 Release 验证的三平台构建、批量数值检查和 App 资源审计通过；发布入口仍因缺少真实 `full-scope-acceptance.json` 退出 2。
- ProPhoto 与 BBC 0.4/0.5/0.6 的解析式和同空间最小计划已通过阶段契约，详情见[H11 ProPhoto 与 BBC 验收](2026-09-25-h11-prophoto-bbc-stage.md)。通用参数化 Gamma、ProPhoto 完整 D50↔D65 工作流、HDR/OOTF、相机范围、真机运行、第三方往返、原生项目 Files/File Provider 和发布验收仍未完成，真机按用户安排最后集中处理，Goal 保持 active。

## 2026-09-25 范围决议补记

- 用户决定不再支持任何旧 App 单文件 JSON 设置迁移；读取、识别、候选映射、无损转换及对应契约均已删除。
- 原生 `.lutcalc` 只接受自身 schema；旧 `version`/`lutBox`/`gammaBox` 结构必须拒绝。该决定已从 Goal、H12 与 FULL-08 待办中移除。
- 原生 Files/File Provider、真机和发布条件仍未完成，Goal 保持 active。详见[范围移除验收](2026-09-25-h12-legacy-app-import-removed.md)。

## 2026-09-25 H04/H08/H12 范围收紧与批量回归

- H04 NCP `0100` writer 保持明确拒绝；H08 本地目标父目录、权限和文件身份竞争边界已通过定向契约。NCP 公开实样按设计跳过，未伪造厂商导出或设备兼容性。
- H12 原生 schema v1 的资源角色猜测/升级路径已删除；schema v1、缺少显式 `assetRoles` 和按文件名推断角色均拒绝。当前用户 LUT 只来自当前 schema 的显式 `.userLUT` 角色。
- 原生子集批量回归通过，日志 `/tmp/lutcalc-after-no-legacy-h04-h08-subset-20260925.log`，SHA-256 `95e58c6d3e389b44beddc40b18702ba6f98a91a79e37e35893b988b89ac39b95`。该结果不替代真机、完整平台交互或发布验收，Goal 保持 active。
- 范围收紧后的完整 Swift Release、macOS/iOS Simulator/iOS generic Release 构建及 3 个 App 包资源审计均通过；日志 `/tmp/lutcalc-no-old-app-migration-release-20260925.log`，SHA-256 `ceb2c4ff240dd1a061be2c82ef426614694f6bdd0bdb8c26cea4b61c2c0e9260`。发布入口仍因缺少真实 `full-scope-acceptance.json` 退出码 2。

## 2026-09-25 H12 范围记录校正

- 上述范围收紧记录曾把原生 schema v1→v2 兼容误写为删除；经定向回归确认，原生项目内部兼容继续保留：schema v1 按既定规则恢复 `legacyUserLUT`/`other` 角色并升级到当前 schema，schema v2 仍要求显式 `assetRoles`。
- 真正删除的只有旧网页 App 单文件 JSON 设置迁移；`version`/`lutBox`/`gammaBox` 结构交给 `ProjectCodec` 必须拒绝。`ProjectContractsTests` 与 `UserLUTProjectAssetContractsTests` 的三项定向测试均通过，日志 `/tmp/lutcalc-legacy-web-removal-native-compat-targeted.log`。

## 2026-09-25 H11 ProPhoto / ROMM 与 BBC 子集续接

- 已接入 ProPhoto / ROMM 的可追溯 16 倍低段/gamma 1.8 公式、RIMM-ROMM/D50 色域主色，以及 BBC 0.4/0.5/0.6 的旧 `LUTGammaBBCGam` 参数化 Double 分段和 data wrapper；注册、TransformPlan 和同空间最小计划已通过定向契约。
- 定向日志 `/tmp/lutcalc-prophoto-bbc-targeted-20260925.log`；LUTCore 5 项、LUTCatalog 1 项通过。详见[阶段记录](2026-09-25-h11-prophoto-bbc-stage.md)。
- 仍未完成：通用参数化 Gamma、CIE L*、BBC WHP283、HDR/OOTF、设备/相机范围、跨色域完整链、真机、Files/File Provider、第三方往返、完整 H11 和发布门槛；Goal 保持 active。

## 2026-09-25 H11 ProPhoto/BBC 批量读回补记

- `run-cube-batch.py` 已把 ProPhoto 与 BBC 同空间研发预设加入显式清单；当前批量验证为 20 个案例、40 个 33³/65³ 生成与独立读回对，默认 2 个受控 worker。ProPhoto 最大尺度化误差 `2.220446049250313e-16`，BBC 0.4 最大尺度化误差 `0`，均低于 `2e-12`。
- 子集入口退出码 0，日志 `/tmp/lutcalc-prophoto-bbc-batched-subset-20260925-rerun.log`，SHA-256 `f1d14d5d0c8f5b2113b39d2449f74948a4617471ea3b7e2b091cb732bdc19015`；Swift Release 全量回归为 205 项，日志 `/tmp/lutcalc-prophoto-bbc-full-swift-20260925.log`，SHA-256 `f05fc8ed8b177f9b9091f16528792fe09183c9c13f432c08ed798622a9ee5f0b`。
- 仍不代表完整 H11、跨色域 D50↔D65、HDR/OOTF、真机或发布门槛完成。

## 2026-09-25 旧 App 设置范围再次确认

- 用户确认删除旧 App 设置无损迁移功能，并从 Goal 目标中移除该项；当前原生应用不读取、识别、候选映射或导入旧 `version`/`lutBox`/`gammaBox` JSON。
- `ProjectContractsTests.testExternalLegacyAppSettingsAreRejected` 批量拒绝三种旧设置形状；原生 schema v1→v2 仅作为原生项目格式内部兼容保留。阶段记录见[H12 旧 App 设置迁移移除验收](2026-09-25-h12-legacy-app-import-removed.md)。
- 完整 Swift Release 与原生子集回归均通过；真机剩余工作、Files/File Provider、完整 H01–H14 和发布门槛仍未完成，Goal 保持 active。

## 2026-09-25 H11 通用参数化 Gamma 补记

- `ParameterizedGammaTransfer` 已以纯 Swift `Double` 接入，旧 `LUTGammaGam` 的固定 γ1.5–γ2.6 复用该核心；独立 `encodedCut` 保留分段边界语义。定向契约、完整 Swift Release 和原生子集回归均通过，详见[H11 通用参数化 Gamma 阶段验收](2026-09-25-h11-parameterized-gamma-stage.md)。
- 任意参数尚未进入 `TransformSettings` 持久化版式，CIE L* 固定注册、HDR/OOTF、真机、Files/File Provider 和发布仍未完成；Goal 保持 active。

## 2026-09-25 H11 CIE L* 补记

- 固定 CIE L* transfer、目录身份、同空间曝光预设和 CLI 已接入，切点采用 `216/24389` 与 `216/2700`，不把它当作完整 CIELAB 色彩空间。详情见[H11 CIE L* 固定曲线阶段验收](2026-09-25-h11-cie-lstar-stage.md)。
- 全包 Swift Release、原生子集和 21 案例/42 对 33³/65³ CUBE 独立读回通过；CIE L* 两种网格最大尺度化误差为 `0`。真机仍按用户安排最后集中，完整 H11 与发布门槛未完成，Goal 保持 active。

## 2026-09-26 CIE L* 平台回归补记

- 合并版本的 macOS、iOS Simulator、iOS generic Release 构建与三个 App 包资源审计均通过；完整入口日志 `/tmp/lutcalc-cie-lstar-release-20260925.log`，SHA-256 `5ee99d4305b1ba046bf44d14eb6b9c83e8ab194b115977828fd7038c95d7bb35`。
- 发布证据检查仍因缺少真实 `full-scope-acceptance.json` 退出 `2`；新增曲线真机验证按用户安排最后集中，Goal 保持 active。

## 2026-09-26 续接：CIELAB 前置契约

- 当前批次已完成 `XYZ64`、D50/D65 白点与纯 Swift XYZ↔CIELAB 分段数学契约；详情见[H11 CIELAB 前置契约阶段验收](2026-09-26-h11-cielab-prerequisite.md)。
- D50/D65 各 33³/65³ 独立 Decimal 参考共 621,124 个样本，最大绝对误差 `1.7763568394002505e-15`；全量 Swift Release 通过。
- 后续接入仍需先冻结非矩阵 Lab 色彩空间、a*/b* 量纲、白点适应和 `TransformPlan` 阶段语义；不得把本批称为完整 CIELAB 或完整迁移。真机继续按用户安排最后集中。

## 2026-09-26 续接：BBC WHP283 兼容批次

- 已接入旧 `js/gamma.js` `LUTGammaBBC283` 的 400%/800% 固定解析候选；阶段记录见[BBC WHP283 兼容阶段验收](2026-09-26-bbc-whp283-compatibility.md)。
- 两个条目各完成 33³/65³ 独立公式检查和批量 CUBE 读回，最大尺度化误差 `5.551115123125783e-17`。由于缺少独立 WHP283 资料归档，当前只声明旧解析兼容，不声明标准/设备/HDR 等价。
- 下一步继续按 H11/H04/H13 依赖推进；真机仍最后集中，Goal 保持 active。

- CIELAB/WHP283 合并 Release 回归为 220 项 Swift 测试，三平台 Release 构建与 App 包资源审计通过；发布入口仍因缺少真实全量验收清单退出码 2，不能作为发布通过证据。

## 2026-09-26 续接：CIELAB 非矩阵计划

- 在前置 XYZ↔Lab 数学契约之后，新增独立 `CIELABTransformPlan`：XYZ→Lab 为“XYZ 输入→白点适应→Lab 输出”，Lab→XYZ 为“Lab 输入→XYZ 解码→白点适应→XYZ 输出”；源白点、Lab 白点、目标白点、CAT、L* 与 a*/b* 量纲均显式保存。阶段详情见[H11 CIELAB 非矩阵计划阶段验收](2026-09-26-h11-cielab-plan-stage.md)。
- 先失败后通过的定向 Release 契约 5 项通过；独立 Bradford 非中性样本门槛 `2e-14`，D65→D50→D65 的 33³/65³ 网格往返最大绝对误差低于 `2e-12`。全量 Swift Release 为 225 项列出、1 项既有可选 NCP 实样按设计跳过，其余通过。
- 原生子集及 macOS、iOS Simulator、iOS generic Release 构建和三个 App 包资源审计通过。完整发布入口仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出码 2；未伪造清单。
- 本批仍不修改 RGB `TransformPlan`、`ColorSpaceID` 或原生项目 schema，不宣称完整 CIELAB、Delta E、显示色彩管理、HDR/EDR、真机、Files/File Provider 或完整迁移；真机继续最后集中。

## 2026-09-26 续接：RGB↔XYZ↔CIELAB 桥接计划

- 在独立 CIELAB 非矩阵计划之上新增 `CIELABRGBTransformPlan`；阶段顺序、白点声明校验、Lab 量纲和错误阶段均显式保留。详情见[H11 RGB↔XYZ↔CIELAB 桥接计划阶段验收](2026-09-26-h11-cielab-rgb-plan-stage.md)。
- `CIELABRGBPlanContractsTests` 先失败后通过共 5 项；sRGB D65→D50 的独立 Bradford 固定样本门槛 `2e-14`，33³/65³ RGB→Lab→RGB 往返门槛 `2e-12`。全量 Swift Release、原生子集、macOS/iOS Simulator/iOS generic Release 构建和三个 App 包审计通过。
- 本批没有把 Lab 加入 RGB `TransformPlan`、`ColorSpaceID` 或项目 schema，也没有恢复旧 App JSON 设置迁移。完整发布入口仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出码 2；完整 CIELAB、显示色彩管理、HDR/EDR、真机、Files/File Provider 和完整迁移继续未完成，Goal 保持 active。

## 2026-09-26 续接：H13 ICC RGB 矩阵/TRC CPU 子集

- 已新增独立 `ICCMatrixTRCTransform` 与阶段追踪；它只接受 ICC `RGB `/`XYZ ` 矩阵/TRC 子集，拒绝未支持的类型，不改变默认显示路径。阶段详情见[H13 ICC RGB 矩阵/TRC CPU 子集阶段验收](2026-09-26-h13-icc-matrix-trc.md)。
- `ICCMatrixTRCContractsTests` 先失败后通过 5 项；独立 Gamma/parametric 参考与 33³/65³ 往返门槛 `2e-12` 通过。全量 Swift Release 为 235 项列出，原生子集、macOS/iOS Simulator/iOS generic Release 构建和 App 包审计通过。
- 该批不等于完整 ICC、显示/工作空间转换、Core Image/Metal、HDR/EDR、真机或完整迁移；发布入口仍因缺少真实 `docs/native-validation/full-scope-acceptance.json` 退出码 2，未伪造清单，Goal 保持 active。

## 2026-09-26 续接：任意参数化 Gamma 项目持久化

- 本批先加入失败契约，确认 `ParameterizedGammaSettings`、稳定参数化曲线身份、项目设置槽位和错配错误均不存在；定向编译按预期失败后才实现。
- 新增纯 Swift `Double` 参数载体、`TransferID.parameterizedGamma`、`TransformSettings.inputGamma/outputGamma` 和 `TransformPlan` 参数化输入/输出接线。原生项目清单可保存/读回这些参数，缺少参数或错位附带参数明确拒绝；schema v1→v2 兼容与旧网页 App JSON 永久拒绝不变。
- 定向 `ParameterizedGammaContractsTests` 6 项、`ProjectContractsTests` 8 项和 `RegistryContractsTests` 16 项通过；全量 Swift Release 列出 238 项并通过，原生子集、macOS/iOS Simulator/iOS generic Release 构建和三个 App 包资源审计通过。完整入口仍因缺少真实 `full-scope-acceptance.json` 退出码 2，未伪造清单。
- 阶段记录见[H11 任意参数化 Gamma 持久化阶段验收](2026-09-26-h11-parameterized-gamma-persistence.md)。下一步继续处理可本地闭环的 H04/H08/H09/H12/H13 子段；HDR/OOTF、设备/真机、第三方软件和完整发布证据仍作为外部阻塞保留。

## 2026-09-26 续接：H13 ICC 参数曲线 type 1/2

- 在既有 ICC RGB matrix/TRC CPU 子集上先加入 type 1/2 独立参考失败契约；实现前定向测试按预期因 `unsupportedCurve("para:1")` 失败。
- `ICCMatrixTRCTransform` 现在以 Double 解析式支持 `para` type 1/2 及其逆函数；type 3 和其余未覆盖曲线继续拒绝，不引入采样表或隐式显示转换。阶段记录见[H13 ICC 参数曲线类型 1/2 CPU 阶段验收](2026-09-26-h13-icc-parametric-types-1-2.md)。
- 定向 ICC 契约 6 项通过；全量 Swift Release、原生子集、三平台 Release 构建和包审计需在本批最终源码上重跑后记录。完整 ICC/显示管理、真机和发布清单仍未完成。

## 2026-09-26 续接：H13 ICC 参数曲线 type 3

- 在 type 1/2 之后新增 `para` type 3 的失败契约；实现前因 `ICCProfileValidator` 仍按 5 参数读取而返回 `invalidProfile`，随后修正为规范 6 参数并接入 Swift `Double` 分段解析式与逆函数。
- `ICCMatrixTRCContractsTests` 7 项通过，新增 type 3 独立低段/高段样本及 33³/65³ 网格往返，最大绝对误差低于 `2e-12`；`LUTPreviewTests` 31 项通过，固定结构 metadata 夹具同步更新。
- 阶段记录见[H13 ICC 参数曲线类型 3 CPU 阶段验收](2026-09-26-h13-icc-parametric-type-3.md)。完整 ICC 类型、采样型 LUT、工作空间/显示转换、Core Image/Metal、HDR/EDR、真机、Files/File Provider 和真实发布清单仍未完成；不创建或伪造 `full-scope-acceptance.json`。
- 本批最终 Swift Release 为 240 项列出并通过（NCP 公开实样 1 项按设计跳过）；7 个批量公式检查、46 对 33³/65³ CUBE 读回、三平台 Release 构建和 App 审计通过。日志 `/tmp/lutcalc-h13-type3-native-release-20260926.log`，SHA-256 `38f3c794ad775cc014f49ac559dfe8d24abaa6f62a9206ade98a29fc62eb3b39`；发布入口仍仅因缺少真实全量清单退出 2。

# 2026-10-02 Final Output 非 UI 阶段验收

## 范围与身份

本工作包实现显式配置的阶段 19 格式边界与用户限幅，身份 `lutcalc.final-output-code-limits.v1`；schema 15 保存配置、算法版本、请求与撤销快照。UI 按用户要求暂缓，没有设备或系统界面操作。旧原生 schema 1–14 未设置本政策时保留既有输出范围路径；disabled 也保留该路径，不静默改写历史数值。

这是 FULL-04 的阶段子集。完整 HDR 自动峰值准备、相机／用户／格式限制的独立模型、裁剪计数、全部格式预设自动联动与旧 Null 等仍欠；H06/H12/H14、FULL-04 和全量迁移不因此完成，Goal **active**。

## 先行契约和实际失败

- `contract-red.log`：实际退出 1，所需 Final Output 类型未实现。
- `debug-core.log`：核心 2 项通过，实际退出 0。
- `storage-contract-red.log`：实际退出 1；核心 3 项通过，项目 1 项有 9 个失败断言、文稿后端 2 项有 1 个失败。schema 14 拒绝新字段、缺算法身份、旧 schema 直接 decoder 未拒绝偷带新配置。
- schema 15、严格字段／身份和文稿 gamma 编辑保留接入后，`debug-storage.log` 退出 0。
- 新增实际旧 17³ 组合链契约，`pipeline-contract-red.log` 退出 1，冻结参照尚未生成；生成后 `debug-verified.log` 退出 0。
- 首轮全包 `release-final.log` 退出 0；补相邻 Double 边界契约时 `release-confirmed.log` 退出 1，是 numeric literal 后直接访问成员的 Swift 语法错误。修为 `Double(0).nextDown` 等，不删断言或改变门槛。
- 最终源码 `debug-final.log` 退出 0，核心 4、项目 1、文稿后端 2，共 **7 项／0 失败**；`release-verified.log` 退出 0，全包 **457 项／0 失败／2 项既有可选夹具跳过**。原失败日志保留。

## 可追溯的定义与边界

来源为 `js/gamma.js:2355` 的实际 `finalOut`、`:5688` 附近的 clipSelect／clipLegal，以及 `js/lutformats.js` 的真实格式边界。旧源码哈希写入研发参照。`67025937=1023×65519` 是旧格式定义的码值约束，未从厂商 LUT 提取参数。

- 模式 none／both／blackOnly／whiteOnly；none 仍应用格式上下限。参数必须有限，允许反转边界，保留 `min(maximum,max(minimum,value))` 的旧顺序，反转时结果恒为 maximum。
- Legal 输出：下限 `(bClip−64)/876`，forceBlackLegal 时 0；上限 `(wClip−64)/876`。Data：下限 `bClip/1023`，forceBlackLegal 时 `64/1023`；上限 `wClip/1023`。
- 用户限幅启用时，在 Legal 输出或 clipLegal=false 条件下，按模式收紧到 0／1；否则 Data 收紧到 `64/1023`／**`959/1023`**，不能以 940 替代。即使设置项目 12-bit，这些 normalized 10-bit 定义不改写。
- 当前 carrier 先还原为 Legal IRE；Data 输出执行 `(value*876+64)/1023`，Legal 输出保持值，随后夹到准备的上下限。输出单位分别为 encodedData／encodedVideo。该阶段支持独立单通道 1D；其他耦合阶段的 1D 限制仍保持。
- HDR 无 Display 时，上限还需准备的 mxO；Data 使用旧 `mxO*.85630498533724+.06256109481916`。核心验证了显式 HDR 上下文，但计划的活跃 PQ／HLG 新政策缺完整峰值模型时抛出 hdrLimitUnavailable，不猜值。SDR Display 激活时按旧规则跳过该 cap，不能以此证明 HDR 显示变体完成。
- 准备值、输入、中间映射都必须有限。旧引擎可能把 Infinity 夹成有限值，原生明确拒绝用限幅隐藏溢出，任务定位 stage19 并 abort。相邻 Double 的 Legal 0／1 边界及 normalized 10-bit 与项目位深独立性均有断言。

## 独立和实际旧组合参照

`generate-final-output-legacy-reference.js` 执行真实 `LUTGamma.finalOut`：2 范围×4 模式×clipLegal×forceBlackLegal×5 格式边界×HDR 有无×Display 有无，共 **640 组／8,960 标量点**。含负值、超白、极大有限值和反转上下限。

`generate-final-output-independent-reference.py` 按闭式定义使用独立 70 位 Decimal，同样 640 组；另按 R 快／G 中／B 慢生成 Data／Legal 两种输出各 33³／65³ 的完整网格，域 `[-.5,2]`，共 **621,124 节点／1,863,372 通道**，并生成独立 1024 点导出轴。没有以旧函数输出作为独立预期。

`generate-final-output-legacy-pipeline.js` 实际执行旧 DLog2 解码→色域／曝光→False Colour 快照→CDL→Multitone→Highlight Gamut→SDR→Gamut Limiter→Knee→黑白电平→Black Gamma→SDR Display→次级 Gamut Limiter→False Colour 覆盖→Final Output。Linear／Post 两模式各完整 17³，Data 输出、both／clipLegal=true、格式 -1023／67025937。此次真实启用最终限幅，不复用此前关闭 clamp 的结果；仍是所选调节子链，不包括未实现的白平衡／PSST／HDR。

### 最终 Release 尺度化误差

定义 `abs(actual-reference)/max(1,abs(reference))`，门槛保持 `2e-12`。

| 集合 | 通道数 | 最大 | RMS | P99 |
| --- | ---: | ---: | ---: | ---: |
| 实际旧 finalOut | 8,960 | `0` | `0` | `0` |
| 独立 Decimal | 8,960 | `1.1102230246251565e-16` | `2.3575195654207416e-17` | `1.1102230246251565e-16` |
| 独立四个完整网格 | 1,863,372 | `0` | `0` | `0` |
| 旧 Linear 组合 17³ | 14,739 | `1.3530843112619095e-14` | `9.214221448207263e-16` | `4.718447854656915e-15` |
| 旧 Post 组合 17³ | 14,739 | `1.6764367671839864e-14` | `7.716526714755525e-16` | `3.3306690738754696e-15` |

False Colour 的 192 个 V8／Apple 离散边界差异继续独立保留；本次网格不证明逐位旧分类兼容。没有降低网格、位宽、插值或放宽阈值。

## 项目、程序化文件和任务

schema 15 严格接纳 finalOutput 键及嵌套字段；未知模式／算法／字段／身份错配拒绝，schema 1–14 偷带配置在 Codec 和直接 decoder 两入口拒绝。旧 schema 14 无政策明确迁移，既有输出单位身份保留。disabled 身份、settings helpers、文稿输入／输出参数化 gamma 编辑、不可变请求和撤销／重做保存配置。

FileWrapper 实际写磁盘并重开，EditorSession 独立打开，配置相同。实际导出 CUBE 的全 33³／107,811 通道和 SPI1D 的 1024 点／3,072 通道与独立参照比较通过。worker 1／4 全节点相等；极值域从 node0 在阶段 19 溢出，实际返回 stage19/sample0，sink aborted。此证据不替代 Files/Finder 或目标调色软件往返。

## 工具链、构建和归档

实际工具链：Xcode 27.0（27A266a）、Swift 6.4、macOS 27.0（26A428）arm64、Node 22.21.0、Python 3.14.6。原输出保存于本目录 artifact。

- 最终 7 项 Debug／457 项 Release，退出 0；Release 有 2 项既有可选夹具跳过。
- macOS／generic iOS／generic iOS Simulator 三平台未签名 Release 构建退出 0。
- 数值子集退出 0，包括新增三个参照生成器的重生成核对、旧组合两模式、既有 Node／Python／Swift 数值入口及批量生成读回。
- 源码边界和三个实际 App 包审计退出 0；静态审计不等于所有间接等价表及算法来源已人工闭合。
- 全量发布证据检查实际退出 **2**，真实 `full-scope-acceptance.json` 仍不存在，未创建清单、未运行完整发布入口、未签名发行。

实际命令／退出码、原失败和最终日志、机器结果、源码／参照／日志／三个 App 文件哈希保存于 [artifacts/2026-10-02-final-output](artifacts/2026-10-02-final-output/results.json)。研发 JS／Python 与二进制参照未进入 App 或 Swift Package 资源。

## 未覆盖范围与下一步

完整 HDR/OOTF／自动 mxO／4 个 HDR 显示变体、旧 Null、独立相机／用户／格式限制模型、裁剪统计、全部格式预设自动联动；完整旧曲线／空间／CAT／调节组合、白平衡／PSST 与其他来源阻塞；ICC、相机 ISO/EI、曝光批量、LUTAnalyst／格式、真实提供商故障、跨设备数值／性能、签名发布及安装升级仍欠。UI 暂缓，原最终范围不缩减。

可继续相机模型与曝光批量，以及有明确模型的格式／分析、文件故障恢复和 ICC/HDR。此阶段已归档，完整 Goal 保持 active。

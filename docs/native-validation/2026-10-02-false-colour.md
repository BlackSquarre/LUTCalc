# 2026-10-02 False Colour 非 UI 阶段验收

## 范围与版本

本工作包实现显式 LUT 导出的 False Colour：阶段 05 保存曝光后／白平衡与调节前的分类快照，阶段 18 在 Gamut Limiter 后替换标记颜色。原生算法身份为 `lutcalc.false-colour-native-thresholds.v1`，usage 为 `exportLUT`。没有新增 UI、预览叠层模式或设备交互；未知 `previewOverlay` usage 会拒绝，不能用预览开关暗中启用 LUT 导出。

该版本保留旧分类结构与调节顺序，但明确采用 Apple 系统 `pow` 的阈值舍入。在已冻结的 11,328 个旧边界探针中，有 **192 个分类与旧 V8 不同**，原因和原输入／旧结果全部保留。不能将它称为旧版逐位兼容；独立高精度参照支持本次阈值版本，差异不以容差掩盖。

FULL-04、H06/H12/H14 与全量发布仍未完成，Goal **active**。

## 先行契约与失败证据

- `contract-red.log` 保存最初编译失败：测试误写 Swift `.09`／`.7` 字面量。中断后进程 handle 已不存在，日志终态为 Build failed／fatalError，未补造该次退出码。修正字面量后，`contract-types-red.log` 实际退出 1，证明所需类型尚未实现。
- `debug-core.log` 实际退出 1，384 个断言失败对应 192 个离散探针的两种分类入口；并非可按 `2e-12` 忽略的连续误差。没有删除分段点或相邻 Double。
- 高精度参照与边界差异台账生成后，`debug-independent.log` 实际退出 0，核心 3 项通过。
- `storage-contract-red.log` 实际退出 1，证明 schema 13 未接纳新字段、缺算法身份、直接 decoder 仍接纳旧 schema 偷带新配置；文稿入口报 `unknownField("settings.falseColour")`。另一个极值契约的首个失败节点实际为 15，纠正夹具到真正从 node0 溢出的域，保持 1 worker，不假定并行调度顺序。
- schema 14、1D 预检和文稿后端保留接入后，`debug-verified.log` 实际退出 0：核心 4、项目 1、文稿后端 2，共 **7 项，0 失败**。随后增加未标记值的位精确保留与混合诊断单位，最终由全包 Release 验证。

## 可追溯的数值定义

来源为 `js/colourspace.js:1854` 的 `setFC`、`:1948` 附近的 `FCOut`、`:4478` 的实际顺序和 `js/gamma.js:2326` 的 `fcOut`；参数约束来自 `js/twk-fc.js` 的 testBlue／testYellow／testRed。所有旧源码哈希保存于实际执行夹具。

- 工作空间沿用 Sony S-Gamut3.cine／D65。Y 系数从公开原色／白点按旧余因子求逆的运算顺序推导，不复制采样表。其独立有理数参照也保存；分类入口明确区分 scene 与旧线性单位，scene 除以 0.9。
- 第 05 阶段不修改 RGB，只保存 band。第 18 阶段消费同一 band，不能用最终图像或调节后的 Y 重算。
- Purple 单独开启时阈值 `0.2*2^-8`；Blue 开启时会把该低端阈值改为 `0.2*2^-10`，Blue 上界为 `0.2*2^-blue`。即使 Purple 关闭，旧分类逻辑中仍有这个低端参与，不改写为直观的新区间算法。
- Green、Pink、Orange 的六个端点分别为旧定义的九位小数常数：`.174110113/.229739671`、`.354307008/.451585762`、`.885767519/1.128964405`。它们是告警区间定义参数，不是厂商 LUT 或等价采样表；不擅自改成更长的理想 stop 公式。
- Yellow 下界为 `0.2*2^(red-yellow)`；当 Red 关闭时，上界仍是旧 `0.2*2^5.95`。Red 开启才替换该上界。nil 参数保留 worker fallback：blue 6.1、yellow .26、red 5.95；通常新设置的显式默认仍是 6.1／.5／6，二者不能混同。
- 参数有限，blue≥1、yellow∈[.0001,3]、red≥3.5。blue／red 无人为上限；所选活跃阈值若溢出则 prepared kernel 明确失败。下溢到 0 保留。不把无上限当作无限精度保证。
- 按从小索引到大索引的首个 `Y<=threshold` 选择 band，并保留旧末端 Purple／Yellow／Red 的条件修正；全部开关关闭时配置仍保存但数值阶段不启用。
- Purple／Blue／Green／Pink／Orange／Yellow／Red 的 Legal RGB 为 `.75,0,.75`／`0,0,.75`／`0,.7,0`／`.75,.35,.35`／`.9,.45,0`／`.7,.7,0`／`.75,0,0`。这些是固定告警标签颜色，不能声称经过主输出色域的物理颜色转换。
- 覆盖时按当前输出 carrier 的 Legal scale／offset 包装，随后沿既有阶段 19 范围路径。未标记 band 原样保留 Double，避免一次无必要的 Legal 往返。trace 保存 band，阶段 18 后色域身份为 nil；未包装输出单位标为 `diagnosticPaletteMixed`，不把标签颜色冒充主空间线性 RGB。
- 3D 启用分类时必须进入工作空间，即使主输入／输出色域相同。1D 不支持三通道分类；请求构造及独立通道入口拒绝，不取灰轴伪装等价。关闭或全标记关闭不影响原有 1D 数值。

## 阈值舍入最小复现与独立裁决

`apple-threshold-minimal.log`、`v8-threshold-minimal.log` 和 `decimal-threshold-minimal.log` 分别记录实际 Swift、Node 及 80／120 位 Decimal。两种高精度的最终 Double 位型一致。

| 指数／阈值 | V8 | Apple／独立 Decimal |
| --- | --- | --- |
| `2^5.5*.2` | `9.050966799187808` | `9.05096679918781` |
| `2^3.5*.2` | `2.262741699796952` | `2.2627416997969525` |

Yellow 单独开启、blue=6.1／yellow=.5／red=6 时，旧 Y=`9.05096679918781` 被标 Yellow，原生版本为未标记；Red 单独开启、red=3.5 时，旧 Y=`2.2627416997969525` 被标 Red，原生为未标记。这是阈值导致的离散差异，不能用普通连续 RGB 容差称为等价。

`false-colour-boundary-audit.json` 保存全部 192 个差异：设置、原 RGB／Y、旧 band、原生 band、两套阈值和原生输出。核对采用独立 Decimal 阈值逐项生成的新预期，没有跳过旧边界。可证明本次参照集合的阈值舍入；没有据此声称所有任意实数 stop 在所有 Apple 平台都正确舍入。精确复现 V8 fdlibm 的旧边界行为尚未实现，不临时打包 JavaScript 或自有 C 核心来复现。

## 独立与旧组合链证据

- 旧 `setFC→FCOut→fcOut`：128 种开关组合×3 组参数（显式默认、nil fallback、边界参数），384 组、11,328 个探针；包含各阈值及其前后一个 Double。差异审计仍保留所有探针。
- 独立 `generate-false-colour-independent-reference.py`：70 位 Decimal 幂阈值、独立分段定义、有理数工作空间原色／白点 Y。两个配置（显式默认、全部颜色／nil fallback）的完整 33³／65³，域 `[-.5,16]`，共 621,124 节点、1,863,372 通道；每个节点的 band 单独逐项比较。11 种 band 都有实际节点，不只测灰轴或标记色。
- 旧 `generate-false-colour-legacy-pipeline.js`：DLog2 解码→色域／曝光→False Colour 快照→CDL→Multitone→Highlight Gamut→SDR→Gamut Limiter 阶段 12→Knee→黑白电平→Black Gamma→Display→Gamut Limiter 阶段 17→False Colour 覆盖→Data 输出。Linear／Post 两模式各完整 17³，非恒等设置与次级同时保护。最终旧 clamp 明确关闭，本证据不代替完整限幅政策。

### Release 实际尺度化误差

`abs(actual-reference)/max(1,abs(reference))`；门槛保持 `2e-12`。

| 集合 | 通道数 | 最大 | RMS | P99 |
| --- | ---: | ---: | ---: | ---: |
| 全部旧输入／独立阈值边界输出 | 33,984 | `0` | `0` | `0` |
| 独立四个完整网格 | 1,863,372 | `8.881784197001252e-16` | `8.295813971765099e-17` | `4.2739412677299257e-16` |
| 旧 Linear 组合链 17³ | 14,739 | `1.7263968032921184e-14` | `1.4205619289249583e-15` | `4.773959005888173e-15` |
| 旧 Post 组合链 17³ | 14,739 | `1.6764367671839864e-14` | `1.051487960191965e-15` | `3.6674285376928745e-15` |

第一行是**独立阈值的预期**，并非未修正的旧边界输出相等。组合网格未落入上述 192 个分歧输入，不据此忽略该离散兼容限制。

## 存储、文件与任务

schema 14 才允许 falseColour 字段；schema 1–13 缺失为 nil，既有单位／Display 身份保持。strict 字段、未知 usage／算法、身份错配与旧 schema 偷带字段拒绝；开关、nil 参数、disabled、版本、settings helper、gamma 后端编辑、请求快照和撤销／重做全部保留。

FileWrapper 实际写磁盘后重开，EditorSession 独立打开取得同一配置；实际 CUBE 全 33³ 节点与独立文件比较。SPI1D 在写文件前拒绝，目标不存在。worker 1／4 数值一致；极值域从 node0 溢出，实际返回 stage5/sample0，sink aborted。没有 Files、Finder、第三方软件或设备交互声明。

## 工具链与门槛

工具链实际输出已归档：Xcode 27.0（27A266a）、Swift 6.4、macOS 27.0 arm64、Node 22.21.0、Python 3.14.6。

- 全包 Release **450 项执行、0 失败、2 项既有可选夹具跳过**，退出 0。
- macOS／generic iOS／generic iOS Simulator 三个未签名 Release 构建退出 0。
- 源码边界和三个实际 App 包审计退出 0；这不能单独证明二进制没有等价采样表或完整来源闭合。
- 数值子集实际退出 0，包含新旧参照、独立全网格及 192 个边界差异台账的重生成一致性核对，并执行既有 Node／Python／Swift 与批量数值入口；终态见 `numeric-subset.log`。
- 全量发布证据检查实际退出 **2**，真实 `full-scope-acceptance.json` 不存在；没有创建或伪造清单，未运行完整发布入口。

实际命令、日志、阶段结果、源码／参照与 App 文件哈希保存到 `artifacts/2026-10-02-false-colour/`。研究夹具未进入 Swift Package 或 App 资源。

## 未覆盖范围

V8 特定位型阈值的逐位旧兼容、全部任意参数／设备运行；旧 Null／最终限幅政策，四个 HDR 显示变体和完整 HDR/OOTF／锚点依赖；完整旧曲线／空间／CAT／调节链；ICC、相机／曝光批量、LUTAnalyst／格式；真实提供商故障、性能、签名发布及安装升级仍欠。白平衡／PSST 来源、厂商风格、旧域外 tricubic、多解逆和 NCP 写出各自研究边界保留。UI 暂缓不缩减最终范围。

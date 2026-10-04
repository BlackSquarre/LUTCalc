# 2026-10-02 SDR Saturation 非 UI 阶段验收

## 交付与语义

接续[ASC-CDL](2026-10-02-asc-cdl.md)，新增原生 Double `SDRSaturationSettings` 与 prepared `LegacySDRSaturation`，算法身份 `lutcalc.sdr-saturation-output-linear.v1`。启用时接入 `TransformPlan` 阶段 11，位于输出色域之后、输出编码之前，使用输出原色 RGB→XYZ 的 Y 行。

这是旧 LUTCalc 的特定 SDR correction，不是 HLG OOTF、显示变换或通用 saturation 乘数。旧代码来源为 `js/colourspace.js:2169 SDRSatOut`、`setSDRSat`；用户参数来源为 `js/twk-sdrsat.js` 和 `js/lutcalc.js` 默认 `inputLim=true`。保留用户合法的 `gamma∈[1,2]`，不量化 gamma 到滑杆 step，不自动开启或改写输出曲线／色域。

输入 scene 值除以 `0.9` 适配旧线性单位。逐通道先除 12，非负值取 `1/gamma` 次幂，负值保留线性除法；计算 Y 后，`Y≤0` 原样保留输入。`Y>0` 时保留 Pb／Pr，令 Y 取 gamma 次幂，重建 RGB 并乘 12、乘 `0.9` 返回 scene。负值／HDR／超白不增加 clamp；溢出、非有限值明确失败并定位阶段 11／节点。

启用该耦合阶段的 1D 请求在写文件前返回 `lossyRepresentation`，不以灰轴冒充三通道结果。直接独立通道入口同样拒绝。disabled 配置保留无调节路径。

## schema 5 与存储

当前写出 schema 5，新增 `settings.sdrSaturation` 和算法版本身份。配置、不可变请求、磁盘 FileWrapper、EditorSession 快照、撤销／重做和普通参数修改均保留该字段；修改参数化 gamma 时也保留它。

原生 schema 1–4 按明确规则迁移：缺失新字段保持 `nil`，schema 4 的 CDL 保留，读取不改写源文件。新字段出现在旧 schema、未知嵌套键、未知算法、非法 gamma、算法版本错配均拒绝。旧 ASC-CDL 测试中的“当前版本”断言改用 `currentSchema`，旧 schema 4 夹具继续使用字面量验证真实兼容边界。旧 App 设置导入没有恢复。

## 契约过程

先写核心／存储契约，因类型和设置字段缺失编译退出 1，日志 `contract-red.log`。实现后 Debug 核心 4 项、存储 2 项通过。

新增磁盘项目与导出服务测试初次错误使用 `SPI1DFailure.kind`，编译退出 1；改为实际 `category` 后，Debug 8 项通过。随后增加实际旧流水线契约，缺失冻结夹具时真实退出 1（`pipeline-red.log`）；取得实际旧引擎输出后，最终定向 Debug **9 项、0 失败**（`debug-pipeline.log`）。中间失败日志全部保留。

最终全包 Release **387 项执行、0 失败、2 项既有可选夹具跳过**。跳过仍为旧 `.labin` 研发夹具和公开 NCP specimen。

## 数值证据

统一使用尺度化误差 `abs(actual−expected)/max(1,abs(expected))`，门槛保持 **`2e-12`**。RMS 对全部通道误差计算，P99 为升序数组的 `ceil(0.99*N)` 个样本；未降低网格、位宽或插值规则。

| 集合 | 通道数量 | 最大误差 | RMS | P99 |
| --- | --- | --- | --- | --- |
| 冻结旧 `SDRSatOut`，4 gamma × 73 点 | 876 | `5.329070518200751e-15` | `3.6901501379974334e-16` | `1.7754698967935704e-15` |
| 独立 Fraction 原色 Y 行／70 位 Decimal，4 gamma × 71 点 | 852 | `4.440892098500626e-16` | `1.1962833440685717e-16` | `3.82028964969136e-16` |
| 33³／65³ 独立 gamma=2 展开，scene 域 `[-0.5,21.6]³` | 931,686 | `7.216449660063518e-15` | `3.2451425962689393e-16` | `1.2212453270876722e-15` |
| 实际旧输入解码／色域／曝光／CDL／SDR 17³ | 14,739 | `2.777793995638905e-13` | `2.8416990708122165e-15` | `3.654818738085751e-15` |

独立数学参照消去 Pb／Pr，直接展开 `12*(q_i+Y^gamma−Y)`，不调用 Swift 或旧函数。全网格 gamma=2 用独立 sqrt／quadratic 和解析 Y 系数；保留负值和非正亮度分支。

旧流水线直接调用实际 `LUTGamma.inCalcRGB→LUTColourSpace.calc(g=true)`，D-Log2／D-Gamut2 Data 输入、曝光 +1、非中性 ASC-CDL、Rec.2020 输出色域、SDR gamma=1.2。冻结输出为旧颜色处理结果乘 `0.9`，明确对应 scene-linear 输出；它没有验证旧 HLG／BBC 最终编码或完整调节链。来源 SHA-256、4913 节点 Float64LE 二进制与 metadata 均保存。

其他契约：

- trace 顺序 `[1,2,3,4,8,10,11,13,19]`；CDL 后进入输出色域，再执行 SDR；另验证 HLG 在 SDR 之后编码。
- 33³ 用 1／4 worker、997 节点分块，输出数组完全相等。
- 程序化磁盘 schema 5 项目写入／重开、参数与快照保留；实际 CUBE 33³ 写出／解析和独立红轴参考点通过，负绿／蓝输出不被裁剪。
- 同一请求写 SPI1D 在文件创建前拒绝，目标不存在；disabled 的 1D 请求允许创建。
- 参数边界、全负值／黑色旁路、混合负输出、HDR 中性灰及极值溢出 stage 11／sample 17 诊断通过。

所有 Node／Python 脚本和冻结夹具仅供研发，不属于 App 资源。

## 实际命令、工具链和结果

Xcode 27.0（27A266a）、Swift 6.4、macOS 27.0 arm64、Node 22.21.0、Python 3.14.6。下列最终命令均退出 0，stdout／stderr 保存于[阶段证据目录](artifacts/2026-10-02-sdr-saturation/)：

```sh
swift test --package-path Native/Packages/LUTKit --filter SDRSaturation
swift test -c release --package-path Native/Packages/LUTKit
node tools/native-validation/generate-sdr-saturation-legacy-reference.js --check
python3 tools/native-validation/generate-sdr-saturation-independent-reference.py --check
node tools/native-validation/generate-sdr-saturation-legacy-pipeline.js --check
bash tools/native-validation/verify-native-subset.sh
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalcSDRSatMacOct2DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalcSDRSatIOSOct2DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalcSDRSatSimOct2DD CODE_SIGNING_ALLOWED=NO build
python3 tools/native-validation/audit-native-sources.py
python3 tools/native-validation/audit-native-bundles.py /tmp/LUTCalcSDRSatMacOct2DD/Build/Products/Release/LUTCalcMac.app /tmp/LUTCalcSDRSatIOSOct2DD/Build/Products/Release-iphoneos/LUTCalcIOS.app /tmp/LUTCalcSDRSatSimOct2DD/Build/Products/Release-iphonesimulator/LUTCalcIOS.app
```

三平台构建未签名，只证明编译；源码和实际包审计通过所列运行时／资源检查，不能证明二进制无任何等价采样表或全部来源已经闭合。本轮没有 UI 控件、桌面操作、真机或模拟器交互验收。

阶段机器结果为 `results.json`，源码／夹具哈希为 `source-sha256.txt`，日志哈希为 `logs-sha256.txt`。它们不替代全量发布清单。`check-release-evidence.py` 实际退出 **2**，缺少真实 `full-scope-acceptance.json`；未创建清单，未运行完整发布入口。

## 研究记录与未完成范围

白平衡检查发现旧 Kelvin／Duv／Dpl 路径依赖来源未闭合的 501 点 Planck 轨迹，已保存七个温度、五组参数和矩阵实际复现，见[研究记录](2026-10-02-white-balance-locus-research.md)。这不是证明任何连续物理算法都不存在；待明确旧生成模型和独立参照，产品未复制该表。

FULL-03 的白平衡、PSST-CDL、Multitone／自定义色域，FULL-04 的 Highlight Gamut、Knee、黑白电平、Black Gamma、显示转换、Gamut Limiter、False Colour 和完整辅助数据链仍未实现。SDR 的全部旧输出版本／组合、其他输出空间和跨设备数值／性能验收仍须补齐。完整 ICC、HDR/EDR/OOTF、相机／批量、LUTAnalyst、格式、提供商故障及签名发布继续未完成。

UI 按用户要求暂缓。H06/H12/H14、FULL-03／FULL-04 和全量验收不勾选，Goal 保持 **active**。

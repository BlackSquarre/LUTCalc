# 2026-10-02 H07/H14 旧 1D cubic 与组合 shaper 阶段验收

## 范围与实现

本轮接续 2026-10-01 的域内 tricubic，实现保留源码 `js/lut.js` 中 `LUTSpline` 的前向 1D cubic。入口为不可变、可跨任务传递的 `LegacyCubicCurve1D`，全部数值为 `Double`。沿用 `LUTInterpolation.tricubicLegacyV1` 选择旧三次规则；该枚举现在可取样独立 1D、独立 3D 和组合 CUBE 的 shaper→3D。

1D 至少 3 点，3D 每轴至少 4 点；不足时显式失败，不以线性替代。prepared sampler 为三个通道分别准备曲线，复用系数及 3D 幽灵网格。准备内存统一检查 64 MiB 上限，包含标量原值、四个系数和暂存斜率的保守预算及 3D 延拓网格；这是准备缓存的上限，不是进程总内存或性能验收。没有降低用户网格或精度。

组合 CUBE 保持现有语义：按每个 shaper 通道的输入域取样，再按 3D 的输入域取样。没有将非单位 3D 输入域改成旧 `LUTVolume.inSpline` 的共享单位域语义。分别用可表达的旧引擎合成案例和不等通道双域的独立仿射案例验证顺序。

## 端点、过冲与域外契约

对样本 `y[0…n−1]`，旧规则使用首端斜率 `−0.5*y[2]+2*y[1]−1.5*y[0]`、末端斜率 `0.5*y[n−3]−2*y[n−2]+1.5*y[n−1]`，内部斜率为中央差分。方向由最后与最初样本比较决定，平坦时选正方向。端点斜率为零或方向相反时替换成 `0.0075*direction/(n−1)`。分段使用原 cubic Hermite 系数及 Horner 运算顺序。

- 原样本保持不变；`LegacyCubicEndpointSlopes` 记录方向、原始与应用斜率、差值和是否修改。斜率单位是样本索引域。成功取样后原生界面显示实际修改，失败、新选择、清空及线性取样不会沿用旧报告。
- 不裁剪三次过冲。`[0,1,1,0]` 中段为 `1.125`；三个平坦样本也因旧端点替换产生 `0.37546875` 的独立预期值。
- 独立 1D 支持 `reject`、`clampToDomain` 和经本轮审计的线性端点外插 `legacyExtensionV1`。三种策略互不代替。
- `legacyExtensionV1` **仅完成 1D cubic 前向**。所有 3D 内核、组合 shaper→3D、现有线性 1D 均显式拒绝该策略，避免误将 clamp 算作延拓。旧 3D 红轴蓝通道导数索引冲突仍保持[研究阻塞](2026-10-01-legacy-tricubic.md)。
- shaper 产生 `1.125` 后，3D 单位域的 `reject` 必须失败；只有显式 `clampToDomain` 才得到边界值 `1`。不能先在 shaper 内裁剪过冲。

本轮没有实现 cubic 反求。既有反求按钮现明确显示“线性反求 1D 输入”，不把基于样本严格单调的线性反求解释为 cubic 单调或 cubic 逆。

## 参照与先行契约

核心、组合接线、会话斜率报告和准备预算契约先落盘，分别因缺失类型或报告字段编译失败；这些实际失败日志已保存。初次完成实现后的 Debug 有一项失败：测试错误地要求既有灰轴分析器接受 1D，抛出 `requiresThreeDimensionalLUT`。审查后保留灰轴的 3D 范围，把该项改为明确的拒绝契约，未为通过测试扩大灰轴语义。该失败日志也保留。

最终定向 Debug 共 15 项执行、0 失败，包含既有 4 项 tricubic 核心回归。最终全包 Release 共 **360 项执行、0 失败、2 项既有可选夹具跳过**；跳过的是旧 `.labin` 研发夹具与公开 NCP specimen，不能算已验收。

| 参照 | 覆盖与结果 |
| --- | --- |
| 冻结旧 1D 引擎 | 尺寸 3、5、17；递增、递减、交替非单调、平坦；域 `[-2,3]` 的端点、节点、内部及域外，共 220 点。最大尺度化误差 `0` |
| 冻结旧组合引擎 | 5 点共享 shaper→4³ 多项式网格，覆盖两端与内部，共 45 点。最大尺度化误差 `4.440892098500626e-16` |
| 独立参照 | 线性函数 `1−x`（含域外）、二次样本对应的端点修改分段值、`1.125` 过冲、平坦样本微小过冲、不等通道 shaper 域与非单位 3D 域的仿射取样；绝对误差不超过 `2e-12` |
| 既有数值子集 | 33³/65³ 独立 CUBE 全节点读回最大尺度化误差 `3.064215547965432e-14`，门槛仍为 `2e-12`；其余公式、图像、文稿与任务契约通过 |

误差定义沿用 `abs(actual−reference)/max(1,abs(reference))`，没有放宽门槛。冻结参照脚本 `tools/native-validation/generate-cubic1d-legacy-reference.js` 只在研发环境运行 Node VM，不进入产品依赖或 App 资源；`--check` 加入数值子集入口。合成 JSON 也不进入 App。原 `js/lut.js` 未修改，SHA-256 为 `359aabf3502eb38508bd0799d631475ecb9ad19a1af6297e95a01f1fd6f501c4`；新夹具 SHA-256 为 `02c5ebb5584174b710a75b88b2ec978e749f5793a0809c8245d869e2172bdc27`。

## 实际命令与结果

工具链：Xcode 27.0（27A266a）、Apple Swift 6.4、macOS arm64。工具链输出及全部日志保存在[证据目录](artifacts/2026-10-02-cubic1d/)。以下最终命令均退出 `0`：

```sh
node tools/native-validation/generate-cubic1d-legacy-reference.js --check
swift test --package-path Native/Packages/LUTKit --filter 'LegacyCubicCurve|LegacyTricubic|testCubicSampleReports'
swift test -c release --package-path Native/Packages/LUTKit
tools/native-validation/verify-native-subset.sh
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalcCubic1DMacOct2DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalcCubic1DIOSOct2DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalcCubic1DSimOct2DD CODE_SIGNING_ALLOWED=NO build
python3 tools/native-validation/audit-native-sources.py
python3 tools/native-validation/audit-native-bundles.py /tmp/LUTCalcCubic1DMacOct2DD/Build/Products/Release/LUTCalcMac.app /tmp/LUTCalcCubic1DIOSOct2DD/Build/Products/Release-iphoneos/LUTCalcIOS.app /tmp/LUTCalcCubic1DSimOct2DD/Build/Products/Release-iphonesimulator/LUTCalcIOS.app
```

三平台构建使用 `CODE_SIGNING_ALLOWED=NO`，只验收编译。实际 App 包未包含所列 LUT/脚本资源或 WebKit/JavaScriptCore 直接链接；这不能单独证明二进制内没有等价表或全部算法来源已验收。

| 最终日志 | SHA-256 |
| --- | --- |
| Debug 定向 | `9105d0c579526c0283d2661283d5277c5fcc8f93dab20b51a392a81fa5f077a7` |
| Release 全包 | `66e52ea4310adcf10fa3b326b1d39c6ea20bdc5f7c257184efc32849e09d468e` |
| 数值子集 | `fc5e3e09b06c36b409b8feb0b226bcaf7e7e9ae222b96338eb019d8ce08befe4` |
| 三平台最终构建，各为空日志 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| 三个实际 App 包审计 | `5cf8f49359d02d2b03d3b23d7fcc0f25b68815ca27754ee29b15de8522a24d2f` |

完整日志哈希清单为 `logs-sha256.txt`，本轮相关源码与夹具为 `source-sha256.txt`。Debug 定向在最后一处 Picker 显示绑定调整前运行；最终 Release 回归、三平台构建和包审计验证当前源码。

## 未覆盖与目标状态

尚未将本轮 cubic 选择接入不可变生成计划、项目持久化或导出链路；既有用户 1D 生成阶段保持原契约。本轮只完成取样、组合 shaper 接线和报告。cubic 的显式域／分支反求、旧 3D 域外冲突、完整 LUTAnalyst 分离与重建、任意 3D 逆、跨设备性能预算均未完成。

没有新增 Finder 直接双击、实体 iPhone 11、iPad 多窗口／旋转／无障碍、真实 File Provider 授权失效／替换竞争／后台恢复或目标调色软件往返证据。完整 ICC、HDR/EDR/OOTF、旧功能覆盖、发布签名及逐项发布验收仍未完成。本轮未复跑完整发布入口，也没有创建 `full-scope-acceptance.json`。H07/H10/H14、FULL-05 和全量平台／发布范围不勾选，Goal 保持 **active**。

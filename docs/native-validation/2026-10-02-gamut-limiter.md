# 2026-10-02 Gamut Limiter 非 UI 阶段验收

## 范围与来源

接续 Highlight Gamut，新增纯 Swift Double `lutcalc.gamut-limiter-chroma-span.v1`、阶段 12／17、不可变辅助样本、schema 11 和程序化项目／导出契约。UI 按用户要求继续暂缓，没有新增控件或系统界面操作。

来源为 `js/colourspace.js` 的 `setGamutLim/calcYCoeffs/gamutLimOut`、`js/gamma.js` 的 `gamutLimOut/outCalcRGB` 和 `js/twk-gamlim.js` 参数规则。产品使用原色／CAT 方程和 Foundation；Node/Python、旧 JS 与数值夹具仅用于研发，不进入 App。

参数和单位见[数值契约 2.1.8](../native-swift-numeric-contracts.md)。Linear 的阈值是 `2^stops`，旧参考白为 1，不能按其他调节习惯乘 `.2`。Post Gamma level 是 Legal IRE 通道跨度，不能解释为逐通道最大码值。

Linear 模式阶段 12 钳零后计算次级空间并压缩；Post Gamma 阶段 12 保存未经钳零的次级线性样本，阶段 17 才处理编码后数值。次级样本经过与主路径相同的 Knee／输出曲线、黑白电平和 Black Gamma。当前阶段 16 显示转换尚缺，因此此次证明不包含该依赖。零钳位属于明确版本化的旧 Limiter 算法，未增加任意末端 clamp；范围映射仍在阶段 19。

## 先行契约与实际失败

- `contract-red.log`、`debug-core.log`、`storage-red.log` 实际退出 1：契约中的 `.99` 不是合法 Swift 字面量，修正为 `0.99`。这些日志不能解释为已经证明缺少产品类型。
- `storage-contract-red.log` 实际退出 1：schema 仍为 10、`settings.gamutLimiter` 未被允许、算法版本与迁移规则缺失；随后补 schema 11、严格键和算法身份。
- `debug-storage.log` 和 `pipeline-red.log` 实际退出 1：独立全网格夹具尚未生成。失败保留后才生成独立参照，没有删掉依赖参照的断言。
- `debug-pipeline.log` 最终定向 **7 项、0 失败**；核心、项目及文稿后端分别为 4、1、2 项。文稿测试只执行 FileWrapper、EditorSession、磁盘读写与导出，不做 UI 验收。

没有改旧 JS、搬入内置采样表、降低网格、位宽或放宽 `2e-12`。

## 分项证据

- 实际旧引擎：Rec.2020／Rec.709 主空间×无次级／两种次级×Protect Both 两分支×两模式，共 24 组；每组 74 RGB 输入，加 6 组直接编码输入，合计 **5346 通道**。包括负域、纯色、超白、阈值及匹配输出空间不产生辅助样本。
- 独立参照：有理数原色矩阵和 **70 位 Decimal** 的跨度／亮度／压缩方程，24 组、每组 73 RGB 输入、**5256 通道**。参照独立求直接空间转换和 `level/span`，产品保留两步旧矩阵及 `/ratio`；参照不读取旧输出作为正确值。
- Linear／Post Gamma 各 **33³/65³**，完整输入域 `[−.5,2]³`，合计 621124 RGB 节点／**1863372 通道**。每个确切 Double 输入进入 Decimal；四个完整网格不抽灰轴、不删除负值节点。
- 两个实际旧 **17³** 子链：D-Log2 解码→输入色域／曝光→CDL→Multitone→Highlight Gamut→SDR→阶段 12→Knee／输出编码→黑白电平→Black Gamma→阶段 17。每链 **14739 通道**；分别启用 Linear 和 Post Gamma。旧末端 clamp 显式关闭，显示转换／False Colour 未启用，不推广为完整旧链证明。
- 阶段顺序、Data↔Legal 编码单位、参数边界、disabled、必要辅助值缺失、1D 拒绝通过。负主输出钳零与负次级保留分别验证。
- schema 11 严格存储、原生 schema 10 明确迁移、旧 schema 偷带新字段拒绝、未知键／算法身份错配拒绝、disabled 身份保留通过。全部 settings helper、文稿 gamma 后端编辑、撤销／重做和请求快照保留配置。
- FileWrapper 实际磁盘写重开、EditorSession、CUBE 写出／解析及 6 个非中性网格节点对独立 Decimal 核对通过。1D 导出写前拒绝，目标文件未产生。
- 1／4 worker 的 Post Gamma 33³ 数组完全相同。有限超大输入在阶段 12／17、节点 0 明确报错，指定 1 worker 验证 sink abort；不以调度顺序假设替代节点证据。

## Release 数值结果

尺度化误差为 `abs(actual−expected)/max(1,abs(expected))`，保持 `2e-12`。RMS 包括全部样本；P99 为升序 `ceil(.99*N)` 位置。

| 参照集合 | 通道数 | 最大误差 | RMS | P99 |
| --- | --- | --- | --- | --- |
| 旧 Linear 组合子链 17³ | 14739 | `3.114632751164745e-14` | `3.2588400161946067e-15` | `5.551115123125783e-15` |
| 旧 Post Gamma 组合子链 17³ | 14739 | `1.566524687746096e-13` | `2.891758972508718e-15` | `4.052314039881821e-15` |
| 实际旧标量／编码分支 | 5346 | `1.2212453270876722e-15` | `1.334126232364352e-16` | `4.330885763709254e-16` |
| 独立 Decimal | 5256 | `6.518909044799022e-16` | `9.235621961925367e-17` | `2.7755575615628914e-16` |
| 独立两模式 33³/65³ | 1863372 | `7.869036450598934e-16` | `8.480882031794601e-17` | `2.220446049250313e-16` |

完整 Swift Package Release **430 项执行、0 失败、2 项既有可选夹具跳过**（旧 `.labin` 研发夹具、公开 NCP specimen）。三平台未签名 Release 构建、源码和实际三个 App 包审计退出 0。数值子集也实际退出 0；终态在阶段结果中单独记录，不将构建当作设备运行。

## 命令、工具链和结果包

Xcode 27.0（27A266a）、Swift 6.4、macOS 27.0 arm64、Node 22.21.0、Python 3.14.6。真实命令、退出码、失败及最终日志、最大／RMS／P99和源码／夹具／日志／实际 App 文件哈希见[阶段目录](artifacts/2026-10-02-gamut-limiter/)。

```sh
swift test --package-path Native/Packages/LUTKit --filter GamutLimiter
swift test -c release --package-path Native/Packages/LUTKit
node tools/native-validation/generate-gamut-limiter-legacy-reference.js
node tools/native-validation/generate-gamut-limiter-legacy-pipeline.js --linear
node tools/native-validation/generate-gamut-limiter-legacy-pipeline.js
python3 tools/native-validation/generate-gamut-limiter-independent-reference.py
bash tools/native-validation/verify-native-subset.sh
python3 tools/native-validation/audit-native-sources.py
python3 tools/native-validation/check-release-evidence.py
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalcGamutLimiterMacOct2DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalcGamutLimiterIOSOct2DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalcGamutLimiterSimOct2DD CODE_SIGNING_ALLOWED=NO build
python3 tools/native-validation/audit-native-bundles.py /tmp/LUTCalcGamutLimiterMacOct2DD/Build/Products/Release/LUTCalcMac.app /tmp/LUTCalcGamutLimiterIOSOct2DD/Build/Products/Release-iphoneos/LUTCalcIOS.app /tmp/LUTCalcGamutLimiterSimOct2DD/Build/Products/Release-iphonesimulator/LUTCalcIOS.app
```

全量证据检查实际退出 **2**：真实 `full-scope-acceptance.json` 仍缺失，没有创建该文件。此次没有运行完整发布入口、真机、签名归档或安装升级。

## 未覆盖范围

当前次级空间限于原生 14 个矩阵空间、CAT02／Bradford；其他旧特殊／自定义空间、其他 CAT、全部参数组合及设备数值仍待验收。stage 16 显示转换加入后，须同时进入主／次级编码链再重验阶段 17；不能忽略这项依赖。

完整 False Colour、HDR/OOTF、全部旧输出版本与限幅政策、白平衡／PSST 来源、ICC、相机／批量、LUTAnalyst／格式、真实 File Provider 故障、性能和签名发布仍未完成。UI 暂缓，程序化文件证据不替代系统界面或目标调色软件往返。

App 包审计不证明所有间接等价表已人工检查。FULL-04、H06/H12/H14 不勾选，Goal 保持 **active**。

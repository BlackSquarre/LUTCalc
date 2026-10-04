# 2026-10-02 Black Gamma 非 UI 阶段验收

## 范围与算法来源

本工作包接入 Black Gamma 输出调节、原生参数和算法身份、不可变生成计划、schema 7 及程序化文稿／文件导出。没有改 UI 控件，用户的 UI 暂缓决议继续有效。

来源为仓库 `js/gamma.js` 的 `setBlkGam/getLumVals/blkGamOut`、`js/twk-blkgam.js` 和 `js/lutcalc.js` 的 `lutSlider.testData`。旧参数上下限是数值边界，不复制界面步长。产品只包含 Swift 解析公式；Node/Python/参照夹具属于研发，不进入 App。

阶段 15 位于输出编码之后、范围换算之前；逐通道独立，合法 1D 请求正常生成。阈值使用 scene 灰 0、`0.18*2^(upperStops−featherStops)` 和 `0.18*2^upperStops`，经过独立 CDL SOP 与输出编码后，用旧固定 0.2126/0.7152/0.0722 加权。不能换成工作空间 Y，也不把曝光、Multitone 或 SDR 加入准备。Knee 与黑白电平尚未实现，其准备依赖仍需后续扩展。

公式、零羽化、负值、折叠／反转阈值、正仿射编码单位转换与版本身份详见[数值契约](../native-swift-numeric-contracts.md)。同色域 1D 不应用 CDL 的 3D 饱和度；未把 3D 灰轴当作 1D 等价。

## 先行契约与实际失败

- 先写核心契约，缺类型／设置字段时 `contract-red.log` 实际退出 1。
- 实现后 `debug-stage.log` 退出 1，原因是新测试缺少 `try`；随后修复测试编译。
- `debug-anchor.log` 退出 1：旧 Legal 阈值与部分原生 Data 编码直接混用；JSONSerialization 数字读取还改变了少数锚点位模式，使敏感参数产生约 `3.02e-10` 偏差。修复研发单位换算，并用精确十进制字符串保留输入位模式；没有放宽阈值。`reference-before-bit-preservation.json` 保留原夹具，`json-binary-diagnostic.json` 保存实际相差 1–2 ULP 的字段。
- 文稿测试初版错误访问 SPI1D 模型字段，相关编译失败日志保留；改用实际 `SPI1DFile.lut.samples`。
- 旧完整可用子链参照未生成时，`pipeline-reference-red.log` 真实退出 1，包含缺文件错误；生成实际旧结果后通过。
- 增加相邻 IEEE754 边界后，`debug-boundary.log` 真实退出 1。最小次正规输入 `5e-324`、B=0、L=0.045、U=0.18、power=0.01，旧公式先做除法使比值丢失精度，独立 70 位 Decimal 误差为 `8.243197216572346e-8`。未删除该点，未缩域或放宽门槛。

## 有独立依据的稳定版本

保留旧运算身份 `lutcalc.black-gamma-output-encoded.v1`，全部冻结旧标量点仍逐项验证。新默认使用独立身份 `lutcalc.black-gamma-output-encoded-stable.v1`，只在次正规比值处采用等价连续公式的对数形式，power=1 精确保留输入。新旧版本均能保存；不把旧不准确行为与数学正确性混称。

失败点的旧结果为 `0.00010714992321968371`，稳定结果为 `0.00010706749124751814`，两者相差 `8.243197216557438e-8`。稳定结果由独立 Decimal 验证，误差约 `1.5e-19`。旧兼容版本在该点不能声称通过连续公式的 `2e-12` 门槛；契约明确要求该差异仍可复现。

## 已取得的定向证据

最终定向 Debug 7 项、0 失败。分别涵盖核心 4 项、项目 1 项和文稿后端 2 项；文稿测试是程序化存储／快照／导出，不是 UI 操作。

- 12 组实际旧阈值准备与 1032 标量点，含三条输出曲线、四组参数、相邻 IEEE754 边界。
- 20 组独立 70 位 Decimal／1640 点，包含 fractional power、负黑位、零羽化和相邻边界；精确输入先转 Decimal，不调用产品或旧算子。
- 33³／65³ 全部 310562 节点、931686 通道的独立二次参照，域为 `[−0.1,1.2]³`，未降网格。
- 实际旧解码／色域／曝光／CDL／Multitone／SDR／D-Log2 编码／Black Gamma 17³ 子链。研发明确关闭最终 clamp，仅验证本轮现有子链；缺失的输出阶段仍未验收。
- 1／4 worker 的 33³ 结果完全相同；写入失败使 sink aborted。
- schema 7 精确保存、原生 schema 6 迁移、新字段不允许出现在旧 schema、未知键／版本／非法参数拒绝；原配置保留。
- 真实本地 FileWrapper 磁盘写入和重开、EditorSession 请求快照、撤销／重做和参数化 gamma 编辑保留；CUBE／SPI1D 写出解析和独立参考点通过。

## 最终验证状态

定向 Debug **7 项、0 失败**；整包 Release **401 项执行、0 失败、2 项既有可选夹具跳过**。跳过为旧 `.labin` 研发夹具和公开 NCP specimen。数值子集、三平台未签名 Release 构建、源码及实际三个 App 包审计全部实际退出 0。没有进行设备运行或完整发布入口。

尺度化误差为 `abs(actual−expected)/max(1,abs(expected))`，门槛保持 `2e-12`；RMS 对全部样本计算，P99 为升序数组 `ceil(0.99*N)` 位置。

| Release 参照 | 样本数 | 最大误差 | RMS | P99 |
| --- | --- | --- | --- | --- |
| legacy full available chain 17³ | 14739 | `5.667589683178308e-13` | `6.5257142309178445e-15` | `4.338552158076834e-15` |
| independent 33³/65³ | 931686 | `1.3877787807814457e-17` | `1.8153353318921918e-18` | `1.3877787807814457e-17` |
| black-gamma-legacy-reference.json | 1032 | `5.551115123125783e-17` | `2.368770581004165e-18` | `2.710505431213761e-20` |
| black-gamma-independent-reference.json | 1640 | `1.1102230246251565e-16` | `1.4683849980575076e-17` | `5.551115123125783e-17` |

旧标量行使用保留旧运算版本；独立 Decimal 和完整可用子链行使用稳定版本。两版本在次正规边界的差异单独验证并保留，不用总体统计掩盖旧兼容版本的数学误差。

## 实际命令、工具链与结果包

工具链：Xcode 27.0（27A266a）、Swift 6.4、macOS 27.0 arm64、Node 22.21.0、Python 3.14.6。日志／JSON／原失败夹具位于[阶段目录](artifacts/2026-10-02-black-gamma/)。最终命令如下（实际失败轮次的退出码分别在前文列明）：

```sh
swift test --package-path Native/Packages/LUTKit --filter BlackGamma
swift test -c release --package-path Native/Packages/LUTKit
node tools/native-validation/generate-black-gamma-legacy-reference.js
node tools/native-validation/generate-black-gamma-legacy-reference.js --check
node tools/native-validation/generate-black-gamma-legacy-pipeline.js
node tools/native-validation/generate-black-gamma-legacy-pipeline.js --check
python3 tools/native-validation/generate-black-gamma-independent-reference.py
python3 tools/native-validation/generate-black-gamma-independent-reference.py --check
swift tools/native-validation/inspect-black-gamma-json.swift
bash tools/native-validation/verify-native-subset.sh
python3 tools/native-validation/audit-native-sources.py
python3 tools/native-validation/check-release-evidence.py
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalcBlackGammaMacOct2DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalcBlackGammaIOSOct2DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalcBlackGammaSimOct2DD CODE_SIGNING_ALLOWED=NO build
python3 tools/native-validation/audit-native-bundles.py /tmp/LUTCalcBlackGammaMacOct2DD/Build/Products/Release/LUTCalcMac.app /tmp/LUTCalcBlackGammaIOSOct2DD/Build/Products/Release-iphoneos/LUTCalcIOS.app /tmp/LUTCalcBlackGammaSimOct2DD/Build/Products/Release-iphonesimulator/LUTCalcIOS.app
```

`check-release-evidence.py` 实际退出 **2**，原因是缺少真实全量发布验收清单；其他最终检查和构建退出 0。未创建 `full-scope-acceptance.json`。三平台构建未签名，只验收编译；源码／包审计不代替间接采样依赖与全部来源的人工审计。

`results.json` 为本工作包结果，不是全量清单。`source-sha256.txt`、`logs-sha256.txt`、`build-products-sha256.txt` 保存本轮源码／参照／日志与实际 App 文件哈希；完整终态命令也保存在结果 JSON 中。测试生成的本地文稿和导出文件在临时目录按测试清理，重开与写读行为由真实测试结果记录，不冒充 Finder/Files 交互。


## 未覆盖范围

完整 Knee／黑白电平准备依赖、全部曲线／参数／调节组合、其他 CAT、跨设备数值与性能、完整 ICC/HDR、相机／批量、LUTAnalyst 与格式、真实提供商故障和签名发布仍未完成。UI 继续暂缓。真实 `full-scope-acceptance.json` 仍不存在，不能据本阶段勾选 FULL-04／H06/H12/H14，Goal 保持 **active**。

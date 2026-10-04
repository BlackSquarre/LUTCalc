# 2026-10-02 黑白电平非 UI 阶段验收

## 范围与来源

接续已验证的 ASC-CDL、Multitone、SDR 与 Black Gamma，新增黑白电平阶段 14、默认值／锁定参数纯函数规则、schema 8、不可变生成请求、程序化文稿保存与 CUBE/SPI1D 写读。没有新增 UI 控件，用户的 UI 暂缓决议继续有效。

来源为 `js/gamma.js` 的 `setBlkHi/getLumVals/blkHiOut/setBlkGam`、`js/twk-blkhi.js` 的单位换算／输入有效域，以及旧参数更新标志。产品只使用 Swift Double 与系统框架；旧引擎、Node/Python、冻结参照均属研发，不进入 App。

黑位和高光映射使用 Legal IRE；参考白是 scene reflectance，默认 0.9。默认值经过独立 CDL SOP 与输出编码，再按旧固定亮度系数加权。逐通道仿射映射在编码后执行，允许负／零斜率，不末端 clamp。normalized Data code 的参数先换到同一单位；1D 保持独立通道语义。

未锁定映射在输出曲线／CDL／HDR 变化时恢复自动默认值；参考白变化只重置高光。模型以 nil 表示自动，生成计划不依赖全局改动标志。输出曲线和 CDL helper、文稿输出 gamma 参数更新已接线；输入或输出色域本身、曝光与 CDL 饱和度不会单独重置。尚未实现的完整 HDR 参数更新仍不能计为通过。

黑白电平准备完成后，还映射 Black Gamma 的黑位、羽化下限与上限，保留阶段 13→14→15→19 顺序。Knee 的准备依赖仍待补齐。数值／参数契约见[数值契约](../native-swift-numeric-contracts.md)。

## 先行契约及真实失败

- 核心契约先写入，缺类型／设置字段时 `contract-red.log` 实际退出 1。
- `debug-stage.log` 实际退出 1，Swift 编译发现初始化期间嵌套函数捕获尚未完成初始化的 self；改为捕获已准备的局部不可变布尔值。
- `pipeline-red.log` 实际退出 1，原因是实际旧组合链冻结文件尚不存在；生成实际旧结果后通过。
- `debug-pipeline.log` 定向 **7 项、0 失败**：核心 4 项、项目 1 项、文稿后端 2 项。文稿后端测试不属于界面操作证据。

没有放宽 `2e-12`，没有降低网格或位深。未使用厂商采样表，也未修改旧 JavaScript 源码。

## 已取得的分项证据

- 旧实际 `setBlkHi/blkHiOut`：4 条输出曲线 × 6 组参数，1776 标量点；默认、单端、双端、负斜率、参考白变化均覆盖。32 组输出／CDL／HDR／参考白变化与锁定开关复现值逐项核对。
- 独立 70 位 Decimal：5 组映射、370 点，确切二进制输入转 Decimal；不同黑白默认值、负斜率、零斜率与超白均覆盖。
- 独立仿射 33³／65³：全部 310562 节点、931686 通道，域 `[−0.5,2]³`；不降网格。
- 实际旧解码／色域／曝光／非中性 CDL／Multitone／SDR／D-Log2 编码／黑白电平／Black Gamma 17³ 子链。研发明确关闭最后 clamp；不据此声称完整输出限幅或全部旧处理链已经通过。
- 阶段 14→15 的阈值联动、范围映射顺序、1D 独立语义、部分 log／ACESproxy 与 canonical HDR 曲线的参数单位核对通过；不等于完整 HDR/OOTF 验收。
- schema 8 保存与原生 schema 7 迁移；原参数保留，旧 schema 不允许新配置，未知键／版本错配拒绝。disabled 也记录版本。
- 本地 FileWrapper 实际磁盘写入／重开、EditorSession 快照、撤销／重做、锁定／未锁定输出 gamma 编辑语义通过。CUBE/SPI1D 真实写出／解析及独立节点检查通过；1／4 worker 33³ 输出完全相同。
- 真实有限输入的乘法溢出定位阶段 14／节点 0，1 worker 任务 abort；不留下可提交的部分 sink。

## 最终验证状态

定向 Debug **7 项、0 失败**；整包 Release **408 项执行、0 失败、2 项既有可选夹具跳过**。跳过为旧 `.labin` 研发夹具和公开 NCP specimen。数值子集、三平台未签名 Release 构建、源码与实际三个 App 包审计均实际退出 **0**。没有执行设备运行或完整发布入口。

尺度化误差为 `abs(actual−expected)/max(1,abs(expected))`，门槛保持 `2e-12`；RMS 对全部样本计算，P99 为升序数组 `ceil(0.99*N)` 位置。

| Release 参照 | 样本数 | 最大误差 | RMS | P99 |
| --- | --- | --- | --- | --- |
| legacy available combined chain 17³ | 14739 | `5.666367386078412e-13` | `6.7614987253345695e-15` | `5.131923122853552e-15` |
| independent 33³/65³ | 931686 | `3.397919565271468e-16` | `1.336456930643904e-16` | `3.397919565271468e-16` |
| black-highlight-legacy-reference.json | 1776 | `0.0` | `0.0` | `0.0` |
| black-highlight-independent-reference.json | 370 | `2.2135287718383183e-16` | `4.499123771510717e-17` | `1.9726339138259303e-16` |

## 实际命令、工具链和结果包

工具链为 Xcode 27.0（27A266a）、Swift 6.4、macOS 27.0 arm64、Node 22.21.0、Python 3.14.6。实际日志位于[阶段目录](artifacts/2026-10-02-black-highlight/)。最终成功轮次及证据检查命令如下；前述失败轮次均保留原日志。

```sh
swift test --package-path Native/Packages/LUTKit --filter BlackHighlight
swift test -c release --package-path Native/Packages/LUTKit
node tools/native-validation/generate-black-highlight-legacy-reference.js
node tools/native-validation/generate-black-highlight-legacy-reference.js --check
node tools/native-validation/generate-black-highlight-legacy-pipeline.js
node tools/native-validation/generate-black-highlight-legacy-pipeline.js --check
python3 tools/native-validation/generate-black-highlight-independent-reference.py
python3 tools/native-validation/generate-black-highlight-independent-reference.py --check
bash tools/native-validation/verify-native-subset.sh
python3 tools/native-validation/audit-native-sources.py
python3 tools/native-validation/check-release-evidence.py
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalcBlackHighlightMacOct2DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalcBlackHighlightIOSOct2DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalcBlackHighlightSimOct2DD CODE_SIGNING_ALLOWED=NO build
python3 tools/native-validation/audit-native-bundles.py /tmp/LUTCalcBlackHighlightMacOct2DD/Build/Products/Release/LUTCalcMac.app /tmp/LUTCalcBlackHighlightIOSOct2DD/Build/Products/Release-iphoneos/LUTCalcIOS.app /tmp/LUTCalcBlackHighlightSimOct2DD/Build/Products/Release-iphonesimulator/LUTCalcIOS.app
```

`check-release-evidence.py` 实际退出 **2**：真实 `full-scope-acceptance.json` 仍缺失。其他最终测试／检查／构建退出 0。没有创建全量清单，没有把未签名编译当作签名发行或设备运行。

`results.json` 是本工作包结果，明确列出未覆盖项。`source-sha256.txt`、`logs-sha256.txt`、`build-products-sha256.txt` 保存源码／参照／日志与实际 App 文件哈希；原生源码／包资源审计不能替代完整来源和间接采样依赖人工审计。测试中的本地文件写读已实际运行，但临时文件按测试清理，不冒充 Finder/Files 操作证据。


## 未覆盖范围

完整 Knee、HDR/OOTF 参数与自动默认值依赖、全部输出曲线／变体与调节组合、设备数值／性能、完整 ICC、相机／批量、LUTAnalyst／格式、真实提供商故障与签名发布仍未完成。旧 Null 尚无原生模型；当前 scene linear 不冒充 Null。

UI 继续按用户要求暂缓。真实 `full-scope-acceptance.json` 尚不存在；本工作包不替代 FULL-04／H06/H12/H14 或全量发布验收，Goal 保持 **active**。

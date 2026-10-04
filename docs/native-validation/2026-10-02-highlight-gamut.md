# 2026-10-02 Highlight Gamut 非 UI 阶段验收

## 范围与来源

接续 Knee、黑白电平与 Black Gamma，新增 `lutcalc.highlight-gamut-output-blend.v1`，替代阶段 10 普通输出色域转换；新增线性／对数过渡、纯 Swift Double 矩阵准备、schema 10、快照与程序化文稿／导出。UI 继续暂缓，没有新增控件或界面操作验收。

来源为 `js/colourspace.js` 的 `setHG/HGOut/setYCoeffs/calc`、`CSMatrix.lc/lf` 与 `js/twk-hg.js` 参数语义。产品只用 Swift、Foundation 和已有纯 Swift 原色/CAT 方程；旧 JS、Node/Python 和冻结参照属于研发，不进入 App。

参数与单位见[数值契约 2.1.7](../native-swift-numeric-contracts.md)。两种过渡都保存 stop 锚点，默认 low=0、high=2.3219；阈值为 `2^stop/5` legacy linear。有限参数必须有序且阈值为正、有限、可区分，不人为限制到某个 slider stop 区间。scene 通过 `.9` 标度衔接。

普通和高光矩阵从同一 Sony S-Gamut3.cine 工作空间输入生成 B 和 H；旧算法用**工作空间 Y 系数点乘普通输出 B**决定混合，直接混合两组 RGB 数值，不将 H 再转换回 B 色域。这是明确版本化的旧算法，不称作标准亮度保留或标准色域压缩。阴影／负 Y 使用普通输出，高光用 H，中间按线性反射率或 stop 过渡。不增加 clamp。

生成计划即使输入／输出色域相同，也在启用 Highlight Gamut 时先进入工作空间；阶段 10→11 SDR→13 Knee/编码→14 黑白电平→15 Black Gamma→19 范围映射保持。默认值的独立 gamma 锚点准备不包含 Highlight Gamut、曝光或色域矩阵。

## 先行契约与真实失败

- `contract-red.log`：核心契约先写入，缺少类型／settings 字段，实际退出 1。
- `debug-core.log`：接入期间 settings 拷贝字段替换误触了锚点编码器调用，编译明确报告额外参数／变量未定义，实际退出 1。修正为只保留 settings payload，锚点编码器不接收 Highlight Gamut。
- `storage-red.log`：存储契约先运行，schema 仍为 9、未知 `settings.highlightGamut`、版本表缺项，实际退出 1。随后补 schema 10、严格键及算法／高光色域校验。
- `pipeline-red.log`：独立全网格和旧组合链夹具尚未生成，实际退出 1；保留日志后生成参照。
- `debug-pipeline.log` 定向 **7 项、0 失败**。最终 CUBE 读回加强为负值域、非中性节点对独立 Decimal 网格核对，完整 Release 再运行通过。

没有修改旧 JS 源码、搬入厂商 LUT、降低网格或放宽 `2e-12`。

## 已取得的分项证据

- 旧引擎矩阵输出：3 组普通／高光色域组合×2 过渡×3 组 stop 参数，18 组／1386 RGB 点／**4158 通道**。负域、纯色、超白、阈值相邻值、相同高光／普通色域均覆盖；实际矩阵 `lc/lf` 逐样本一致，不推广到其他非矩阵输出。
- 独立原色与 CIECAT02/Bradford 方程：精确有理数矩阵及 **70 位 Decimal** 过渡，16 组／1232 RGB 点／**3696 通道**。包括 D65、ACES AP0/D60、ProPhoto/D50，负域和阈值附近输入；不读取旧矩阵结果作为参照。
- 线性与对数各自 **33³/65³**，域 `[−0.5,2]³`，四份完整网格合计 621124 RGB 节点／**1863372 通道**。每个节点按确切 Double 输入转 Decimal，独立计算两套矩阵与混合；不抽取灰轴或降低网格。
- 实际旧 D-Log2 解码→输入色域／曝光→CDL→Multitone→Highlight Gamut→SDR→Knee→黑白电平→Black Gamma 的 **17³** 子链。旧最后 clamp 显式关闭；不声称完整 Gamut Limiter／显示转换／False Colour／限幅链已经验收。
- 工作空间强制准备、阶段 10 替代而非重复转换、负 Y 不做对数、两端选择、disabled 普通转换、独立 1D 拒绝通过。
- schema 10 原样保存参数／算法身份，原生 schema 9 明确迁移保留 Knee；旧 schema 带新配置、未知字段和算法身份错配拒绝。disabled 仍保存身份。其他 settings helper 和文稿 gamma 编辑保留高光配置，快照／撤销不丢失。
- FileWrapper 实际本地磁盘写入／重开、EditorSession、CUBE 文件生成与解析、6 个包含非中性的节点对独立 Decimal 全网格核对通过。1D 导出写前拒绝，目标文件不存在。
- 1／4 worker 33³ 数组完全相同；有限超大输入在阶段 10／节点 0 明确报错，1 worker 任务 abort，不留下可提交 sink。

## 最终验证状态

最终整包 Release **423 项执行、0 失败、2 项既有可选夹具跳过**。跳过仍为旧 `.labin` 研发夹具和公开 NCP specimen。三平台未签名 Release 构建、源码及实际三个 App 包审计退出 **0**。数值子集也实际退出 **0**，全部终态见阶段结果文件。没有执行设备运行或完整发布入口。

尺度化误差 `abs(actual−expected)/max(1,abs(expected))` 的门槛保持 `2e-12`；RMS 包括全部样本，P99 为升序 `ceil(.99*N)` 位置。

| Release 参照 | 通道数 | 最大误差 | RMS | P99 |
| --- | --- | --- | --- | --- |
| 旧现有组合子链 17³ | 14739 | `5.634716686405631e-13` | `7.657482597526395e-15` | `8.180663801949646e-15` |
| 旧标量矩阵输出 | 4158 | `1.9984014443252818e-15` | `3.298938560716728e-16` | `7.034391322497277e-16` |
| 独立 CAT／Decimal | 3696 | `8.480463141558622e-16` | `1.6676018393657826e-16` | `4.3638585919703153e-16` |
| 独立线性／对数 33³/65³ | 1863372 | `1.2323878497565341e-15` | `1.7249681064381764e-16` | `4.506238801934162e-16` |

## 实际命令、工具链与结果包

工具链为 Xcode 27.0（27A266a）、Swift 6.4、macOS 27.0 arm64、Node 22.21.0、Python 3.14.6。失败与成功日志、阶段 `results.json`、命令／退出码清单和源码／日志／实际 App 文件哈希位于[阶段目录](artifacts/2026-10-02-highlight-gamut/)。最终轮次采用以下命令：

```sh
swift test --package-path Native/Packages/LUTKit --filter HighlightGamut
swift test -c release --package-path Native/Packages/LUTKit
node tools/native-validation/generate-highlight-gamut-legacy-reference.js
node tools/native-validation/generate-highlight-gamut-legacy-reference.js --check
node tools/native-validation/generate-highlight-gamut-legacy-pipeline.js
node tools/native-validation/generate-highlight-gamut-legacy-pipeline.js --check
python3 tools/native-validation/generate-highlight-gamut-independent-reference.py
python3 tools/native-validation/generate-highlight-gamut-independent-reference.py --check
bash tools/native-validation/verify-native-subset.sh
python3 tools/native-validation/audit-native-sources.py
python3 tools/native-validation/check-release-evidence.py
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalcHighlightGamutMacOct2DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalcHighlightGamutIOSOct2DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalcHighlightGamutSimOct2DD CODE_SIGNING_ALLOWED=NO build
python3 tools/native-validation/audit-native-bundles.py /tmp/LUTCalcHighlightGamutMacOct2DD/Build/Products/Release/LUTCalcMac.app /tmp/LUTCalcHighlightGamutIOSOct2DD/Build/Products/Release-iphoneos/LUTCalcIOS.app /tmp/LUTCalcHighlightGamutSimOct2DD/Build/Products/Release-iphonesimulator/LUTCalcIOS.app
```

全量证据检查实际退出 **2**：真实 `full-scope-acceptance.json` 尚不存在，没有创建该清单。阶段结果不代替全量清单，未签名构建不代替签名发布或真机运行。

## 未覆盖范围

当前高光色域限于原生目录的 14 个矩阵空间及 CIECAT02/Bradford；其余旧色域／特殊输出／自定义空间、其他 CAT 和全参数组合仍须按原范围补齐。内置采样风格缺公式的研究阻塞保持，不能把旧表搬入产品。当前完整网格与设备运行、性能预算不是同一个验收层级。

完整 Gamut Limiter／显示转换／False Colour／HDR、白平衡与 PSST 来源、ICC、相机与批量、LUTAnalyst／格式、真实 File Provider 故障和签名发行仍未完成。程序化文件读写不替代目标软件或 Finder/Files 交互；UI 依用户要求暂缓。

源码／包审计不替代完整来源与间接等价表人工审计。FULL-04、H06/H12/H14 与全量发布均不勾选，Goal 保持 **active**。

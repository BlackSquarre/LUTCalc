# 2026-10-02 Multitone 非 UI 阶段验收

## 实现范围

新增 Double `MultitoneSettings`、`MultitoneTone` 和 prepared `LegacyMultitone`，版本 `lutcalc.multitone-working.v1`。接入阶段 9、不可变生成请求、schema 6、程序化项目重开和 CUBE 导出；没有新增 UI 控件或进行桌面／设备交互。

来源为保留的 `js/colourspace.js:1414 buildColourSquare`、`1754 setMulti`、`2054 multiOut`，以及 `js/twk-multi.js` 的用户参数。旧代码注明 LUTCalc GPLv2 和上游 `https://github.com/cameramanben/LUTCalc`。

### 算法与旧语义

- 工作空间 Sony S-Gamut3.cine；scene 除以 `0.9` 到旧线性单位。17 个用户 saturation 控制点位于 −8 至 +8 stop、范围 `[0,2]`，以 `log2(Y/0.2)+8` 插值，两端保持；非正 Y 使用首参数和中性 Y。
- 用户色调保存 hue／saturation 的原 8-bit 参数与有限、严格递增 stop；stop 不强制限制到滑杆显示的 `[−8,8]`，不丢小数。非法间隔／溢出间隔拒绝。
- 色调按 HSL（L=0.5）公式直接计算，再 Rec.709→工作空间→输出色域。仅计算用户提供的色调，不生成或打包 256×256 色方格，不打包厂商或等价采样表。17 个 saturation 值是用户控制点，默认值是中性参数。
- **保留旧特殊行为**：旧 `setMulti` 将色调预先转到输出色域，但 `multiOut` 仍在工作空间缓冲区中用工作 Y 系数混合这些值。本版本明确保留它，不悄悄改成其他色调模型。
- `sat≥1` 用中性 Y；`sat<1` 选择／线性插值色调，按工作 Y 归一化，色调 Y≤0 回退中性。输出 `mono+sat*(input−mono)`；不 clamp 负值或 HDR。
- 同输入／输出色域时，启用 Multitone 仍经过工作空间。阶段顺序是曝光→CDL→Multitone→输出色域→SDR→输出编码。启用该耦合阶段的 1D 请求在写文件前拒绝，不取灰轴冒充等价输出；disabled 保留原无调节路径。

## 先行契约与精度诊断

先写契约，缺类型／设置字段时编译退出 1（`contract-red.log`）。实现后的首轮网格测试真实失败：65³ 第 148136 节点蓝通道，Double 参照与原生差值为 `2.1653977153938485e-12`，超过 `2e-12`。`debug-stage.log`、`grid-diagnostic.log` 和完整阶段 trace 全部保留。

该节点输入为 `(0.5428124999999999, 2.7112499999999997, 25.1184375)`，工作 Y 接近抵消。对**确切 IEEE754 输入**用精确有理数原色和 70 位 Decimal 复算：Y=`0.000918929356067425772779704731592694...`，蓝通道=`1.213381630266724709736...`。原生原结果对高精度值的误差约 `1.2011e-12`，原 Double 测试参照自身误差约 `9.6427e-13`，两者方向相反。

因此修正的是参照可靠性：为全部 33³／65³ 共 310,562 节点生成 70 位 Decimal 参照，记录输入轴的位模式，并在测试核对位模式后读回全部通道。**没有改产品计算、删除该节点、减小域或放宽阈值**。复现脚本为 `diagnose-multitone-cancellation.py`，实际日志与复算 JSON 均归档。

另先写实际旧组合链契约，缺冻结文件时真实退出 1（`pipeline-red.log`）；取得旧引擎输出后通过。最终定向 Debug **7 项、0 失败**，全包 Release **394 项执行、0 失败、2 项既有可选夹具跳过**。跳过仍是旧 `.labin` 研发夹具和公开 NCP specimen。

## 最终 Release 数值

尺度化误差为 `abs(actual−expected)/max(1,abs(expected))`，门槛保持 **`2e-12`**。RMS 对全部通道计算，P99 为升序数组的 `ceil(0.99*N)` 个样本。

| 参照 | 通道数 | 最大误差 | RMS | P99 |
| --- | --- | --- | --- | --- |
| 旧 `setMulti/multiOut`，372 点，含准备色调 | 1116 | `3.4193377524295055e-15` | `1.2790137533813859e-16` | `4.221495185442063e-16` |
| 独立有理数 HSL／矩阵及 70 位 Decimal，284 点 | 852 | `3.164135620181696e-15` | `1.9914514347055217e-16` | `7.889405669255579e-16` |
| 33³／65³，scene 域 `[−0.18,46.08]³`，独立 Decimal | 931686 | `1.201189098608258e-12` | `1.8378469776699792e-15` | `3.3000957105406944e-15` |
| 旧 D-Log2 解码／色域／曝光／CDL／Multitone／SDR 17³ | 14739 | `5.667610467233136e-13` | `8.10588321796154e-15` | `5.995204332975845e-15` |

独立参照采用 HSL 六顶点精确插值、Fraction 原色矩阵、Decimal 对数及色调插值，不调用原生或旧算子。旧参照调用实际旧 `setMulti`，组合链直接调用 `inCalcRGB→colourspace.calc(g=true)`，最终乘 `0.9` 对应 scene-linear 输出；不证明旧 HLG／BBC 最终编码。

补充实际证据：1／4 worker、997 节点分块的 33³ 输出数组完全相等；schema 6 真实磁盘 FileWrapper 写入／重开、EditorSession 快照、撤销／重做和 gamma 修改保留配置；CUBE 33³ 写出／解析及独立红轴参考点通过；SPI1D 在写文件前拒绝、目标不存在；溢出返回阶段 9／节点诊断并 abort。

## schema 6

保存 Multitone 参数与算法身份，即使 disabled 也保存版本。原生 schema 1–5 明确迁移到当前内存模型，缺新配置为 `nil`；schema 5 的 CDL／SDR 和原用户资源保留，读取不改写源文件。旧 schema 出现新字段、未知 tone 键、未知算法、非法参数或版本错配均拒绝。旧 App 设置导入没有恢复。

## 实际命令与结果归档

工具链：Xcode 27.0（27A266a）、Swift 6.4、macOS 27.0 arm64、Node 22.21.0、Python 3.14.6。最终以下命令退出 0，日志位于[阶段目录](artifacts/2026-10-02-multitone/)：

```sh
swift test --package-path Native/Packages/LUTKit --filter Multitone
swift test -c release --package-path Native/Packages/LUTKit
node tools/native-validation/generate-multitone-legacy-reference.js --check
node tools/native-validation/generate-multitone-legacy-pipeline.js --check
python3 tools/native-validation/generate-multitone-independent-reference.py --check
python3 tools/native-validation/generate-multitone-independent-grid.py
python3 tools/native-validation/generate-multitone-independent-grid.py --check
python3 tools/native-validation/diagnose-multitone-cancellation.py
bash tools/native-validation/verify-native-subset.sh
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalcMultitoneMacOct2DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalcMultitoneIOSOct2DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalcMultitoneSimOct2DD CODE_SIGNING_ALLOWED=NO build
python3 tools/native-validation/audit-native-sources.py
python3 tools/native-validation/audit-native-bundles.py /tmp/LUTCalcMultitoneMacOct2DD/Build/Products/Release/LUTCalcMac.app /tmp/LUTCalcMultitoneIOSOct2DD/Build/Products/Release-iphoneos/LUTCalcIOS.app /tmp/LUTCalcMultitoneSimOct2DD/Build/Products/Release-iphonesimulator/LUTCalcIOS.app
```

网格生成命令实际执行全部 Decimal 计算；网格 `--check` 检查来源 SHA／内容哈希和完整尺寸，不重复执行全部高精度计算。修改生成算法后必须重新生成，不能只改 metadata。Node／Python 和 Float64 参照仅属研发，不进入 App。

三平台构建未签名，只验收编译；源码和实际包审计不替代全部来源／二进制等价表人工审计。机器结果、源码／夹具／日志和构建产物哈希保存为 `results.json`、`source-sha256.txt`、`logs-sha256.txt`、`build-products-sha256.txt`。

`check-release-evidence.py` 实际退出 **2**，真实 `full-scope-acceptance.json` 仍缺失。未创建清单，未运行完整发布入口。

## 未完成范围

PSST-CDL 固定映射来源未闭合，已保存默认彩色输入也非恒等的实际复现，见[研究记录](2026-10-02-psst-fixed-rings-research.md)。白平衡继续保留其 Planck 研究阻塞。

完整自定义色域、其余调节／限制阶段、全部输出版本和组合、Multitone 其他输出色域／CAT／设备数值与性能、完整 ICC／HDR/OOTF、相机／批量、LUTAnalyst、格式、提供商故障及发布仍未完成。当前证据不能勾选 FULL-03、FULL-04、H06/H12/H14；UI 继续按用户要求暂缓，Goal 保持 **active**。

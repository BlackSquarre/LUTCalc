# 2026-10-01 H07/H14 旧 tricubic 网格取样阶段验收

## 范围与实现

本工作包推进 FULL-05 的旧插值范围：实现 `js/lut.js` 的域内三次权重和网格幽灵节点延拓，保持 `Double`、R 最快节点序、原始网格尺寸和过冲。原生入口为 `LegacyTricubicVolume3D`／`LUTInterpolation.tricubicLegacyV1`；新增 `PreparedCubeSampler` 可复用延拓网格，灰轴分析复用同一 sampler。用户导入 LUT 的 SwiftUI 插值 Picker 已接入三次选项。

支持独立三维 LUT，四点 stencil 要求尺寸至少 4。尺寸不足、1D cubic 和组合 shaper 的 cubic 显式拒绝，不回退到三线性。网格内存沿用 64 MiB 量级的受限分配边界；17³、33³、65³、129³ 不因本工作包降低尺寸。该网格由调用者的用户 LUT 构建，不属于内置转换或厂商采样表。

## 参照与契约

先增加 4 项核心与 2 项接线契约；未实现时分别因缺失 native cubic 类型、prepared sampler 和插值枚举而编译失败，退出 `1`。随后实现并通过定向 Debug 6 项。中间一次 Debug 编译因测试代码漏写 `try` 失败，已修正并保留失败日志。

- 合成多项式与交替非单调网格，尺寸 4、5、17；覆盖内部、六个面、十二条边和八个角，以及固定随机取样。共 546 个点与原 `LUTVolume.RGBCub` 的冻结输出比较，Debug/Release 最大尺度化误差均为 `0`，门槛保持 `2e-12`。
- 独立仿射参照在不等通道输入域核对全部 125 个网格节点和两个非节点。节点精确相等，非节点绝对误差低于 `2e-12`。
- 独立四点 `[0,1,1,0]` 契约在中段得到 `1.125`，未裁剪 cubic 过冲。
- `reject` 与 `clampToDomain` 分开验收；`clampToDomain` 结果不被标记为旧域外外插。
- 接线契约证明 `CubeLUT`、prepared sampler 和灰轴分析使用所选内核，并证明不支持的 1D/shaper 会失败。

合成参照生成器为 `tools/native-validation/generate-tricubic-legacy-reference.js`，只在研发环境通过 Node VM 执行保留源码，不进入 App。`--check` 已加入数值子集入口。冻结文件为 `tests/fixtures/native-contracts/tricubic-legacy-reference.json`，SHA-256 `c5fc7a1631b6ac666dbd497fbf9e8148c81e71d193f385a33958a258ef774534`；源 `js/lut.js` SHA-256 `359aabf3502eb38508bd0799d631475ecb9ad19a1af6297e95a01f1fd6f501c4`。

## 域外外插研究阻塞

`js/lut.js:2929` 将红轴外插的蓝通道导数写到 `rgb[27]`，而 `this.rgb` 只有 18 项；第 2947 行却读取 `rgb[17]`。这使蓝通道外插丢失或读取其他取样留下的状态。

最小复现：4³ 单位域仿射网格 `(R,G,B)=(r,g,r)`，输入 `(-0.1,0.5,0.5)`。解析前向结果为 `(-0.1,0.5,-0.1)`；保留旧引擎实际输出为 `(-0.09999999999999996,0.5,0)`。复现结果保存在冻结 JSON 的 `outsideResearchConflict`，执行 `node tools/native-validation/generate-tricubic-legacy-reference.js --check` 可再次核对。

因此 `legacyExtensionV1` 的域外兼容行为仍为研究阻塞：需要区分保留历史行为与按导数修正行为，不能把任一结果宣称为两者均已通过。本工作包仅发布明确的域内三次与 reject/clamp 策略，未修改保留 JavaScript 源码。

## 实际验证

工具链：Xcode 27.0（27A266a），macOS arm64。

```sh
node tools/native-validation/generate-tricubic-legacy-reference.js --check
swift test --package-path Native/Packages/LUTKit --filter LegacyTricubic
swift test -c release --package-path Native/Packages/LUTKit
tools/native-validation/verify-native-subset.sh
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalcTricubicMacOct1DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalcTricubicIOSOct1DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalcTricubicSimOct1DD CODE_SIGNING_ALLOWED=NO build
python3 tools/native-validation/audit-native-bundles.py /tmp/LUTCalcTricubicMacOct1DD/Build/Products/Release/LUTCalcMac.app /tmp/LUTCalcTricubicIOSOct1DD/Build/Products/Release-iphoneos/LUTCalcIOS.app /tmp/LUTCalcTricubicSimOct1DD/Build/Products/Release-iphonesimulator/LUTCalcIOS.app
```

以上最终命令均退出 `0`。全包 Release 为 351 项执行、0 失败、2 项既有可选夹具跳过。数值子集保留原有公式、33³/65³ 独立 CUBE 全节点读回和图像/项目/任务契约。三平台构建采用 `CODE_SIGNING_ALLOWED=NO`，不计入发布签名验收。

实际日志与源码哈希清单保存于 [证据目录](artifacts/2026-10-01-tricubic/)。

| 日志 | SHA-256 |
| --- | --- |
| 核心契约先失败 | `29f3bfe63875dcba20e3cd60b660d86120b7ed410f91e3406a90f63f78271abd` |
| 接线契约先失败 | `9f30f8f3c4d30d95c3d2b72e9821caeefbe2f0027f81fdd5056cfe781ab40d74` |
| Debug 定向最终结果 | `1a272629c7137fe4c58a12311400cb68672d4655a1956f5ad91c474baef3c060` |
| Release 全包结果 | `7d4c606f08eaaf0f5d83d5998ba467dff622212302b560d9ad8fb51c25736b55` |
| 三平台构建（各为空） | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| 三个 App 包审计 | `5cf8f49359d02d2b03d3b23d7fcc0f25b68815ca27754ee29b15de8522a24d2f` |
| 数值子集入口 | `64857a0228cae693a2c15a848a4ca57e63dedb228efe8305c9d13a4e798e2ee3` |

## 未覆盖范围

当前仍未完成 1D cubic／样条反求、组合 shaper 的 cubic、旧域外 `legacyExtensionV1`、LUTAnalyst TF／颜色完整分离及任意 3D 逆。UI 仅完成代码接线与编译，本轮没有真机或 iPad UI 操作结果包，没有跨设备 tricubic 性能预算，也没有证明用户 3D LUT 已进入生成计划。完整 H07/H10/H14、FULL-05、平台及发布门槛均保持未完成，Goal 保持 active。

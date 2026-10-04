# 2026-10-02 输出码值单位修复非 UI 验收

## 实际问题与范围

准备阶段 16 显示转换时，核对 `NativeOutputEncoder` 与实际传递函数返回值，发现原单位元数据漏列 **19 条已包装 Data 的曲线**：CIE L*、ProPhoto、BBC 0.4/0.5/0.6、BBC WHP283 400/800 和 γ1.5–γ2.6。它们的普通编码函数已执行 `Legal*.85630498533724+.06256109481916`，而先前 Knee／黑白电平／Post Gamma Limiter 却按 scale=1、offset=0 使用该值。

这会令 Legal 参数作用于错误单位，不是微小舍入差异。γ2.2、scene 黑 0、锁定 black Legal `.05` 的最小复现：旧原生输出 `.05`，正确 Data 为 `.105376344086022`，差约 `.055376344086022`。旧问题不能通过提高容差解释。

本工作包修正单位分类与共用边界，默认新请求为 `native.output-code-units.complete.v2`；保留 `native.output-code-units.partial.v1` 以复现受影响的旧原生项目。普通输出传递函数、Double、网格、位深、插值和 `2e-12` 不变。阶段 16 的显示转换仍未实现，UI 继续暂缓。

## 契约和历史重现

先写核心、项目与程序化文稿契约，再完成实现与实际运行。数值语义见[契约 2.1.9](../native-swift-numeric-contracts.md)。

- `contract-red.log` 实际退出 1：核心契约缺少 `OutputCodeUnitPolicy` 与 settings 字段。
- `debug-core.log` 核心 3 项通过；当时参照为首批 76 组，后续扩充次级空间与 Black Gamma 组合，旧日志作为历史阶段保留。
- `storage-red.log` 实际退出 1：schema 仍为 11、未知新字段、缺版本身份、旧项目被当作新策略，明确复现黑值被悄悄改变的问题。
- `debug-storage.log` 核心／存储 4 项通过。
- `debug-final.log` 实际退出 1：文稿测试错误假设 SPI1D 与 CUBE 同为 33 点，而实际服务固定输出 1024 点；原始 97 条失败断言保留。补独立 1024 点参照，保持产品规格不变。
- `debug-verified.log` 最终定向 **6 项、0 失败**（核心 3、项目 1、文稿后端 2）。
- `release.log` 首轮完整 Release 实际退出 1：12 条 Conventional Gamma 和 1 条 CIE L* 的旧版本字符串断言未包含新策略身份；数值比较通过。仅更新这两份版本契约，误差断言不变，然后重新运行完整 Release。

两种单位身份进入计划版本。schema 12 的相关 settings／algorithmVersions 必须一致，未知／缺失／错配拒绝。受影响的原生 schema 1–11 项目明确迁移到 partial v1，重新保存时显式保留其身份与原数值；未受影响输出保持原单位。读取不改写源文件，直接 `JSONDecoder` 与 `ProjectCodec` 的迁移均验证。settings helper、gamma 后端编辑、请求快照和 undo/redo 不丢策略。

partial v1 是已知有缺陷的历史兼容身份，**不满足此次 Legal 数值契约**。选择 complete v2 是明确算法边界变化；此阶段不新增选择策略的 UI。

## 数值与文件证据

- 单位分类契约覆盖当前 44 个 ID：实际 Data 返回值 34 个，canonical／scene／参数化返回值 10 个。原有 15 个 Data 曲线保持此前边界；修正的 19 个使用其实际舍入包装常数。没有按函数名猜单位。
- 实际旧引擎 **19 曲线×6 配置×72 RGB 输入＝24624 通道**：黑白电平、Knee、Post Gamma 限制以及组合链，另包含次级空间、两种保护规则和 Black Gamma。参照执行旧 `outCalcRGB` 与实际 `gamutLimOut`，末端 clamp 显式关闭；不称完整 False Colour／显示转换／HDR 链已经覆盖。
- 独立 **70 位 Decimal** 的 19 条传递方程、黑白电平 Legal 仿射与有理数 Rec.2020 Y／次级矩阵；主／次级／同时保护三种配置，**12312 通道**。不读取旧输出作为正确值。
- 对 19 条曲线逐一运行 **33³／65³ 全部节点**，域 `[−.5,2]³`，共 **17702034 通道**。该测试链是可分离的传递／黑白电平，独立高精度轴参照扩展到每个完整三维节点逐通道比较；不抽取灰轴，不据此声称三维耦合链也具有可分离性。三维耦合另有上述独立集合及既有 Limiter 网格记录。
- 程序化 FileWrapper 磁盘写重开、EditorSession、CUBE 写出／解析和非中性节点对独立网格核对通过；SPI1D **1024 点全部三通道**对独立参照核对通过，输入域一致。
- 主／次级同一策略准备、v1/v2 快照隔离、1／4 worker 的 33³ 数组一致通过；有限超大输入在阶段 14／节点 0 报错，指定 1 worker 验证 sink abort。

## Release 数值结果

尺度化误差为 `abs(actual−expected)/max(1,abs(expected))`，门槛保持 `2e-12`。RMS 包含全部样本，P99 为升序 `ceil(.99*N)` 位置。最终值由 `release-final.log` 和 `results.json` 归档。

| 集合 | 通道数 | 最大误差 | RMS | P99 |
| --- | --- | --- | --- | --- |
| 实际旧 Knee／黑白电平／Post Limiter 组合 | 24624 | `7.993605777301127e-15` | `2.1989883122005162e-15` | `4.7228504507418146e-15` |
| 独立 Decimal 耦合集合 | 12312 | `6.661338147750939e-16` | `1.569962003335032e-16` | `4.440892098500626e-16` |
| 19 曲线完整 33³ | 2048409 | `4.440892098500626e-16` | `1.5983518974995328e-16` | `4.0777601802047935e-16` |
| 19 曲线完整 65³ | 15653625 | `4.440892098500626e-16` | `1.6012455887179053e-16` | `3.8983161049435746e-16` |

最终完整 Swift Package Release **436 项执行、0 失败、2 项既有可选夹具跳过**（旧 `.labin` 研发夹具、公开 NCP specimen）。三平台未签名 Release 构建、源码和实际三个 App 包审计退出 0。数值子集也实际退出 0，终态另列于结果文件；没有设备运行证据。

## 工具链与命令

Xcode 27.0（27A266a）、Swift 6.4、macOS 27.0 arm64、Node 22.21.0、Python 3.14.6。实际终态、失败日志、命令／退出码、源代码／夹具／文档与 App 文件哈希见[阶段目录](artifacts/2026-10-02-output-code-units/)。

```sh
swift test --package-path Native/Packages/LUTKit --filter OutputCodeUnits
swift test -c release --package-path Native/Packages/LUTKit
node tools/native-validation/generate-output-code-units-legacy-reference.js
python3 tools/native-validation/generate-output-code-units-independent-reference.py
bash tools/native-validation/verify-native-subset.sh
python3 tools/native-validation/audit-native-sources.py
python3 tools/native-validation/check-release-evidence.py
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalcOutputCodeUnitsMacOct2DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalcOutputCodeUnitsIOSOct2DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalcOutputCodeUnitsSimOct2DD CODE_SIGNING_ALLOWED=NO build
python3 tools/native-validation/audit-native-bundles.py /tmp/LUTCalcOutputCodeUnitsMacOct2DD/Build/Products/Release/LUTCalcMac.app /tmp/LUTCalcOutputCodeUnitsIOSOct2DD/Build/Products/Release-iphoneos/LUTCalcIOS.app /tmp/LUTCalcOutputCodeUnitsSimOct2DD/Build/Products/Release-iphonesimulator/LUTCalcIOS.app
```

## 未覆盖范围与发布门槛

本阶段不实现显示转换，不证明全部 HDR/OOTF 参数、全部旧空间／CAT／调节组合或设备数值完成。旧 partial v1 的错误行为只获重现，不获得新正确性声明；后续 UI 重做需要明确呈现迁移与选择策略。

False Colour、白平衡／PSST 来源、全部旧曲线／空间与相机模型、ICC、批量、LUTAnalyst／格式、真实提供商故障、性能和签名发行仍缺。程序化文件证据不替代目标软件、Finder/Files 或跨设备运行。

全量证据检查实际退出 **2**，真实 `full-scope-acceptance.json` 仍缺失；未创建该清单，未执行完整发布入口、真机或签名发行。FULL-04、H06/H12/H14 不勾选，Goal 保持 **active**。

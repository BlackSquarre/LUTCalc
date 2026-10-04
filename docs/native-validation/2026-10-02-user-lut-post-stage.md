# 2026-10-02 用户 LUT 后置生成、存储与预览阶段验收

## 本轮实现范围

接续[旧 1D cubic 与组合 shaper](2026-10-02-legacy-cubic1d-shaper.md)，将已验证的取样内核接入实际生成链路。新增不可变 `UserLUTPostStageSettings`，分别保存 `interpolation` 和 `outside`。阶段位置明确为原生 `TransformPlan` 输出曲线及范围换算之后；使用用户 LUT 自身输入域，不推断相机输入曲线、色域或逆函数。

- 显式配置支持独立 1D、独立 3D 和组合 shaper→3D 的前向取样；支持线性／三线性、四面体和旧三次。各内核原有尺寸、Double、过冲、资源预算和拒绝规则继续生效。
- `LUTGenerationRequest` 和 `LUT1DGenerationRequest` 在请求建立时准备系数／网格；并发 worker 共享不可变 sampler，不逐节点重新构建。请求捕获配置及用户 LUT 的值，后续项目编辑不会改变该请求。
- 原生导出服务向 1D 导出请求传递相同配置。存在三维耦合或组合 shaper→3D 时，1D 导出在写文件前返回 `lossyRepresentation`，不取灰轴冒充完整转换。
- CPU 图像取样与显示预览请求接入相同插值／域外配置，保持原 alpha 解预乘与零 alpha 规则。界面提供独立的生成后置插值／域外控制；数值检查 Picker 的选择不悄悄改写项目生成配置。
- `legacyExtensionV1` 仍仅适用于独立 1D 的旧 cubic 前向；3D、组合 shaper 和其他内核在配置／请求阶段拒绝该策略。3D 域外冲突未解除。

## 项目 schema 3 与兼容语义

原生项目新增可选 `userLUTPostStage`，schema 升至 **3**。schema 1/2 仍可读取并迁移为当前内存模型，其新字段为 `nil`，保留旧的“单位域 1D、线性、reject 后置阶段”语义。未显式配置的 3D 或非单位域 LUT 仍拒绝生成；不能把旧项目解释成自动启用新的三维阶段。

schema 3 配置与原始资源内容／哈希一起保存。配置要求恰好一份已有用户 LUT 资源；未知嵌套字段、非法枚举、缺少资源均拒绝。旧 schema 中出现新字段也拒绝。既有重复键检查保留，将测试中的 schema 字面量改为当前版本插值，以继续真实制造重复键。

FileDocument、磁盘项目、撤销／重做、目录预设及普通设置更新保留后置配置；`EditorSession.makeSnapshot` 和 FileDocument 的生成请求均从项目配置构建阶段。非法配置在候选文稿中验证后才提交，不改变当前项目。原始用户 LUT 的字节与内容哈希不因配置而重写。

这不是外部旧 App 项目导入；只延续已有原生 schema 1/2 的兼容范围。

## 先行契约与修复记录

先新增生成与文稿契约，未实现时因缺失设置类型／请求字段编译失败，退出 `1`。发现 CPU 预览仍固定线性后，先新增预览契约，再接入设置；该先行契约同样因缺失参数失败。所有失败日志保存。

中间两次 Debug 编译失败来自新测试误用 `SPI1DFile.samples`，正确模型为 `SPI1DFile.lut.samples`；保留失败日志并修正测试。一次运行失败来自新测试误把 `dataToVideo` 写成反向映射，导致 `outsideDomain`。按既有数值契约，`D=C/1023`、`V=(C−64)/876`，所以 `dataToVideo(D)=(D*1023−64)/876`。修正独立参照及该测试的输入采样域至 `[64/1023,940/1023]`，验证完整范围换算到 `[0,1]` 后再进入 shaper；没有修改产品范围算法、裁剪超黑／超白或放宽阈值。

最终定向 Debug **8 项、0 失败**；全包 Release **368 项执行、0 失败、2 项既有可选夹具跳过**。跳过仍为旧 `.labin` 研发夹具和公开 NCP specimen。

## 数值与链路证据

| 验证 | 实际结果 |
| --- | --- |
| 用户 1D cubic 全节点 | 33³ 与 65³；每个网格分别以 1／4 worker、997 节点分块生成。全部节点对独立 Hermite 展开参照，最大绝对误差 `5.551115123125783e-17`；worker 结果数组完全相等 |
| 组合 shaper→耦合 3D | 17³ 全节点；输出 video 范围换算后先应用三点 cubic，再应用独立仿射耦合网格。最大绝对误差 `2.6645352591003757e-15` |
| 域外策略 | 同一曝光 +1 请求分别验证 reject→abort、clamp→边界 `1`、1D 旧端点延拓→`3`；无 LUT 却声明配置及不支持的延拓组合在请求创建时失败 |
| 项目与快照 | schema 3 磁盘写入／FileWrapper 重开、原始资源字节、撤销／重做、预设保留、EditorSession 快照和后续配置变更不影响旧请求；schema 1/2 迁移及未知字段拒绝 |
| 实际本地导出 | `NativeExportService` 生成 17³ CUBE 和 1024 点 SPI1D；独立参考点 `0.06296875` 与 SPI1D 非节点公式通过。组合资源包重开后生成耦合 CUBE，通过同一独立参考；尝试 SPI1D 返回不可表示，不创建输出 |
| 失败清理 | 曝光使输入超出用户 LUT 域时，CUBE 生成失败并删除暂存，不留下目标或其他部分文件 |
| CPU 预览 | 非零 alpha 解预乘后按 cubic 得到 `0.06296875`，零 alpha 保持黑色；没有把显示变换引入导出数值路径 |

绝对误差门槛保持 `2e-12`，没有降低网格、位宽或插值规则。用户 LUT 合成数据来自本轮测试，并非内置转换或厂商表。数值子集入口仍通过原有公开公式、33³/65³ CUBE、图像、项目和任务契约。

## 工具链、实际命令与日志

工具链：Xcode 27.0（27A266a）、Apple Swift 6.4、macOS arm64。以下最终命令均退出 `0`：

```sh
swift test --package-path Native/Packages/LUTKit --filter UserLUTPostStage
swift test -c release --package-path Native/Packages/LUTKit
tools/native-validation/verify-native-subset.sh
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalcPostStageMacOct2DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalcPostStageIOSOct2DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalcPostStageSimOct2DD CODE_SIGNING_ALLOWED=NO build
python3 tools/native-validation/audit-native-sources.py
python3 tools/native-validation/audit-native-bundles.py /tmp/LUTCalcPostStageMacOct2DD/Build/Products/Release/LUTCalcMac.app /tmp/LUTCalcPostStageIOSOct2DD/Build/Products/Release-iphoneos/LUTCalcIOS.app /tmp/LUTCalcPostStageSimOct2DD/Build/Products/Release-iphonesimulator/LUTCalcIOS.app
```

以上构建未签名，只验收编译。App 包审计通过所列资源及直接运行时链接边界，不替代全部算法来源或二进制等价表的人工验收。日志、工具链和源码哈希保存于[证据目录](artifacts/2026-10-02-user-lut-post-stage/)；完整清单为 `logs-sha256.txt`、`source-sha256.txt`。

| 日志 | SHA-256 |
| --- | --- |
| Debug 定向最终 | `8520009edf0f89cc7de13bac358c776d45b0366cb2d0d0469f16beb8c179b454` |
| Release 全包 | `c3784efe71a545b00b1bc2f930ab7ca4fecb7ddbe23203c2905e71a1fcacfb06` |
| 数值子集 | `72802e57bbdd34381d8fea2c2298881ccfa3a7d9cf063080f8a56ba209529049` |
| 三平台构建，各为空日志 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| 实际 App 包审计 | `5cf8f49359d02d2b03d3b23d7fcc0f25b68815ca27754ee29b15de8522a24d2f` |

## 未覆盖与目标状态

本轮项目重开／文件导出是程序化本地文件契约，不是 Finder 双击、Files 再导入或目标调色软件往返。UI 控件只完成接线和编译，未取得本轮实体 iPhone 11、iPad 多窗口／旋转／无障碍结果包。显示色彩变换仍须按既有预览验收范围单独证明；本轮预览新增契约证明 CPU 后置阶段及 alpha，不能扩大到全部 ICC／HDR 显示精度。

尚未实现用户 cubic 反求、LUTAnalyst TF／颜色完整分离与重建、LUTAnalyst 颜色分节的生成语义、完整阶段诊断与导出来源元数据、旧 3D 域外冲突解决及跨设备缓存／性能预算。File Provider/iCloud 故障、完整 ICC、HDR/EDR/OOTF、其余旧功能、真实平台验收及发布签名继续未完成。

本轮没有复跑完整发布入口，没有创建 `full-scope-acceptance.json`。H07/H10/H14、FULL-05 及全量平台／发布范围仍不勾选，Goal 保持 **active**。

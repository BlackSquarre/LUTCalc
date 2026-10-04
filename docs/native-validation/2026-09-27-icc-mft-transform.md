# 2026-09-27 ICC `mft1/mft2` 用户导入转换阶段验收

## 范围

本阶段只实现用户主动导入 ICC profile 中 `mft1`（8 位）和 `mft2`（16 位）的 RGB→RGB CPU 转换。实现使用 Swift 与 `Double`，不把 ICC payload 保存到 `ICCProfileValidation`，也没有把任何 LUT 或采样表打包进应用。`mAB `、`mBA `、device-link、系统色彩管理、HDR/EDR 和真实显示设备仍未实现。

## 依据与固定语义

**2026-09-27 更正：** 本节早期记录的“输入表→矩阵”和“R-fast”是当时实现行为，并非 ICC.1 规范语义。已在[后续规范修正验收](2026-09-27-icc-mab-mft-transform.md)中用先失败后通过的契约修正为“矩阵→输入表→CLUT→输出表”及“首通道变化最慢”；下方文字仅保留为历史阶段记录。

- 结构与字段依据 ICC.1:2022-05：<https://www.color.org/specification/ICC.1-2022-05.pdf>，包括 `lut8Type`/`lut16Type` 的通道数、网格、3×3 `s15Fixed16` 矩阵、输入/输出表项和 CLUT 布局。
- 转换顺序固定为：输入 1D 表 → 3×3 矩阵 → 3D CLUT → 输出 1D 表。
- CLUT 使用本项目冻结的 R-fast 轴序：R 轴步长为 1，G 轴步长为网格大小，B 轴步长为网格大小的平方；三线性插值使用 `Double`。
- 本阶段只接受 3 输入、3 输出和 2…64 网格点；样本输入必须有限且位于 0…1。矩阵后超出 CLUT 采样域时按采样器边界夹取，外部输入域错误直接拒绝。
- 1D 表和 CLUT 的原始整数值即时转换为 `Double`，只保存在当前转换实例中，不进入 profile 结构摘要或应用内置资源。

## 先写契约测试，再实现

新增 `ICCMFTContractsTests` 共 5 项：

1. `mft1` 恒等表、R-fast CLUT 和 8 位量化误差。
2. `mft2` 恒等表、16 位三线性插值、非有限输入和越界输入拒绝。
3. 非 RGB 通道和 payload 长度错误拒绝。
4. `s15Fixed16` 缩放矩阵在 CLUT 前生效。
5. `mft2` 输入表和输出表使用不同表项数时仍按各自表长度解析。

测试夹具只在测试目标中构造规范 payload，不作为应用资源。

## 实现文件与哈希

- `Native/Packages/LUTKit/Sources/LUTPreview/ICCProfile.swift`：新增经完整 profile 校验后的单次 tag payload 提取；`mft` 元数据仍只做结构摘要。SHA-256 `495e295f4ac4eedb1cf57b733a10a59ec315cdf8c284bd4100f2aeb3785c3859`。
- `Native/Packages/LUTKit/Sources/LUTPreview/ICCMFTTransform.swift`：`mft1/mft2` Double 转换路径。SHA-256 `780ae11d51baf871771c5f49329e5e105a02d267f57c216ed824f9cde45b6ae6`。
- `Native/Packages/LUTKit/Tests/LUTPreviewTests/ICCMFTContractsTests.swift`：契约测试与规范夹具。SHA-256 `e39388a3123708e29957fa8bd404560477002ad8cebde3df9c0f345b28e20235`。

## 工具链

- Xcode `27.0`（Build `27A266a`）。
- Apple Swift `6.4.0.34.1`，Swift language mode 6。
- macOS arm64；Package 最低平台 macOS 14、iOS 17。

## 实际命令与结果

定向 Debug：

```text
swift test --package-path Native/Packages/LUTKit --filter ICCMFTContractsTests
```

退出码 `0`，5 项通过。日志 `/tmp/lutcalc-icc-mft-debug-20260927.log`，SHA-256 `de7b4531f0b3444b8f4f765668bee18383407dec4e58eb18dcfb523cbce21540`。

定向 Release：

```text
swift test --package-path Native/Packages/LUTKit -c release --filter ICCMFTContractsTests
```

退出码 `0`，5 项通过。最终日志 `/tmp/lutcalc-icc-mft-release-20260927-final2.log`，SHA-256 `4405bbb0081515c3bb8ba7339aba0998a0846d7073c5eb937eea9aad4bab56f4`。

全包 Swift Release：

```text
swift test --package-path Native/Packages/LUTKit -c release
```

退出码 `0`，所有执行到的测试套件均为 0 失败；`swift test --list-tests` 列出 327 项。最终日志 `/tmp/lutcalc-icc-mft-full-release-20260927-final.log`，SHA-256 `c8047655c0b09ce9ea7932074e22ba5e5d8fc387101e38de03286e899e5ec01d`。

三平台 Release 构建：

```text
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'generic/platform=macOS' -derivedDataPath /tmp/LUTCalcICCMFTMacDD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalcICCMFTSimDD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

三条命令退出码均为 `0`。由于同一默认 DerivedData 目录并发构建会锁定 `build.db`，前两条并发尝试退出 `65`；随后使用独立 `-derivedDataPath` 串行重跑成功。最终日志分别为 `/tmp/lutcalc-icc-mft-mac-20260927-final.log`、`/tmp/lutcalc-icc-mft-sim-20260927-final.log`、`/tmp/lutcalc-icc-mft-ios-20260927-final.log`，三份日志均为空且 SHA-256 为 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。

## 数值结果

- `mft1` 8 位恒等夹具的端点和中间点均在 `1/255` 绝对误差内。
- `mft2` 16 位恒等夹具的中点在 `2/65535` 绝对误差内；输入表 2 项、输出表 3 项的合法布局也通过。
- 矩阵夹具验证输入 `(0.8, 0.4, 0.2)` 经 0.5 对角矩阵后得到约 `(0.4, 0.2, 0.1)`，误差门槛为 `1/255`。
- 没有改变网格大小、位宽、插值规则或最终生成路径的 `Double` 精度。

## 未覆盖与路线状态

本阶段只证明用户导入 `mft1/mft2` 的受限 RGB 转换。`mAB `/`mBA ` 的曲线/矩阵/CLUT 组合、LUT profile linking、渲染意图、ICC 显示工作空间、Core Image/系统色彩管理、HDR/EDR、真实图像导入和真机 Files 往返仍未验收。因此 H13、FLOW-05、UI-03、UI-06 以及 FULL-01 至 FULL-08 继续保持未完成；Goal 保持 active。没有创建或修改 `docs/native-validation/full-scope-acceptance.json`。

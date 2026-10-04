# 2026-09-27 ICC `mAB/mBA` 与 `mft1/mft2` 数值契约验收

## 范围

本阶段只实现用户主动导入 ICC profile 的三通道 CPU 路径。没有新增厂商 profile、内置 LUT、旧 `.labin` 或等价采样资源；所有解析和生成仍使用 Swift `Double`。实现依据 ICC.1:2022-05 的公开定义（<https://www.color.org/specification/ICC.1-2022-05.pdf>）：

- `mAB ` 顺序为 A 曲线、CLUT、M 曲线、矩阵、B 曲线；`mBA ` 顺序为 B 曲线、矩阵、M 曲线、CLUT、A 曲线。
- 3×4 矩阵按每行三个系数后一个 offset 交错存储；矩阵结果按规范在后续曲线或 CLUT 前限制到 `0...1`。
- CLUT 第一通道变化最慢，最后通道变化最快；每个节点按输出通道连续存放。
- `para` type 3 使用 6 个参数，type 4 使用 7 个参数；曲线和处理 section 必须受相邻 offset 的物理边界约束。

## 先失败后修复

先加入的独立夹具覆盖 type 3/4 两侧分段、矩阵交错布局、非统一网格、非法可选组合、section 越界和曲线 offset 共享。修复前，type 3 的 6 参数输入被错误拒绝，CLUT/矩阵会误读相邻 section，且轴序和矩阵位置测试失败；这些失败没有通过放宽阈值规避。

## 修改

- `Native/Packages/LUTKit/Sources/LUTPreview/ICCMABTransform.swift`
  - 修正 type 3/4 参数数量和公式；加入有限结果检查。
  - 为曲线、矩阵、CLUT 施加下一个 section offset 边界及溢出检查。
  - 按 ICC 规定读取交错 3×4 矩阵、执行合法组合检查、CLUT 使用首通道最慢布局。
- `Native/Packages/LUTKit/Sources/LUTPreview/ICCProfile.swift`
  - 结构验证允许 A/B/M 曲线共享 offset，同时继续拒绝矩阵或 CLUT 与其他处理元素别名。
- `Native/Packages/LUTKit/Sources/LUTPreview/ICCMFTTransform.swift`
  - 修正 `mft1/mft2` 为矩阵→输入表→CLUT→输出表，并使用 ICC 的首通道最慢 CLUT 布局。
- `Native/Packages/LUTKit/Tests/LUTPreviewTests/ICCMABContractsTests.swift`
  - 新增 12 项契约测试，覆盖顺序、分段、边界、组合、矩阵、非统一网格和 Double 结果。
- `Native/Packages/LUTKit/Tests/LUTPreviewTests/ICCMFTContractsTests.swift`
  - 新增矩阵先行和 ICC 通道顺序回归测试，共 6 项定向测试。

源码 SHA-256：

- `ICCMABTransform.swift`：`2aa19162db2e85b5ed9fd3b7c3baf58d03ac666cdd46af04adb89435abb23f97`
- `ICCMFTTransform.swift`：`4e13384ea7efe3882cabedda9eb847c1630dc1164e0391e6510c6948cf459bd6`
- `ICCProfile.swift`：`b6faeb107db6e2a63b609a36462c1120a09237cde29e03291ac6b1ea0b7d2c83`
- `ICCMABContractsTests.swift`：`c055aa34c6b72d8c9db05b67ee3fa880bc9a0606ad870d63b23caa0bc5d2804d`
- `ICCMFTContractsTests.swift`：`5fead66e182c6888818f7a7533c4d5b26fce64a030100c84d6c4592d8e4687aa`

## 实际命令与结果

工具链：Xcode `27.0 (27A266a)`，Swift `6.4`，Apple Swift `6.4.0.34.1`，arm64 macOS。

- `swift test --package-path Native/Packages/LUTKit --filter ICCMABContractsTests`：12 项通过，退出码 `0`；日志 `/tmp/lutcalc-icc-mab-final-debug-20260927.log`，SHA-256 `945c110f1f928c9977a6f04d225ee2f6638865fb05cd127446cc61ba074aa381`。
- `swift test --package-path Native/Packages/LUTKit -c release --filter ICCMABContractsTests`：12 项通过，退出码 `0`；日志 `/tmp/lutcalc-icc-final-mab-release-20260927.log`，SHA-256 `afa2f221509b7432a48b5be8474219cd656e71609a1df246f1bc172519c05bd0`。
- `swift test --package-path Native/Packages/LUTKit --filter ICCMFTContractsTests`：6 项通过，退出码 `0`。
- `swift test --package-path Native/Packages/LUTKit -c release --filter ICCMFTContractsTests`：6 项通过，退出码 `0`；日志 `/tmp/lutcalc-icc-final-mft-release-20260927.log`，SHA-256 `854fa944aae4f46115903f621a9f2864d2ed5864be9d3933c816c65bfdbb8aee`。
- `swift test --package-path Native/Packages/LUTKit -c release`：342 项执行，0 失败，2 项既有可选夹具按设计跳过，退出码 `0`；日志 `/tmp/lutcalc-icc-final-full-release-20260927.log`，SHA-256 `da229a3cf5f92159e53f27ddb4d9c5621228fcc556299581e46b8fcd3fbc8060`。
- `xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/LUTCalcICCFinalMacDD CODE_SIGNING_ALLOWED=NO build`：退出码 `0`；日志 `/tmp/lutcalc-icc-final-mac-build-20260927.log`，SHA-256 `612d7cf2a9fa7654dca3ee9b110a6c14a1fdf03707816ff7bd45d16737add333`。
- `xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalcICCFinalIOSDD CODE_SIGNING_ALLOWED=NO build`：退出码 `0`；空日志 SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。
- `xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalcICCFinalSimDD CODE_SIGNING_ALLOWED=NO build`：退出码 `0`；空日志 SHA-256 同上。
- `bash Scripts/verify-native-release.sh`：构建、Swift 回归和 3 个 App 包资源审计通过；按设计退出码 `2`，因为真实 `docs/native-validation/full-scope-acceptance.json` 仍缺失。日志 `/tmp/lutcalc-icc-final-release-gate-20260927.log`，SHA-256 `757f3e72d943ad4dcc1f63e1087f181165060dc48d344618981504bd9372a682`。

合成 ICC 夹具的 16 位曲线/CLUT 线性结果均符合原有 `2/65535` 绝对误差测试门槛；没有计算真实第三方 profile 的最大误差，因此不报告不存在的独立实样误差。

## 未覆盖与阻塞

没有真实第三方 `mAB/mBA` profile 的独立数值参照；没有完成完整 ICC 类型、任意通道数、工作/显示空间转换、整图显示、HDR/EDR、真机 ICC 文件往返或目标软件验证。该阶段不勾选完整 H13、完整 ICC 或 Goal；真实 `docs/native-validation/full-scope-acceptance.json` 仍缺失。

# LUTAnalyst 三线性三维反求诊断验收

## 2026-10-05 解析 Jacobian 复验

本次复验将单元内 Newton 候选求解使用的 Jacobian 从有限差分改为三线性多项式的解析偏导。生产采样、Double 精度、网格、插值规则、`2e-12` 相对尺度阈值和保守 `unresolved` 语义均未改变。新增强缩放仿射单元契约，验证在通道尺度约为 `5e5` 至 `1e6` 时仍能回到已知输入坐标。

定向 Debug／Release 均为 10 项通过、0 失败。完整 Swift Release 为 8 个测试包、793 项执行、0 失败，其中 `LUTFormats` 保留 2 项既有外部夹具跳过，`LUTAnalysis` 为 66 项。解析 Jacobian 新增契约也在完整回归中通过。

实际命令：

```sh
swift test --package-path Native/Packages/LUTKit -c debug --filter TrilinearInverseContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter TrilinearInverseContractsTests
swift test --package-path Native/Packages/LUTKit -c release
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -sdk macosx -destination generic/platform=macOS -derivedDataPath /tmp/lutcalc-trilinear-analytic-macos-20261005 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/lutcalc-trilinear-analytic-ios-20261005 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/lutcalc-trilinear-analytic-simulator-20261005 CODE_SIGNING_ALLOWED=NO build
```

结果包：`artifacts/2026-10-05-lutanalyst-trilinear-analytic-jacobian/`。

三平台 Release 构建使用独立 DerivedData 和 `CODE_SIGNING_ALLOWED=NO`，macOS、generic iOS、generic iOS Simulator 均退出码 `0`，三份日志均包含 `BUILD SUCCEEDED`。

SHA-256：

- `targeted-debug.log`: `56fe26eb471ac64542ecee79673302ab1e515126d64900706fb8d67eb3101e4e`
- `targeted-release.log`: `b8473ad69e67b2642b3a04b936b67ea695d82a56e0be8eb2145a11bf40a25936`
- `full-release.log`: `b0b4b2c3f7331a861a681870c078d5625b73181bfd127265fece3f16c8372fd5`
- `macos-release.log`: `422ffad9d9966296a9a64e9978a6e68b0483aea7f330becc8d4917583736fb32`
- `ios-release.log`: `db037f355ee30a6ce657c2fa2c3f9db2b8179a0842194e14eb6c308aeba19514`
- `simulator-release.log`: `c1801617a2989737a8acb97da092057fe459173c95a69831c6944a9b4a7d7f1d`
- 本批所有 `.exit` 文件：`9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa`

工具链：Xcode `27.0 (27A266a)`，Swift `6.4`，Apple Silicon macOS。

## 范围

本批只验证导入 3D CUBE 在现有生产 `trilinear` 采样规则下的逐网格单元反求诊断。实现使用 Swift `Double`，对每个单元求数值候选，并用生产采样回放和相对残差核验；折叠映射返回多个分支，奇异单元或包围盒命中但有限求解器未能证明的单元报告 `unresolved`，不伪造唯一逆。带 shaper、非三线性插值和超过资源预算的输入明确拒绝。

本批不完成任意 3D LUT 的连续全局反求、tricubic 反求、组合 shaper 反求、自动 transfer／colour 分离、生成计划／项目／导出接线，也不改变 LUT 节点、网格、位宽、插值规则或既有阈值。FULL-05、H10 和 Goal 继续保持 active。

## 契约与实现

- `Trilinear3DInverse.analyze` 穷举所有网格单元，使用包围盒筛选、多个初值和三元 Newton 候选。
- 每个候选必须落在单元内，并以生产 `LUTVolume3D.sample(..., interpolation: .trilinear)` 回放通过 `2e-12` 相对尺度残差。
- 恒定／奇异单元以及包围盒覆盖目标但没有回放通过根的单元不下结论，报告 `unresolvedBoxCount`；结果按输入坐标稳定排序并去除相邻单元边界重复根。
- 契约覆盖恒等唯一解、折叠双解、域外无解、包围盒命中未决、退化未决、相邻单元边界根去重、非单位输入域坐标回映射、非法容差／资源预算和非三线性／shaper 拒绝。

## 实际验证

工具链：Xcode 27.0、Swift 6.4，Apple Silicon macOS。

定向 Release 命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter TrilinearInverseContractsTests
```

结果：9 项通过，0 失败；退出码 `0`。完整 Release 命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release
```

结果：8 个测试包、733 项执行、0 失败；退出码 `0`。其中 LUTAnalysis 测试包 63 项，`TrilinearInverseContractsTests` 9 项。结果文件：

- `artifacts/2026-10-04-lutanalyst-trilinear-inverse/targeted-release.log`
- `artifacts/2026-10-04-lutanalyst-trilinear-inverse/targeted-release.exit`
- `artifacts/2026-10-04-lutanalyst-trilinear-inverse/targeted-debug.log`
- `artifacts/2026-10-04-lutanalyst-trilinear-inverse/targeted-debug.exit`

平台 Release 构建命令均使用 `CODE_SIGNING_ALLOWED=NO`，结果退出码均为 `0`：

```sh
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -sdk macosx -destination generic/platform=macOS -derivedDataPath /tmp/lutcalc-lutanalyst-trilinear-macos-20261004-final CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/lutcalc-lutanalyst-trilinear-ios-20261004-final CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/lutcalc-lutanalyst-trilinear-simulator-20261004-final CODE_SIGNING_ALLOWED=NO build
```

构建日志为 `macos-release.log`、`ios-release.log`、`simulator-release.log`，三份日志均包含 `BUILD SUCCEEDED`；对应 `.exit` 文件保留实际退出码。
- `artifacts/2026-10-04-lutanalyst-trilinear-inverse/full-release.log`
- `artifacts/2026-10-04-lutanalyst-trilinear-inverse/full-release.exit`

SHA-256：

- `targeted-debug.log`: `1830237f6f8989ce9df99c1443170858479c7d6675b2b28419c7f4cfb6e4d652`
- `targeted-debug.exit`: `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa`
- `targeted-release.log`: `5194ccdd32ca6741cb792b0321606d1e9398cc24eb0dd2fba3868421bff7ab6a`
- `targeted-release.exit`: `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa`
- `full-release.log`: `ba2b30a120c2a8f2495333fe403c59fd574dba00172812803b0279dffb0b0c2a`
- `full-release.exit`: `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa`
- `macos-release.log`: `4e5b10ff67b79a93a3a613da29da1e4f0f7525db05d11c4266adc16c012ffc6d`
- `macos-release.exit`: `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa`
- `ios-release.log`: `7dd541dcbfa0691b8bd6bbde2a750ed1deac3825f6b949684ba9bfb7bef3e359`
- `ios-release.exit`: `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa`
- `simulator-release.log`: `fb3b3ae5b353d60a56b1dcaaab0d2842e0941739b043ef782c3af49e648e2eb7`
- `simulator-release.exit`: `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa`

## 未覆盖与后续

Newton 数值诊断依赖有限初值集合；包围盒命中但未找到回放通过根时现保守报告未决，因此不会把求解器覆盖不足误报为无解。非单位域只验证了坐标回映射，不代表任意连续 LUT 的全局唯一性。tricubic 旧扩展仍受旧红轴外插索引冲突研究阻塞，不能据此自动生成逆。9 个 `.labin`、45 个直接查表注册、完整 ICC／HDR/OOTF、格式目标软件往返、UI、真机性能和发布验收仍按原台账处理。

## 2026-10-05 资源上限溢出安全复验

三线性网格盒子总数 `(size - 1)^3` 现使用 `multipliedReportingOverflow`，在遍历前同时检查整数溢出和 `maxBoxes`。超限统一返回 `.invalidMaxBoxes`，不把资源拒绝误报为无解，也不改变合法网格的候选、插值规则、Double 路径或 `2e-12` 阈值。契约使用 size 3、`maxBoxes: 1` 复现超限路径。

实际命令：

```sh
swift test --package-path Native/Packages/LUTKit -c debug --filter TrilinearInverseContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter 'TrilinearInverseContractsTests|TetrahedralInverseContractsTests|TricubicInverseContractsTests|CombinedShaperColourInverseContractsTests'
swift test --package-path Native/Packages/LUTKit -c release
bash Scripts/verify-native-numerics.sh
```

结果：Debug 定向 10 项通过；Release 组合定向 31 项通过；Swift Release 全量和原生数值门禁退出码均为 `0`。结果包位于 `artifacts/2026-10-05-lutanalyst-trilinear-resource/`。

日志 SHA-256：

- `trilinear-resource-debug.log`: `c622601cbc8a32edc023403ced542a73dcc7fe5e2e1545aed1f51e625d8608cc`
- `trilinear-resource-release.log`: `fb4a1d482a00d227f8f4579eba0bc3a97fead28c6e18f547f183091a4f8cd679`
- `trilinear-resource-full.log`: `3e3822b14b1f4b0129c2c212a98bec787603d6220654e86a584ae45d7b15a4ab`
- `trilinear-resource-numerics.log`: `e36ea0ac259a6e5157c1a5457a308fa2e6a4a80d7ffe8b8f87a14301bcb07a70`

该修复只关闭资源计数的整数安全边界，不增加任意三维 LUT 全局反求、跨单元全根完备性、连续域唯一性、自动 transfer／colour 分离或完整重建的证据；`FULL-05`、`H10` 和 Goal 继续保持 active。

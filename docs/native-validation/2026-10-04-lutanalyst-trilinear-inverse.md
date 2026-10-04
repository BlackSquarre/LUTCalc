# LUTAnalyst 三线性三维反求诊断验收

## 范围

本批只验证导入 3D CUBE 在现有生产 `trilinear` 采样规则下的逐网格单元反求诊断。实现使用 Swift `Double`，对每个单元求数值候选，并用生产采样回放和相对残差核验；折叠映射返回多个分支，奇异单元或包围盒命中但有限求解器未能证明的单元报告 `unresolved`，不伪造唯一逆。带 shaper、非三线性插值和超过资源预算的输入明确拒绝。

本批不完成任意 3D LUT 的连续全局反求、tricubic 反求、组合 shaper 反求、自动 transfer／colour 分离、生成计划／项目／导出接线，也不改变 LUT 节点、网格、位宽、插值规则或既有阈值。FULL-05、H10 和 Goal 继续保持 active。

## 契约与实现

- `Trilinear3DInverse.analyze` 穷举所有网格单元，使用包围盒筛选、多个初值和三元 Newton 候选。
- 每个候选必须落在单元内，并以生产 `LUTVolume3D.sample(..., interpolation: .trilinear)` 回放通过 `2e-12` 相对尺度残差。
- 恒定／奇异单元以及包围盒覆盖目标但没有回放通过根的单元不下结论，报告 `unresolvedBoxCount`；结果按输入坐标稳定排序并去除相邻单元边界重复根。
- 契约覆盖恒等唯一解、折叠双解、域外无解、包围盒命中未决、退化未决、非法容差／资源预算和非三线性／shaper 拒绝。

## 实际验证

工具链：Xcode 27.0、Swift 6.4，Apple Silicon macOS。

定向 Release 命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter TrilinearInverseContractsTests
```

结果：7 项通过，0 失败；退出码 `0`。完整 Release 命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release
```

结果：8 个测试包、61 项执行、0 失败；退出码 `0`。结果文件：

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

- `targeted-debug.log`: `48331cef0e359818c50227cc197c6b79666d5d421534fec3e298f3e4db669e76`
- `targeted-debug.exit`: `5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9`
- `targeted-release.log`: `f9b06c542654a01c184b4f4331831bbf284b2ff6aff4234c0f6dced327317531`
- `targeted-release.exit`: `5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9`
- `full-release.log`: `618cd74705641a4548570b6877e9449f4b6ace3e86d6d5fd363a26bbf72741f8`
- `full-release.exit`: `5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9`
- `macos-release.log`: `e6a507ae0b6aab08bfd1f50467d05e87c98c2b648d4794d8a803e6154847ae87`
- `macos-release.exit`: `5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9`
- `ios-release.log`: `b585cd1e207c7de249a1c8c848f170005f5ea4ff6f3e524b7e337ee76bc0d542`
- `ios-release.exit`: `5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9`
- `simulator-release.log`: `151a7490cc78a7f6fb0f572980a658bf28e7f0d9826a28cf161de6cfae84f3a4`
- `simulator-release.exit`: `5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9`

## 未覆盖与后续

Newton 数值诊断依赖有限初值集合；包围盒命中但未找到回放通过根时现保守报告未决，因此不会把求解器覆盖不足误报为无解。它没有证明任意连续 LUT 的全局唯一性。tricubic 旧扩展仍受旧红轴外插索引冲突研究阻塞，不能据此自动生成逆。9 个 `.labin`、45 个直接查表注册、完整 ICC／HDR/OOTF、格式目标软件往返、UI、真机性能和发布验收仍按原台账处理。

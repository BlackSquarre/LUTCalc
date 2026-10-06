# LUTAnalyst 组合 shaper 与三维 colour 局部反求验收

日期：2026-10-05

## 范围

本轮只补齐用户导入 CUBE 的显式 `shaper -> colour` 诊断接线。算法先在不带 shaper 的三维 colour LUT 上运行已有三线性、四面体或旧 tricubic 局部诊断，再对每个颜色候选逐通道求 shaper 的全部 cubic 根，最后使用完整生产 sampler 回放。候选只在残差满足既有 `2e-12` 相对尺度阈值时保留。

新增 `ImportedLUTAnalyzer.diagnoseCombinedShaperColourInverse` 及其结果类型。有限候选遗漏、颜色单元奇异、shaper 平段或非单调边界保留为 `unresolved`，不被折叠为无解或唯一根。该入口没有接入 `inverseColourLUT` 默认路径、生成计划、项目持久化或 UI，也没有从 LUT 样本推断模型。

## 契约

`CombinedShaperColourInverseContractsTests` 共 4 项：

1. 恒等 shaper 与恒等 colour LUT 经过完整生产 sampler 回放得到唯一根。
2. 折叠 shaper 保留两个输入分支，并核对两个根的回放残差。
3. 奇异 colour 单元在组合路径中保持 `unresolved`。
4. 缺少 shaper、非法 tolerance 和零结果上限明确拒绝。

随后补充四面体资源上限契约：`Tetrahedral3DInverse` 在遍历前以溢出安全方式计算 `(size - 1)^3 * 6`，超过 `maxTetrahedra` 或发生整数溢出时明确抛出 `invalidMaxTetrahedra`；组合 shaper 的 tetrahedral 路径把 `maxCells` 传递到该上限。

## 实际命令与结果

工具链：Xcode `27.0 (27A266a)`，Swift `6.4`，Apple Silicon macOS。先行契约在旧实现上因缺少组合入口编译失败；实现后执行：

```sh
swift test --package-path Native/Packages/LUTKit \
  --filter CombinedShaperColourInverseContractsTests
swift test --package-path Native/Packages/LUTKit -c release \
  --filter CombinedShaperColourInverseContractsTests
swift test --package-path Native/Packages/LUTKit -c release
bash Scripts/verify-native-numerics.sh
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac \
  -configuration Release -destination 'platform=macOS' \
  -derivedDataPath /tmp/LUTCalcCombinedMacDD CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/LUTCalcCombinedIOSDD CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS \
  -configuration Release -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/LUTCalcCombinedSimDD CODE_SIGNING_ALLOWED=NO build
```

- Debug 定向：4 项通过，退出码 `0`。
- Release 定向：4 项通过，退出码 `0`。
- Swift Release 全量：退出码 `0`，无失败。
- 原生数值门禁：退出码 `0`。
- macOS、iOS generic、iOS Simulator Release：均出现 `** BUILD SUCCEEDED **`，退出码均为 `0`。Simulator 构建日志仍记录了环境层 `CoreSimulator` 内存警告，但不影响 generic 编译结果。

资源上限修复后的复验：四面体定向 9 项与组合 shaper 定向 4 项 Release 共 13 项通过；Swift Release 全量、原生数值门禁、macOS、iOS generic、iOS Simulator Release 均退出 `0`。复验日志和退出码追加在同一结果目录，文件名带 `max-tetra`；Simulator 日志仍保留 CoreSimulator 内存警告，但构建结果为 `** BUILD SUCCEEDED **`。

结果包：`docs/native-validation/artifacts/2026-10-05-lutanalyst-combined-shaper-inverse/`。

日志 SHA-256：

- `targeted-debug.log`: `31c7c9d511913e2bb6010d031f751734e2e3420bb831007034ebc80c2ff97942`
- `targeted-release.log`: `1470dc04610a3891fb0cc7d8325b1fcb4c990eec114be4c90962a04a172cf9c0`
- `full-release.log`: `cb3887a74d169b614012217d67b3dcc68a3be79aee4bc4452f28aca337a131ed`
- `numerics-gate.log`: `d45d7b851b5a9e03a7acb74bc65b69a7dbb9415b41cafc3c8162e653bb7ec2fc`
- `macos-release.log`: `80ca71e22f31b5e3c49e6ad754372c13b6a1369958cd6a0de9f3822c3b052251`
- `ios-release.log`: `d724968a2653b52918d99a09a22e8536a4a462ab72194cb08fbbc47da7e6a80c`
- `simulator-release.log`: `10621fe5ad0c6b2904abc3e3edaaad09c7daead3067668a63a718bebd0c35655`

七个 `.exit` 文件内容均为 `0`，SHA-256 均为 `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa`。

## 未覆盖范围

该入口仍是局部候选诊断，不证明任意三维 LUT 的全局根完备性、跨单元多根、切向根、病态 Jacobian 或连续域唯一性。没有实现自动 transfer/colour 分离、完整重建、生成导出接线、`.labin` 替代、直接查表替代、完整 HDR/ICC 或目标软件往返。`FULL-05`、`H10` 和 Goal 继续保持 `active`。

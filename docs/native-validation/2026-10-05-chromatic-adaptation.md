# 2026-10-05 公开 CAT 白点适应矩阵验收

## 范围

本轮只补齐现有 `ChromaticAdaptation` 数学分派中已有来源的 3×3 锥响应模型：CIE CAT97s、Von Kries、Sharp、CMCCAT2000、Bianco-S、Bianco-S-PC 和 XYZ Scaling。CIE CAT02、Bradford 的既有行为不变。实现没有新增 UI 选择器、项目字段、默认 CAT、厂商 LUT、`.labin` 或采样数组。

旧 JavaScript 的模型常数来自 `js/lutcalccombined.js` 中 `CSCAT.prototype.models`，该文件 SHA-256 为 `75dabaed379417d7e2edd30dd3c6dd942b60a022d8b05f74a74787d0e6726b74`。每个模型均按锥响应适应的公开矩阵形式运行时计算：

```text
M = A⁻¹ · diag(A·W_target / A·W_source) · A
```

源码只保留 3×3 常数，计算路径使用 `Double`。同一源／目标白点直接返回恒等矩阵；现有项目缺少 `adaptation` 时仍按 CIE CAT02 解码。

## 契约先行

先新增 `ChromaticAdaptationContractsTests`，在实现前运行：

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter ChromaticAdaptationContractsTests
```

旧枚举缺少 `cieCAT97s`、`vonKries`、`sharp`、`cmccat2000`、`biancoBS`、`biancoBSPC` 和 `xyzScaling`，编译按预期失败。该红灯没有计入生产失败。

## 实现与独立参照

实现文件：

- `Native/Packages/LUTKit/Sources/LUTCore/Matrix3x3.swift`
- `Native/Packages/LUTKit/Tests/LUTCoreTests/ChromaticAdaptationContractsTests.swift`

独立参照脚本使用 Python 90 位 `Decimal`，没有导入 Swift 源码或旧 JavaScript：

```sh
python3 tools/native-validation/probe-chromatic-adaptation.py \
  > /tmp/lutcalc-chromatic-adaptation-decimal-20261005.json
```

参照输入是源 D65 `(0.3127, 0.3290)`、目标 D50 `(0.3457, 0.3585)`，并核对非中性 XYZ `(0.25, 0.4, 0.1)`。9 个模型的矩阵和样本结果均在 `2e-15` Double 门槛内；同白点恒等和 Codable 原始值往返也通过。

## 实际结果

工具链：Xcode `27.0 (27A266a)`、Swift `6.4`、Apple Silicon macOS。

```sh
swift test --package-path Native/Packages/LUTKit -c debug \
  --filter ChromaticAdaptationContractsTests \
  2>&1 | tee /tmp/lutcalc-chromatic-adaptation-contracts-debug-20261005.log

swift test --package-path Native/Packages/LUTKit -c release \
  --filter ChromaticAdaptationContractsTests \
  2>&1 | tee /tmp/lutcalc-chromatic-adaptation-contracts-release-20261005-r2.log
```

Debug 与 Release 均退出码 `0`，各执行 2 项、失败 `0`。

随后运行 `Scripts/verify-native-numerics.sh`，66 个原生检查、11 个 Node 契约、54 个 CUBE 生成/读回案例及 Swift 命令行检查全部通过，退出码 `0`。本次入口日志 SHA-256 为 `dd855ad8dcdea3467dfabf300003deff9cd562d561c47664cf9d25f881070bdf`。

结果包 `docs/native-validation/artifacts/2026-10-05-chromatic-adaptation/`：

- `independent-decimal-results.json`：`e689f3afcc0b62f86211b21bff8ba6eaacddd464964a6309376695c04a2fe2bc`
- `targeted-debug.log`：`7f5eb6b7b60f572cacbe5c203ab74509909a85210f95ce7a5c494d9a533d82c2`
- `targeted-release.log`：`c46a14e90534819afcf5df921b384871391dc6e68cdc59748fdd327812292b26`
- `verify-native-numerics.log`：`dd855ad8dcdea3467dfabf300003deff9cd562d561c47664cf9d25f881070bdf`

源码 SHA-256：

- `Matrix3x3.swift`：`5c19f16d64b4c5c60f025a3df4bd89d47aa7d2f51a5940d7fa5ade77804d97fd`
- `ChromaticAdaptationContractsTests.swift`：`2e0ddef994628e89f4bf573a29e4a69330da05ede8f70bb6046db0a69aa64b0a`
- `probe-chromatic-adaptation.py`：`8779c13d8d306ceb586b6c52e0b39d7fa384e0267dc9c7390f518c12352a3a47`

## 未覆盖范围

本轮不等于完整白平衡或完整 H03/H11：501 点 Planck 轨迹、CCT/Duv/Dpl 的连续来源、PSST 固定映射、旧调节链组合、完整自定义色域、厂商查表替代、HDR/EDR、ICC、LUTAnalyst、UI、真机和发布验收仍未完成。Goal 保持 `active`。

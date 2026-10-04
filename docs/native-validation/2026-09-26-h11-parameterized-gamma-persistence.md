# H11 任意参数化 Gamma 持久化阶段验收

日期：2026-09-26

## 范围

本批只处理已有 `ParameterizedGammaTransfer` 算法的项目持久化和执行接线。参数仍是纯 Swift `Double` 解析式，不引入采样表、旧 `.labin`、Web/JS runtime 或厂商资源；本批不宣称完整 H11、HDR/OOTF、设备范围或完整迁移。

## 失败契约

新增定向契约后先执行：

```text
swift test -c release --package-path Native/Packages/LUTKit --filter ParameterizedGammaContractsTests
```

在实现前按预期失败：`ParameterizedGammaSettings`、`TransferID.parameterizedGamma`、参数化设置槽位和匹配错误类型均不存在，无法编译。

失败契约要求：

- 参数化 Gamma 必须具有稳定 TransferID，并可进入 `TransformSettings`；
- 输入/输出参数分别持久化，曲线身份与参数槽位必须匹配；
- 缺少所需参数或给非参数化曲线附带参数必须拒绝；
- JSON 编解码后 Double 参数保持一致，`TransformPlan` 必须使用保存的参数而不是固定目录曲线；
- 原生 `.lutcalc` 项目包必须保存并读回参数；旧 schema v1→v2 和旧网页 App JSON 拒绝规则保持不变。

## Swift Double 实现

- 新增可 Codable 的 `ParameterizedGammaSettings`，以 `exponent`、`linearSlope`、`offset`、`linearCut` 和可选 `encodedCut` 保存解析式参数，并复用既有构造校验；
- 新增 `TransferID.parameterizedGamma`；`AlgorithmCatalog` 增加可追溯注册项，内置注册表为 41 条曲线、13 个色域、26 个预设；
- `TransformSettings` 增加 `inputGamma`/`outputGamma` 可选参数槽位和匹配校验；旧项目缺少这两个可选字段时仍可读；
- `TransformPlan` 在初始化时验证参数槽位，并在输入解码/输出编码阶段使用对应 `ParameterizedGammaTransfer`；计划版本为 `parameterized-gamma-settings-v1`；
- `ProjectCodec` 允许这两个原生字段，项目清单缺少必需参数或携带错位参数时返回 `invalidSettings`；
- 更新注册表命令行检查的曲线数量，不改变旧 App JSON 设置迁移已删除的边界。

## 定向结果

- `ParameterizedGammaContractsTests`：6 项通过；覆盖设置 JSON 往返、计划使用保存参数、输入/输出槽位错配拒绝、既有分段边界和非有限值拒绝；
- `ProjectContractsTests`：8 项通过；新增原生 `.lutcalc` 清单保存/重开和缺失参数拒绝；
- `RegistryContractsTests`：16 项通过；注册表来源、唯一性和 41 条曲线计数通过。

## 全量与平台结果

- `swift test -c release --package-path Native/Packages/LUTKit`：`swift test --list-tests` 列出 238 项，Release 全量通过；
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash tools/native-validation/verify-native-release.sh`：原生子集、Swift Release、macOS Release、iOS Simulator Release、iOS generic Release、三个 App 包资源审计均通过；
- 发布证据检查最后仍退出码 `2`，唯一阻塞是缺少真实 `docs/native-validation/full-scope-acceptance.json`，没有创建占位清单；这不是本批失败。

## 证据哈希

- `ParameterizedGammaTransfer.swift`：`95d7e8633f40ab1d60f751449e2fa66db163a90b3af3ec4a152c5f3d93b0d994`；
- `TransformPlan.swift`：`5652386ae2bc79b413b2ef339c1f28b5f235df688927130956ba2eddf7ac19a8`；
- `AlgorithmCatalog.swift`：`6a46c55e08666fdff1844cec0cd161b5c28efc77a009643ce685cafb7dd918ee`；
- `ProjectManifest.swift`：`f9748f0445994387a9fa5abb00da641121928de047d6e5a0db79c6535333f644`；
- `ParameterizedGammaContractsTests.swift`：`cac1ae0b46be5206b78bfa4b6b3e443e118283a3304d0e9e51040f8461de51d0`；
- `ProjectContractsTests.swift`：`2f53487344fe2e5a268e84c8ff8f91218490781817fe443a740ff46a3f6d7157`；
- 全量 Swift 日志 `/tmp/lutcalc-parameterized-gamma-full-swift-20260926.log`：`7a0602bcf8e2ee36e4cac79c3c20fe802c2247940e2b35d66b15cc1243b623dc`；
- Release 入口日志 `/tmp/lutcalc-parameterized-gamma-release-20260926.log`：`0869567a48e6935861c40c30bae8fc4d25706881d341270d4aa5fa6ea8195195`。

## 结论

任意参数化 Gamma 已完成原生参数载体、项目持久化和执行接线的本地可验收子段。仍未完成的 H11 范围包括 HDR/HLG OOTF、显示 EOTF/EDR、真实设备参数、完整旧调节链、相机范围、完整跨色域工作流、真机和发布清单。

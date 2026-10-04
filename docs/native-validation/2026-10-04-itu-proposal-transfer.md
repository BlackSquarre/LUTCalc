# ITU Proposal legacy 传递曲线验收

## 范围

本轮只收口旧 `js/gamma.js` 中已经存在解析式的两个注册：`ITU Proposal (400%)` 与 `ITU Proposal (800%)`。实现使用 Swift `Double` 公式，不加入厂商 LUT、`.labin` 或采样表；不扩展到其他曲线、HDR、ICC、LUTAnalyst 全量、UI 或真机性能。

## 公式与来源

- 来源：`js/gamma.js:LUTGammaITUProp registrations`，旧注册参数分别为 `m=0.12314858` 与 `m=0.083822216783`。
- 线性到 legal：`x > m` 时使用由 `m` 连续拼接的对数肩部；`0.0181 <= x <= m` 使用 `1.0993*x^0.45-0.0993`；更低值使用 `4.5*x`。
- legal 到线性：肩部使用指数逆；`y >= 0.08145` 使用 `((y+0.0993)/1.0993)^(1/0.45)`；更低值使用 `y/4.5`。旧实现的 `0.08145` 分支边界被原样保留，因此正逆在该十进制边界不强行改成完全闭合。
- Rec.2020 data 包装使用 `data = legal*0.85630498533724 + 0.06256109481916`，最终生成路径保持 `Double`。

## 契约与实现

- 新增 `ITUProposalTransfer`、`TransferID.ituProposal400`、`TransferID.ituProposal800`，并接入 `TransformPlan`、`NativeOutputEncoder`、`OutputCodeUnits`、`AlgorithmCatalog`、计划版本和 `LUTReferenceCLI`。
- 新增契约：[ITUProposalTransferContractsTests.swift](../../Native/Packages/LUTKit/Tests/LUTCoreTests/ITUProposalTransferContractsTests.swift)。覆盖 knee 连续性、toe、data 包装、计划／目录区分和非有限输入拒绝。
- 先行契约在旧实现上真实编译失败；实现后 Debug／Release 定向 4 项均通过。

## 独立全网格结果

使用 Python `Decimal`（精度 90）独立重读 Swift 导出的完整 CUBE，覆盖 400%／800% 两个注册及 `17³`、`33³`、`65³` 六个网格。核验脚本为 [verify-itu-proposal-cubes.py](../../tools/native-validation/verify-itu-proposal-cubes.py)，脚本不调用生产 Swift 或 JavaScript。

六个网格均通过 `2e-12` 尺度化误差阈值；核验报告和 CUBE 位于 [验收产物目录](artifacts/2026-10-04-itu-proposal-transfer/)。最大误差为 400% `65³` 的 `2.5368073366341900e-16`；800% `65³` 为 `1.1348612780515286e-16`。

## 编译与回归

- `swift test --package-path Native/Packages/LUTKit -c release`：完整 Swift Release 回归，退出码 `0`，各测试包均 `0 failures`；复跑日志 SHA-256：`986c8a47417b454e882dba0dffbda6495d35e822b509904b3af472522bd22fe7`。
- macOS Release `xcodebuild` 退出码 `0`，日志 SHA-256：`bcc779757e967353b3807ebc35196688b28da5b46cf5822ffcb69a9399f043df`。
- generic iOS Release `xcodebuild` 退出码 `0`，日志 SHA-256：`907a4f662774c848e394a0e7ae43db06dd235043e0c1abd85713d69870ee39c4`。
- generic iOS Simulator Release `xcodebuild` 退出码 `0`，日志含既有 CoreSimulator `Cannot allocate memory` 诊断但未影响构建，SHA-256：`f7e812c3b6f44b3db9a7d85817b84de0f51f3221fb11370d510ae928a0b2d137`。

## 未覆盖与状态

本包只关闭两个 ITU Proposal legacy 解析式注册、计划接线和独立 CUBE 核验。没有关闭 FULL-01 至 FULL-08、H01 至 H14、完整查表替代台账、HDR/EDR/OOTF、ICC 全量、LUTAnalyst 全量、格式目标软件往返、真机性能、签名发布或真实 `full-scope-acceptance.json`。Goal 继续保持 `active`。

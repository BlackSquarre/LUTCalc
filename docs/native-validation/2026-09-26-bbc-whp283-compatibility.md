# BBC WHP283 400%/800% 旧版解析兼容批次

日期：2026-09-26。

本批次接入旧 LUTCalc `js/gamma.js` 中的 `LUTGammaBBC283` 解析式，注册两个固定条目：

- 400%：`m = 0.139401137752`
- 800%：`m = 0.097401889128`

两项均固定 `s = 1`。推导量为 `n = sqrt(m) / 2`、`r = sqrt(m) * (1 - log(sqrt(m)))`、`e = sqrt(m)`。编码严格按 `x > m`、`x > 0` 分支，解码严格按 `y > e` 分支；data wrapper 沿用旧 LUTCalc 的 `0.85630498533724` scale 与 `0.06256109481916` offset。负编码输入按旧实现归零。

由于工作区没有归档的 BBC White Paper 283 或独立公式资料，这两个条目只声明为旧版解析兼容候选，不宣称标准、设备或 OOTF 语义。任意 system gamma 没有加入 `TransferID` 或项目持久化；API 仅接受有限、正值参数供契约测试使用。

## 接入范围

- `BBCWHP283Transfer.swift`：纯 Swift `Double` 解析式与参数校验。
- `TransferID`、`TransformPlan`、`AlgorithmCatalog`：稳定 ID、计划版本、同空间 sRGB 研发预设。
- `LUTReferenceCLI`：`bbc-whp283-400-exposure` 与 `bbc-whp283-800-exposure`。
- 独立 Python CUBE 读回器和批量清单：每个条目覆盖 33³、65³。

## 验证结果

- `BBCWHP283ContractsTests`：严格 m/e 边界、负值策略、data wrapper、非有限参数与往返契约通过。
- `ProPhotoBBCRegistryContractsTests`：注册表和两个预设通过。
- `LUTBBCWHP283Checks`：400%/800% 的 33³、65³ 独立公式读回通过，最大尺度化误差分别为 `0` 与 `5.551115123125783e-17`（门槛 `2e-12`）。
- Python CUBE 独立读回：两个 33³ CLI 输出最大尺度化误差均为 `0`。

## 合并回归

- 合并 CIELAB 前置契约与 WHP283 后，`swift test --list-tests` 为 220 项；Swift Release、macOS Release、iOS Simulator Release、iOS generic Release 和三个 App 包资源审计通过。
- 合并日志：`/tmp/lutcalc-after-cielab-bbc-release-20260926.log`
- SHA-256：`3e27fb64f182de30d69b6c07351028aac01017debb831f1ebfd5e9f2a26bee43`
- 发布入口以退出码 `2` 结束，直接原因仍是缺少真实 `docs/native-validation/full-scope-acceptance.json`；未伪造清单。真机、完整 H11/H04/H08/H09/H12/H13 和发布人工审查继续未完成。

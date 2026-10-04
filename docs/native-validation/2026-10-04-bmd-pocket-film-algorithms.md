# Blackmagic Pocket Film 算法验收记录

日期：2026-10-04

## 范围

本记录只关闭旧 `js/gamma.js` 中 `BMD Pocket Film` 的九参数 `LUTGammaLog` 兼容曲线。它登记为 `blackmagic.pocket-film.lutcalc-legacy.v1`，没有声称 Blackmagic 官方公开曲线，也没有为 Pocket 相机补造色域或默认路由。相机目录中的 `Passthrough` 仍按未定义色域处理。

## 来源与实现

- 来源：`js/gamma.js` 的 `LUTGammaLog` 注册与实际执行，固定源文件 SHA-256 为 `250017d8efe758f3555148ba9fcb923698add0ac7d9380fa290716eb98e0821e`。
- 参数：`0.195367159/0.9`、`-0.014273567/0.9`、`0.36274758`、`1.05345192*0.9`、`0.63659829`、`0.027616437`、decode 分界 `0.096214896`、encode 分界 `0.004523664*0.9`。
- Swift 实现：`BMDPocketFilmTransfer` 只使用 `Double`，拒绝非有限输入；`TransformPlan` 在输入和输出边界各只执行一次旧 legacy↔scene 的 0.9 标度。
- 不新增厂商 LUT、`.labin`、采样数组或等价资源。输出目录仅保存测试生成的 CUBE 与参照日志，不进入 App 资源。

## 契约与独立参照

先冻结旧 JavaScript 的实际执行结果，再运行 `BMDPocketFilmContractsTests` 4 项：

- 九参数 encode/decode 与冻结 JavaScript 结果一致；
- encode/decode 分界相邻值保持旧实现的非连续行为；
- NaN、正负无穷均拒绝；
- TransformPlan 的 legacy↔scene 0.9 边界只适配一次，目录身份、预设和 normalized data 单位分类稳定。

独立 Decimal verifier 为 `tools/native-validation/verify-bmd-pocket-film-cube.py`。它按 `data → legacy decode → 一档曝光 → legacy encode` 的完整计划重算节点，未读取 Swift 输出作为参照。

## CUBE 结果

使用 Release `LUTReferenceCLI` 生成一档曝光预设 `blackmagic.pocket-film-legacy-exposure-one.v1`：

| 网格 | 节点 | 通道 | 最大尺度化误差 | RMS | P99 | 门槛 |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 17³ | 4,913 | 14,739 | `1.099935053888399e-16` | `4.549732822214049e-17` | `1.099935053888399e-16` | `2e-12` |
| 33³ | 35,937 | 107,811 | `1.2130769762582558e-16` | `4.4937312116025596e-17` | `1.2130769762582558e-16` | `2e-12` |
| 65³ | 274,625 | 823,875 | `1.3153340910382913e-16` | `4.384970242683173e-17` | `1.3153340910382913e-16` | `2e-12` |

文件和日志位于 `docs/native-validation/artifacts/2026-10-04-bmd-pocket-film-contracts/`，包括三个 CUBE、三个 verifier JSON、JavaScript 参照 fixture、Release 测试日志和目录检查日志。

## 构建与回归

- 定向 Debug：`swift test --package-path Native/Packages/LUTKit --filter BMDPocketFilmContractsTests`，4 项通过。
- Swift Release：`swift test -c release --package-path Native/Packages/LUTKit`，各测试包合计 706 项通过；LUTFormats 既有外部夹具 2 项按原设计跳过，0 失败。
- 目录检查：`swift run -c release --package-path Native/Packages/LUTKit LUTCatalogChecks`，通过，目录计数为 64 条曲线、20 个色域、60 个预设、66 个相机。

## 尚未关闭

本包不关闭 Blackmagic Pocket 的真实输入色域、官方 Pocket 曲线、Pocket 相机默认路由、DRAGONColor、DJI 查表项、其余 45 个直接查表注册项、9 个 `.labin` 替代、HDR/ICC/LUTAnalyst、平台/UI、目标软件往返、签名发布或真实 `full-scope-acceptance.json`。Goal 继续保持 active。

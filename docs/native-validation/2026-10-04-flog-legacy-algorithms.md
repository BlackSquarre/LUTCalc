# Fujifilm F-Log legacy 算法验收记录

日期：2026-10-04

## 范围

本包只关闭旧 `js/gamma.js` 中 `Fujifilm F-Log` 的九参数 `LUTGammaLog` 兼容路径，登记为 `fujifilm.flog.lutcalc-legacy.v1`。这不是 Fujifilm 官方 F-Log 完整设备模型，也不扩展 F-Log2、F-Gamut C 或相机 shoulder 语义。

## 来源与实现

- 来源：`js/gamma.js:LUTGammaLog Fujifilm F-Log`，源文件 SHA-256 为 `250017d8efe758f3555148ba9fcb923698add0ac7d9380fa290716eb98e0821e`。
- 参数：`0.1144737`、`-0.010630486`、`0.344676`、`0.5000004`、`0.790453`、`0.009468`，decode 分界 `0.100537775`，encode 分界 `0.000988889`。
- Swift 实现只使用 `Double`，拒绝非有限值；`TransformPlan` 在 legacy 与 scene 之间只执行一次 0.9 标度。
- 没有加入厂商 LUT、`.labin`、采样数组或等价资源。

## 契约与参照

`FLogContractsTests` 共 4 项，覆盖冻结 JavaScript 实际执行、分界相邻值、非有限拒绝、目录/预设/normalized data 分类，以及 Fujifilm F-Log 相机的 legacy 路由。

独立 verifier `tools/native-validation/verify-flog-legacy-cube.py` 使用 90 位 Decimal 重算完整一档曝光计划，不读取 Swift 输出作为参照。

## CUBE 结果

| 网格 | 节点 | 通道 | 最大尺度化误差 | RMS | P99 | 门槛 |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 17³ | 4,913 | 14,739 | `1.1801279737198132e-16` | `5.2634534188627335e-17` | `1.1801279737198132e-16` | `2e-12` |
| 33³ | 35,937 | 107,811 | `1.6111701450247143e-16` | `5.4141984377567684e-17` | `1.6111701450247143e-16` | `2e-12` |
| 65³ | 274,625 | 823,875 | `1.637708140187745e-16` | `5.726457111209467e-17` | `1.637708140187745e-16` | `2e-12` |

## 构建与回归

- 定向 Debug：4 项通过。
- Swift Release 全量：LUTSharedUI 162、LUTProject 64、LUTPreview 94、LUTJobs 67、LUTFormats 56（既有外部夹具 2 项跳过）、LUTCore 211、LUTCatalog 24、LUTAnalysis 32，0 失败。
- `LUTCatalogChecks` 通过：65 条曲线、20 个色域、61 个预设、66 个相机。
- macOS、generic iOS、generic iOS Simulator Release 构建通过；160 个 Swift 源码和三个 App 包审计通过。

## 未覆盖

官方 Fujifilm F-Log 定义、完整 F-Gamut 设备模型、F-Log 相机全部行为、DJI/其他查表项、`.labin`、HDR/ICC/LUTAnalyst、第三方往返、UI、File Provider、签名发布和真实 `full-scope-acceptance.json` 仍未完成。Goal 保持 active。

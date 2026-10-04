# RED Log3G10 legacy 算法验收

日期：2026-10-04

## 范围

本包只闭合旧 `js/gamma.js` 注册项 `LUTGammaLogLog RED Log3G10`。实现身份为 `red.log3g10.lutcalc-legacy.v1`，保留参数 `[0.224282, 155.975327, 0.01]`、输入 `0.9` 边界和旧合法数据包装 `0.85630498533724 / 0.06256109481916`。实现位于 `Native/Packages/LUTKit/Sources/LUTCore/REDLog3G10Transfer.swift`，运行时只使用 Swift `Double`、Foundation `log10`/`pow`，不读取旧 JavaScript、LUT 或 `.labin`。

## 契约与参照

先由 `tools/native-validation/generate-red-log3g10-reference.js` 在 Node 18+ 中直接执行旧 `LUTGammaLogLog.linToD/linFromD`，保存参照 `tests/fixtures/native-contracts/red-log3g10-legacy-reference.json`；旧 `js/gamma.js` SHA-256 为 `250017d8efe758f3555148ba9fcb923698add0ac7d9380fa290716eb98e0821e`。`REDLog3G10ContractsTests` 覆盖正值、负值、零、`-0.01/0.9` 边界、合法包装、非有限输入、目录别名和计划身份，并确认 legacy-grey 缩放只应用一次。

## 实际结果

- 定向 Debug：4 项通过。
- Swift Release 全量：8 个测试包分别为 162、64、94、67、56、215、24、32，共 714 项通过，0 失败；LUTFormats 的 2 个既有外部夹具按原设计跳过。
- `LUTCatalogChecks`：66 曲线、20 色域、62 预设通过。
- Release `LUTReferenceCLI` 生成 17³、33³、65³ 同空间一档曝光 CUBE；独立 `verify-red-log3g10-cube.py` 逐节点 Decimal 读回通过，最大通道误差分别为 `1.5418158111277507e-16`、`1.5418158111277507e-16`、`2.271864703803957e-16`，阈值 `3e-15`。
- macOS、generic iOS、generic iOS Simulator Release 构建通过。`audit-native-sources.py` 报告 161 个 Swift 源文件无所列禁止边界；三个实际 App 包资源审计通过。

命令、CUBE、参照、Swift Release 日志和哈希保存在[结果包](artifacts/2026-10-04-red-log3g10-contracts/README.md)。

## 明确未完成

这次只关闭 RED Log3G10 一维 legacy 解析和同空间曝光计划。REDWideGamutRGB 的完整相机模型、DRAGONColor2／Epic DRAGON 默认语义、IPP2 风格输出、HDR/OOTF、ICC、LUTAnalyst、其他查表注册项和 `.labin` 替代仍未完成；UI、真机性能、提供商故障、发布签名及真实 `full-scope-acceptance.json` 也不因本包改变。Goal 继续保持 active。

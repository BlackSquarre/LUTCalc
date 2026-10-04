# H11 ProPhoto / ROMM 与 BBC 参数化 Gamma 子集验收

日期：2026-09-25。状态：子集阶段通过；不代表 H11、CORE-03、FULL-01 或完整迁移完成。

## 范围与来源

本段按旧 `js/gamma.js` 的可追溯解析式接入四个原生 Double 算子：ProPhoto / ROMM 与 BBC 0.4、0.5、0.6。ProPhoto 色域采用 ITU-R BT.2380-0 §2.7 的 RIMM-ROMM 主色坐标与 D50 白点（`js/colourspace.js` 注册也保持一致）；ProPhoto 曲线保留 16 倍低端线性段和 gamma 1.8 幂段。BBC 曲线保留旧 `LUTGammaBBCGam` 的指数、斜率、偏移、分段点及固定 data scale/offset。实现只使用 Swift `Double` 与公式，未打包旧脚本、`.labin` 或等价采样表。

## 先失败后实现

新增 `ProPhotoBBCContractsTests` 前，原生 `TransferID`、`ColorSpaceID`、`TransformPlan` 和目录均没有这些条目，Release 编译按预期失败，日志 `/tmp/lutcalc-prophoto-bbc-red-20260925.log`。随后新增公式、计划接线、色域主色和目录注册，并修正低段边界：ProPhoto `1/1024` 编码为 `1/64`。

## 验证

- `swift test --package-path Native/Packages/LUTKit -c release --filter 'ProPhotoBBCContractsTests|ProPhotoBBCRegistryContractsTests'`
- 结果：LUTCore 5 项公式/逆函数/错误/同空间计划契约通过；LUTCatalog 1 项注册契约通过。
- 日志：`/tmp/lutcalc-prophoto-bbc-targeted-20260925.log`。
- 日志 SHA-256：
  `31a93d825fd679a4b8d40ed9bfbfe434de3337c0a4d7808f1284f2c04f2176b0`

## 边界

本段只覆盖 ProPhoto / ROMM 与 BBC 0.4/0.5/0.6 的标量和同空间最小计划；没有宣称通用参数化 Gamma、CIE L*、BBC WHP283 400%/800%、HDR/OOTF、设备范围、跨色域全链、真机、第三方往返、Files/File Provider 或发布验收。H11 和 Goal 继续保持未完成。

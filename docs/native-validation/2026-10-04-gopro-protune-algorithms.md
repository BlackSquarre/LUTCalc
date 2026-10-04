# GoPro Protune legacy 算法验收

日期：2026-10-04

## 范围与来源

本阶段只闭合旧 `js/gamma.js` 注册项 `Protune` 的一维 `LUTGammaLog` 参数式。参数为 `[0, 0, 876/1023, 53.39427221, 113, 64/1023, 1, 0, 0]`；其中对数底为 113，编码端负值走旧实现的固定 `1e-15` 近零分支。实现使用 Swift `Double`，不携带旧数组、LUT 或 `.labin`。

`Protune Native` 仍是旧相机元数据中的色域名称，缺少可追溯连续原色定义，因此本阶段不新增色域或 GoPro 完整相机默认路由。

## 契约与命令

- `LegacyRegisteredLogTransfer` 新增 `.protune` 变体，显式保留非十进制对数底和零斜率分支。
- 新增 `TransferID.goProProtuneLUTCalcLegacy`、目录描述、同空间一档曝光预设和 CLI 短名 `gopro-protune-legacy-exposure`。
- `LegacyRegisteredLogContractsTests`：3 项通过，覆盖旧 JavaScript 参照、固定近零分支、非有限值、计划边界、目录身份与数据编码分类。
- 旧 JavaScript 仅生成固定 JSON 参照：`tests/fixtures/native-contracts/legacy-registered-log-reference.json`，SHA-256 `aefbc74e837b5adf53ff35bb88070ff9c3510798f990399003f10a499e29885e`。

```sh
swift test -c debug --package-path Native/Packages/LUTKit \
  --filter LegacyRegisteredLogContractsTests
for n in 17 33 65; do
  swift run -c release --package-path Native/Packages/LUTKit LUTReferenceCLI \
    --size "$n" --output "protune-$n.cube" \
    --preset gopro-protune-legacy-exposure
  python3 tools/native-validation/verify-legacy-registered-log-cube.py \
    "protune-$n.cube" protune
done
```

## 独立 Decimal 结果

校验器不调用生产 Swift。最大通道误差：

| 网格 | 通道样本 | 最大绝对误差 | 阈值 |
| ---: | ---: | ---: | ---: |
| 17³ | 14,739 | `1.7094813128803784e-16` | `3e-15` |
| 33³ | 107,811 | `1.7094813128803784e-16` | `3e-15` |
| 65³ | 823,875 | `1.8812006117085657e-16` | `3e-15` |

结果包：

- `protune-17.cube`：`c93d04cf4dbb3be586fd5debe9823352477967477db8f948971b1588e10108d0`
- `protune-33.cube`：`fda32d1a0967d7743bd6e8e9a9d62c05a28cf2b2a04c4842f150bee6a05d95b9`
- `protune-65.cube`：`8ad46b2bd3a7455f7646db3c6941c17aa650f8815419cdc51b1a652bba9f3705`

## 未覆盖范围

本记录不证明 GoPro Protune Native 色域、相机曝光／ISO 行为、HDR、第三方软件往返或完整 GoPro 支持。其余 45 个直接查表注册项、9 个 `.labin` 资源、设备与发布验收继续未完成；Goal 保持 active。

## 回归与平台构建

- Swift Release 全量：8 个测试包共 723 项执行、0 失败、2 项既有可选外部夹具跳过。日志 `/tmp/lutcalc-protune-release-20261004-r2.log`，SHA-256 `612a736e11d8992c8ca0e3daedd9c4b3a4983cf5fcd45b9735ee6a13ba4b0988`。
- `swift run -c release --package-path Native/Packages/LUTKit LUTCatalogChecks`：74 曲线、20 色域、70 预设通过。
- 静态源审计：164 个 Swift 源文件通过。最终使用独立 DerivedData 串行完成 macOS、iOS Simulator、generic iOS Release 构建，三个日志 SHA-256 分别为 `948694eec5ee344a3c00004fccce179a5276e2efd9839cfe0ef57a3299e27812`、`9ead7a8cabcb310ed12c2135b6f462f30cf017817dd321e4431f24ce5c610102`、`069e3bd0f9b02f27b0ebaae1e0ad75ae0730b4dcb15cea893fc77664ba804923`。
- 三个实际 Release App 包资源审计通过，无所列 LUT/脚本文件或 WebKit/JavaScriptCore 直接链接。

这些结果不替代完整设备相机语义、第三方往返、发布签名和真实 `full-scope-acceptance.json`；Goal 仍保持 active。

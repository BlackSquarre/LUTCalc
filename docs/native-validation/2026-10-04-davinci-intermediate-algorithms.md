# DaVinci Intermediate legacy 算法验收

日期：2026-10-04

## 范围

本阶段只闭合旧 LUTCalc 注册项 `DaVinci Intermediate` 的一维 legacy 解析式、Swift `Double` 计划接线和 CUBE 独立读回。实现没有读取或打包 `.cube`、`.labin` 或其他采样表，UI、完整 DaVinci 色彩管理和设备语义不在本阶段范围内。

旧源码来源为 `js/gamma.js` 的 `LUTGammaDaVinci`。保留其参数、分支和合法数据包装：`a=0.0075`、`b=7`、`c=0.07329248`、`m=10.44426855`、`lin_cut=0.00262409`、`log_cut=0.02740668`、`0.9` legacy-grey 缩放、`0.85630498533724` 合法范围比例和 `0.06256109481916` 合法偏移。

## 契约与实现

- `DaVinciIntermediateTransfer.swift` 提供 `encodeLegacyToData` 与 `decodeDataToLegacy`，有限值和溢出均 fail closed。
- `TransformPlan`、`NativeOutputEncoder`、`OutputCodeUnits`、目录描述和 CLI 预设均使用独立的 `TransferID`：`davinci.intermediate.lutcalc-legacy.v1`。
- `DaVinciIntermediateContractsTests` 的 3 项契约覆盖旧 JavaScript 参照、非有限值、零点计划行为、目录身份和数据编码分类。
- 旧 JavaScript 仅用于生成固定参照 JSON，不进入 Swift 运行时。

## 实际命令与结果

工具链：Xcode 27 / SwiftPM，macOS arm64；生产路径为 Swift `Double`。

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  --filter DaVinciIntermediateContractsTests
```

结果：3 项通过，0 失败。参照文件为 `tests/fixtures/native-contracts/davinci-intermediate-legacy-reference.json`。

独立 Decimal 校验器不调用生产 Swift：

```sh
for f in docs/native-validation/artifacts/2026-10-04-davinci-intermediate-contracts/davinci-{17,33,65}.cube; do
  python3 tools/native-validation/verify-davinci-intermediate-cube.py "$f"
done
```

结果：

| 网格 | 通道样本 | 最大绝对误差 | 阈值 |
| ---: | ---: | ---: | ---: |
| 17³ | 14,739 | `1.4311544532104805e-16` | `3e-15` |
| 33³ | 107,811 | `1.9100206717192337e-16` | `3e-15` |
| 65³ | 823,875 | `2.9397408698361883e-16` | `3e-15` |

结果包：

- `artifacts/2026-10-04-davinci-intermediate-contracts/davinci-17.cube`，SHA-256 `ec1eeecd0e8c29625ef3cbcff3c2c5d177f616e45f71014f5c32147b27e136b5`
- `artifacts/2026-10-04-davinci-intermediate-contracts/davinci-33.cube`，SHA-256 `8ac6b07ea77766d84585d764f6281b547bb91bebcbc47548d467a7c3e1d34e58`
- `artifacts/2026-10-04-davinci-intermediate-contracts/davinci-65.cube`，SHA-256 `7db8e1fd0fab60c849d970387e29af7600641abfa9ddf4f79a3d756026587bf9`

## 纠错记录

初版独立校验器把高端公式写成了 `log2(x+a)*c+b`，而旧源码和 Swift 实现实际是 `(log2(x+a)+b)*c`。因此初版 17³/33³/65³ 读回曾出现高端误差；修正校验器后全网格通过。该修正没有改变生产 Swift 算法或阈值。

## 未覆盖范围

本记录不证明 DaVinci Resolve 的完整色彩管理、ACES/显示变换、项目默认路由、设备校准、HDR/OOTF、第三方软件往返或完整旧功能已迁移。其余未闭合算法台账、查表注册项和 `.labin` 资源继续按逐项证据处理；Goal 仍保持 active。

## 回归与平台构建

- `swift test -c release --package-path Native/Packages/LUTKit`：8 个测试包共执行 723 项，0 失败，2 项既有可选外部夹具跳过。完整日志 `/tmp/lutcalc-davinci-release-20261004.log`，SHA-256 `9f383f14363621c5ef068285c03eac90b0ae394dabd075983b7a3409f21f9683`。
- `swift run -c release --package-path Native/Packages/LUTKit LUTCatalogChecks`：73 曲线、20 色域、69 预设通过。
- `python3 tools/native-validation/audit-native-sources.py`：164 个 Swift 源文件边界通过。
- `python3 tools/native-validation/audit-native-bundles.py ...`：临时 DerivedData 中 macOS、iOS Simulator、iOS 三个 Release App 包资源审计通过。
- 使用独立 DerivedData 串行构建：macOS、iOS Simulator、generic iOS 均 `** BUILD SUCCEEDED **`，对应日志 SHA-256 分别为 `699428abbb61d751d7b6ded6b0191fa4fc11b30690dc48f3ec58295eb05a1734`、`5d29796a26f60b16769e14c9eff60eeb4e4415007c47a1312dc00e4bf20024c8`、`eeaec37a84bf58efc7313cde7050f3fafd2aa3493eac9efef9a7e6cd01fc4a14`。

统一发布入口第一次复跑在默认 Xcode DerivedData／CoreSimulator 路径遇到环境级 `Cannot allocate memory` 与 `The file “Xcode” couldn’t be saved in the folder “Developer”`，退出 74；随后独立 DerivedData 串行三端构建均通过。真实 `full-scope-acceptance.json` 仍缺失，因此不伪造发布清单，也不把发布入口标记为全量通过。

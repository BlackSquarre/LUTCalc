# 2026-10-05 BT.2100 HLG reference OOTF extended gamma 项目持久化验收

## 范围

本轮只把已经通过独立公式验收的 `BT2100HLGReferenceOOTF.GammaMode.extended` 接入项目清单。新增字段使用 schema `27`，不新增 UI、默认路由或新的 HDR 变体；`Goal` 继续保持 `active`。

## 实现与契约

- `Native/Packages/LUTKit/Sources/LUTCore/HLGOOTF.swift`：`HLGOOTFSettings` 增加可选 `referenceGammaMode`；只有 `bt2100.hlg-reference-ootf.v1` 可以建立 reference kernel，legacy HLG 携带该字段时拒绝。
- `Native/Packages/LUTKit/Sources/LUTProject/ProjectManifest.swift`：当前 schema 从 `26` 升至 `27`；schema 27 才允许 `settings.hlgOOTF.referenceGammaMode`，严格字段白名单同步更新；schema 26 及更早版本携带该字段时拒绝。
- `Native/Packages/LUTKit/Tests/LUTProjectTests/HLGOOTFProjectContractsTests.swift`：新增扩展 gamma 项目往返、旧 schema 拒绝和 legacy 算法拒绝契约。测试样例使用输入／输出均为 `10000 cd/m²`，符合 reference 路由要求的相同峰值边界。

## 实际命令与结果

工具链：Xcode `27.0 (27A266a)`、Swift `6.4`、Apple Silicon macOS。

```sh
swift test --package-path Native/Packages/LUTKit -c debug \
  --filter 'HLGOOTFProjectContractsTests|BT2100HLGReferenceOOTFContractsTests'
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'HLGOOTFProjectContractsTests|BT2100HLGReferenceOOTFContractsTests'
swift test --package-path Native/Packages/LUTKit -c release
Scripts/verify-native-numerics.sh
```

- 定向 Debug／Release：各 9 项执行，0 失败。
- 完整 Swift Release：8 个测试包共 896 项执行，0 失败；`LUTFormats` 2 项既有外部夹具按既定规则跳过。
- 原生数值门禁：退出码 `0`；66 项静态／公式检查、Node 契约、Swift 命令行检查、格式生成／读回和项目／任务检查均通过。

结果包：`docs/native-validation/artifacts/2026-10-05-hlg-reference-ootf-extended-project/`。

| 文件 | SHA-256 |
| --- | --- |
| `targeted-debug.log` | `357957e644ccc37b6bc019b51c4a80e601255ef93dc468fb0e4a5ebe1cc238c9` |
| `targeted-release.log` | `ed17f6bd9a1964b6962b52c3c3e89459eb4dd19902a5e908216ee9c6e7adebba` |
| `full-release.log` | `7ae7ab13f0abfbc7919726d6796c96c48cdfdaf0f85654481bf6a0b2c1ccb6ba` |
| `numerics-gate.log` | `ef6a6a05790db1bc99a6c883d28b8596f7626e1c8e297db9d0f7aec3fc3ff41e` |
| 所有 `.exitcode` 文件 | `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa` |

## 未覆盖范围

本轮不关闭自动峰值选择、参考白／黑位策略、四种完整 HDR 变体、标准 PQ OOTF、完整 HDR/EDR 显示路径、真实显示设备、UI、iPadOS、多窗口、File Provider/iCloud、第三方软件往返、性能、签名发布、`9/9` `.labin`、`45/45` 直接查表注册、完整 ICC、LUTAnalyst 任意三维反求或真实 `full-scope-acceptance.json`。已有扩展 gamma 数学证据见[扩展 gamma 数学子集验收](2026-10-05-hlg-reference-ootf-extended.md)。

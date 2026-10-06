# 2026-10-05 BT.2100 HLG reference OOTF 扩展 gamma 数学子集验收

## 范围与来源

本包在 `bt2100.hlg-reference-ootf.v1` 的标量/RGB OOTF 之上，补齐 BT.2100-3 (02/2025) Note 5f 的 extended system gamma 公式。实现仍是纯 Swift `Double`，算法身份为 `bt2100.hlg-reference-ootf-extended.v1`；不读取旧 JavaScript、`.labin`、厂商 LUT 或等价采样表。

扩展模式必须由调用方显式选择，不能根据峰值亮度自动推断。默认初始化器继续只接受通常制作范围 `400...2000 cd/m²`；扩展初始化器接受有限正峰值，但不改变现有项目 schema、默认路由或 UI。

## 公式与边界

```text
gamma = 1.2 * 1.111 ^ log2(L_W / 1000)
F_D   = L_W * Y_S^(gamma - 1) * E
```

标量路径使用 `F_D = L_W * scene^gamma`，RGB 路径仍按 BT.2100 原色权重先求 `Y_S`，然后对三个分量使用同一耦合尺度。负色度分量和既有 reference OOTF 语义保持一致；本包只验证 extended gamma，不扩大黑位、自动峰值或 HDR 显示策略。

## 先行契约与独立参照

- 源码：`Native/Packages/LUTKit/Sources/LUTCore/BT2100HLGReferenceOOTF.swift`
- 契约：`Native/Packages/LUTKit/Tests/LUTCoreTests/BT2100HLGReferenceOOTFExtendedContractsTests.swift`
- 参照生成器：`tools/native-validation/probe-hlg-reference-ootf-extended.py`
- 结果包：`docs/native-validation/artifacts/2026-10-05-hlg-reference-ootf-extended/`

契约覆盖默认模式对非通常峰值的拒绝、显式 extended 模式、`L_W=100` 与 `10000` 的公式锚点、非正/非有限峰值拒绝，以及多组峰值和 scene 的 90 位 `Decimal` 独立参照。另覆盖 extended gamma 下的黑位抬升、负 PLUGE 头房、标量逆、RGB 亮度耦合和高低峰值交叉路径。OOTF 独立参照最大尺度化误差为 `4.974256639474225e-16`，EOTF 交叉参照最大尺度化误差为 `7.771561172376096e-16`。

## 实际命令与结果

工具链：Xcode 27.0（27A266a）、Swift 6.4、Python 3.14.6、Node 22.21.0、macOS arm64。

```sh
python3 -m py_compile tools/native-validation/probe-hlg-reference-ootf-extended.py
python3 tools/native-validation/probe-hlg-reference-ootf-extended.py \
  > docs/native-validation/artifacts/2026-10-05-hlg-reference-ootf-extended/decimal-reference.json
swift test --package-path Native/Packages/LUTKit -c debug \
  --filter BT2100HLGReferenceOOTFExtendedContractsTests
swift test --package-path Native/Packages/LUTKit -c release \
  --filter BT2100HLGReferenceOOTFExtendedContractsTests
Scripts/verify-native-fast.sh
Scripts/verify-native-numerics.sh
```

扩展定向 Debug/Release 各 4 项通过；与既有 OOTF 定向契约合计各 10 项通过。快速门禁和原生数值门禁均退出码 `0`，结果包中的所有 `.exitcode` 均为 `0`。

结果包 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `decimal-reference.json` | `e6459b7e8a2d4d7075ed0e5eed14711b05e579dbcaed4d6149b94b39db3b5d28` |
| `targeted-debug.log` | `3817ede300351120e6b5a8b1c000a9b6337d206938c1474200ef1a5a0456c697` |
| `targeted-release.log` | `e8ef6b525366b783bfa48eea65573d723c6983450c198e8eb39136706ae77e38` |
| `fast-gate.log` | `67c57706698987403fa9b9c26bb1a1ab7ab58eae2126f2f3a01846d9f0866bf1` |
| `numerics-gate.log` | `dba2883b4e861a4183712cf7f6be1cb5f3853ab4a113d0b9d3cc301b4cb2b166` |

## 未覆盖范围

本包只关闭 extended system gamma 的公式、显式模式和数值参照，并交叉验证该模式下的 reference EOTF。自动峰值选择、项目参考白/黑位策略、四种完整 HDR 变体、标准 PQ OOTF、完整 HDR/EDR 显示路径、真实显示设备和默认路由仍未完成。`9/9` `.labin`、`45/45` 直接查表注册、完整 ICC、LUTAnalyst 任意三维反求、相机模型、平台交互、性能与签名发布以及真实 `full-scope-acceptance.json` 仍未完成；Goal 保持 `active`。

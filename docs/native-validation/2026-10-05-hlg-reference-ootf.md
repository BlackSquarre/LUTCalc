# 2026-10-05 BT.2100 HLG reference OOTF 数学子集验收

## 范围与来源

本包新增独立的纯 Swift `Double` 内核 `BT2100HLGReferenceOOTF`，算法身份为
`bt2100.hlg-reference-ootf.v1`。来源为仓库保存的
`research/colour/2026-09-24/itu-bt2100-3-2025.pdf`，依据 BT.2100-3 (02/2025)
Table 5 与 Note 5f。它描述归一化 scene-linear RGB 的参考 OOTF：场景白为
`1.0`，输出单位为 `cd/m²`，峰值范围只接受 `400...2000 cd/m²`。

本内核与历史 `HLGOOTF` 保持独立。历史类型仍保留 LUTCalc 的 `0...12` 场景约定、黑位、BBC 和峰值裁切语义；本包没有替换它。`bt2100.hlg-reference-ootf.v1` 已通过显式设置接入 `TransformPlan`：stage 130 使用参考 RGB OOTF，stage 13 在调用 HLG OETF 前把 nits 除以 `1000`。现有项目 schema 22 已支持该算法身份、nits 单位和严格参数往返；尚未新增 schema 版本、默认路由或 UI。通常范围之外的 Note 5f extended gamma 已作为独立显式数学模式验收，见[扩展 gamma 验收](2026-10-05-hlg-reference-ootf-extended.md)，尚未接入项目默认策略。

## 公式与边界

系统 gamma 和参考 OOTF 按以下公式计算：

```text
gamma = 1.2 + 0.42 * log10(L_W / 1000)
F_D   = L_W * Y_S^(gamma - 1) * E
```

其中 `L_W` 为显示峰值，`Y_S` 为场景亮度，`E` 为场景 RGB 分量。RGB 路径先用 BT.2100 原色权重 `0.2627/0.6780/0.0593` 求 `Y_S`，再按同一尺度耦合三个分量；负的色度分量可以保留，但场景亮度必须非负。零亮度的非唯一逆值明确拒绝。实现不执行峰值裁切。

## 先行契约与独立参照

- 源码：`Native/Packages/LUTKit/Sources/LUTCore/BT2100HLGReferenceOOTF.swift`
- 契约：`Native/Packages/LUTKit/Tests/LUTCoreTests/BT2100HLGReferenceOOTFContractsTests.swift`
- 参照生成器：`tools/native-validation/probe-hlg-reference-ootf.py`
- 结果包：`docs/native-validation/artifacts/2026-10-05-hlg-reference-ootf/decimal-reference.json`

契约覆盖 `L_W=1000` 的标准锚点、标量正逆、RGB 亮度耦合、负色度分量、非法峰值和输入、零亮度非唯一逆、`TransformPlan` stage 130 路由、stage 13 nits 归一化、normalized scale 拒绝、历史黑位/BBC/峰值不一致拒绝以及 90 位独立 `Decimal` 参照。`L_W=1000` 时 `gamma=1.2`，`scene=0.18` 输出 `127.74002773725992 cd/m²`。

独立参照最大尺度化误差为：标量 `1.1102230246251565e-16`，RGB `1.3342336993997586e-16`；契约门槛为 `3e-14`。没有降低网格、位宽、插值规则或项目既有误差阈值。

## 实际命令与结果

工具链：Xcode 27.0（27A266a）、Swift 6.4、Python 3.14.6、Node 22.21.0、macOS arm64。

```sh
python3 -m py_compile tools/native-validation/probe-hlg-reference-ootf.py
python3 tools/native-validation/probe-hlg-reference-ootf.py \
  > docs/native-validation/artifacts/2026-10-05-hlg-reference-ootf/decimal-reference.json
swift test --package-path Native/Packages/LUTKit -c debug \
  --filter BT2100HLGReferenceOOTFContractsTests
swift test --package-path Native/Packages/LUTKit -c release \
  --filter BT2100HLGReferenceOOTFContractsTests
swift test --package-path Native/Packages/LUTKit -c debug \
  --filter HLGOOTFProjectContractsTests
swift test --package-path Native/Packages/LUTKit -c release \
  --filter HLGOOTFProjectContractsTests
swift test --package-path Native/Packages/LUTKit -c release --parallel
Scripts/verify-native-numerics.sh
```

Debug 和 Release 定向算法契约各 6 项通过；项目 schema 22 定向 Debug／Release 各 2 项通过。当前源码完整 Swift Release 实际执行 872 项、0 失败，退出码为 `0`。原生数值门禁的静态、Node、Swift 命令行、公式和 54 个 CUBE 生成／读回对共 66 项全部通过，退出码为 `0`。

结果包 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `decimal-reference.json` | `f264184509ab00b20d5452968823f7a8e4ae01f3887801c2ad20d79fe0a6597d` |
| `targeted-debug.log` | `dd45890f3df7615af420693a059efff2fc455421c0387a5c11b85f62363001ab` |
| `targeted-debug.exitcode` | `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94c94f6f3fe3ab86aa` |
| `targeted-release.log` | `879ef0d65daa98b841031099de13f735c5c2fa10193b0eb682add6b139cb7fa1` |
| `targeted-release.exitcode` | `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94c94f6f3fe3ab86aa` |
| `full-release.log` | `b6639e15338d09777499128a429cd36b2a2fca768eff946ab43050a101f7a7d7` |
| `full-release.exitcode` | `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94c94f6f3fe3ab86aa` |
| `project-targeted-debug.log` | `668fc317fafaac4b00ec762f3525094d05cf9d19923ba38866cb13fa0ca70884` |
| `project-targeted-debug.exitcode` | `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94c94f6f3fe3ab86aa` |
| `project-full-release.log` | `4054b3aecb9420cf6a785e47df04fc5314b2d3960ad8052257ff4f2f6611700f` |
| `project-full-release.exitcode` | `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94c94f6f3fe3ab86aa` |
| `native-numerics-gate-rerun.log` | `6153c11b1f6d5ad12c67ac2380e15d87bbf246bf60efcde941366fe783f3ce28` |
| `native-numerics-gate-rerun.exitcode` | `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94c94f6f3fe3ab86aa` |
| `native-numerics-gate.log` | `f55eacc129c970aeddbdd8484a1a01d226d855775ebbd927a1bddb49e45bf1f4` |
| `native-numerics-gate.exitcode` | `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94c94f6f3fe3ab86aa` |

## 未覆盖范围

本包关闭 BT.2100 HLG reference OOTF 的标量／RGB 数学子集、`TransformPlan` 显式路由、单位边界和 schema 22 严格往返子集。自动峰值、参考白／黑位策略、四种 HDR 变体、PQ OOTF、完整 HDR/EDR 显示路径、峰值裁切统计、真实显示设备、默认路由和跨软件参照仍未完成。历史 `HLGOOTF` 与本内核的语义差异继续由算法枚举和参数拒绝保持隔离。

9 个 `.labin`、45 个直接查表注册、完整 ICC、LUTAnalyst 任意三维反求、相机模型、平台故障恢复、签名发布和 `full-scope-acceptance.json` 仍保持未完成；Goal 继续为 `active`。

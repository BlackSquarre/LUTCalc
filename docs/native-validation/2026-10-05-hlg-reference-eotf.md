# 2026-10-05 BT.2100 HLG reference EOTF 黑位抬升数学子集验收

## 范围与来源

本包补齐 `bt2100.hlg-reference-ootf.v1` 的 BT.2100-3 reference EOTF 黑位抬升子集。来源是仓库保存的 ITU-R BT.2100-3 (02/2025)，依据 Table 5、Note 5f、Note 5h 和 Note 5i。实现仍是纯 Swift `Double`，不读取旧 LUT、`.labin` 或采样表。

本包只扩展已经验收的 reference OOTF，不改变历史 `HLGOOTF` 的场景范围、BBC、峰值裁切或项目默认路由。黑位参数通过显式调用传入，尚未把黑位策略接入默认项目设置或 UI。

## 公式和边界

```text
beta = sqrt(3) * (LB / LW)^(1 / gamma)
FD   = OOTF[OETF^-1[max(0, (1 - beta) * E' + beta)]]
gamma = 1.2 + 0.42 * log10(LW / 1000)
```

标量路径以 `LW` 为峰值 nits、`LB` 为黑位 nits；RGB 路径先逐通道执行黑位抬升和 HLG 逆 OETF，再用 BT.2100 原色权重 `0.2627/0.6780/0.0593` 执行参考 OOTF 的亮度耦合。

`E'=0` 的显示值是 `LB²/LW`，不是显示黑位本身。BT.2100-3 Note 5h 允许负 `E'` 作为 PLUGE 和处理头房，因此该锚点以下的正显示值仍可唯一逆回负编码；`FD<=0` 才拒绝为非唯一或域外逆。`max(0, ...)` 折叠出的零显示值不能被逆解。

## 契约和独立参照

- 实现：[BT2100HLGReferenceOOTF.swift](../../Native/Packages/LUTKit/Sources/LUTCore/BT2100HLGReferenceOOTF.swift)
- 契约：[BT2100HLGReferenceEOTFContractsTests.swift](../../Native/Packages/LUTKit/Tests/LUTCoreTests/BT2100HLGReferenceEOTFContractsTests.swift)
- 独立 90 位参照：[probe-hlg-reference-eotf.py](../../tools/native-validation/probe-hlg-reference-eotf.py)
- 结果目录：[2026-10-05-hlg-reference-eotf](artifacts/2026-10-05-hlg-reference-eotf/)

契约覆盖 `LW=1000`、`LB=10` 的 `beta`、黑位锚点、编码 `-0.01/0/0.1/0.5/0.75/1`、负头房标量逆、零显示非唯一拒绝、RGB 逐通道边界、RGB 亮度耦合、非有限输入和非法黑位。Swift 结果与 90 位 `Decimal` 参照的已记录锚点包括：

- `beta = 0.0373159034472412803155032867...`
- `E'=0 -> 0.1 cd/m²`
- `E'=-0.01 -> 0.0488645943108462073... cd/m²`
- `E'=0.5 -> 55.5195514385478952... cd/m²`
- RGB `(0.5,0.75,0.25) -> (66.0089300293989493..., 204.0594649614117786..., 18.9158224243948848...) cd/m²`

独立参照没有降低网格、位宽、插值规则或既有误差阈值；它只验证解析公式和边界域。

## 实际命令与结果

工具链：Xcode 27.0、Swift 6.4、Python 3.14.6、Node 22.21.0、macOS arm64。

```sh
python3 -m py_compile tools/native-validation/probe-hlg-reference-eotf.py
python3 tools/native-validation/probe-hlg-reference-eotf.py \
  > docs/native-validation/artifacts/2026-10-05-hlg-reference-eotf/decimal-reference.json
swift test --package-path Native/Packages/LUTKit -c debug \
  --filter BT2100HLGReferenceEOTFContractsTests
swift test --package-path Native/Packages/LUTKit -c release \
  --filter BT2100HLGReferenceEOTFContractsTests
Scripts/verify-native-fast.sh
Scripts/verify-native-numerics.sh
```

结果：Debug 定向 6/6、Release 定向 6/6；快速入口退出码 `0`（Swift Release 和 Node 11 项）；原生数值入口退出码 `0`（静态、Node、Swift 命令行、公式和 54 个 CUBE 生成/读回对）。本包没有把发布入口的缺失 `full-scope-acceptance.json` 伪造成通过。

结果包 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `decimal-reference.json` | `f2ff907ce84a8ae1305ef15e127581d4b51817ae47d84abcc64c0522de2c5dbf` |
| `targeted-debug.log` | `387c4fa41b4888df91e9688d682beef132e90bb5c2327413ad6897c9a779d525` |
| `targeted-release.log` | `63527318f7310c06b1bc0612f91bb213007175feb100b4fe61b7671d99659033` |
| `fast-gate.log` | `f0a285287237133d597c1e50577d8f74add5cf9ddab611819c2f1bb20f9f3735` |
| `numerics-gate.log` | `620301b4a3271df1fa9c04a418621d4c62a61d53cf98f921e15d39df196610f1` |

所有对应 `.exitcode` 文件为 `0`，其哈希为 `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94c94f6f3fe3ab86aa`。

## 仍未覆盖

本包关闭 reference HLG EOTF 的黑位抬升标量/RGB 解析数学和逆向唯一域，不等于完整 HDR。自动峰值、参考白/黑位项目策略、扩展 gamma 范围、四种旧 HDR 变体、标准 PQ OOTF、完整 HDR/EDR 显示路径、峰值裁切统计、真实 HDR 设备和跨软件往返仍未完成。`.labin` 仍为 `0/9` 替代，直接查表注册仍为 `0/45`，LUTAnalyst 任意三维反求、UI、真机性能、签名发布和真实全量清单也未完成；Goal 保持 `active`。

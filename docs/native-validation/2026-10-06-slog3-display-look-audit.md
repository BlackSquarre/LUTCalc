# S-Log3 后显示查表等价性审计

## 范围

本轮审计 10 个旧 `LUTGammaLUTSL3` 输出注册：Amira709、Alexa-X-2、LC709A、
LC709、Sony Cine+709、Varicam V709、REDGamma、REDGamma2、REDGamma3、
REDGamma4。全部注册共享旧 S-Log3 解码桥接，再由各自 64/65 点样条产生
显示 look。没有搬运节点或新增生产 transfer。

## 公开来源与数值参照

通用 Sony S-Log3 的公开公式只定义场景／编码传递函数，不定义 ARRI、Sony、
Panasonic 或 RED 的后续 display rendering。Rec.709 OETF 与 BT.1886 EOTF
分别定义不同信号环节，也不能推出这些厂商 look 的肩部、黑位、色彩映射或
设备版本。仓库 `.labin` 夹具审计已指出对应 Sony/ARRI/Panasonic 输出变换
仍缺连续定义和非灰轴参照；REDGamma 版本也缺 RED 官方版本化 display
transform 公式与独立参照。

从旧共同 S-Log3 bridge 的 scene 输入 `0.18` 执行每个旧输出样条，得到：

| 注册 | 旧样条输出 | Rec.709 OETF |
|---|---:|---:|
| Amira709 | 0.3872661761 | 0.4090077289 |
| Alexa-X-2 | 0.3851997656 | 0.4090077289 |
| LC709A | 0.3862313968 | 0.4090077289 |
| LC709 | 0.3853188637 | 0.4090077289 |
| Sony Cine+709 | 0.4503219941 | 0.4090077289 |
| Varicam V709 | 0.4047634802 | 0.4090077289 |
| REDGamma | 0.4004958062 | 0.4090077289 |
| REDGamma2 | 0.4032963392 | 0.4090077289 |
| REDGamma3 | 0.4263468125 | 0.4090077289 |
| REDGamma4 | 0.4261675505 | 0.4090077289 |

有限灰轴样本仅证明这些输出并不等于 Rec.709；不能用这些节点或其他有限
样本拟合连续公式，更不能证明非灰轴行为、机型、固件或色彩矩阵语义。

## 失败契约与命令

新增 `RegistryContractsTests/testSLog3DisplayLookupsCannotAliasPublishedTransfers`，
逐项确认 10 个名称不能解析为 transfer、色域或预设，同时确认独立 S-Log3、
Rec.709 legacy 和 BT.1886 身份仍然存在。

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter RegistryContractsTests/testSLog3DisplayLookupsCannotAliasPublishedTransfers
```

Release 执行 1 项、0 失败；工具链 Xcode 27 / Swift 6，macOS arm64。结果包：
`docs/native-validation/artifacts/2026-10-06-slog3-display-look-audit/release.log`；
SHA-256：`6a4f8b308d865f52da2f20fefa6adb1a3e2fb97c5d1bbc8eb44eb34e273996cc`。

## 结论

10 项仍属于直接查表阻塞，不能由通用 S-Log3、Rec.709 或 BT.1886 安全替代。
直接查表替代保持 `0/45`。后续需获得各厂商连续显示变换、适用机型／版本、
非灰轴定义和独立 17³/33³/65³ 参照后再评估。Goal 保持 `active`。


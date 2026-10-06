# Sony STD1/STD2/STD3/STD6 查表等价性审计

## 范围

本轮复核四个旧 `LUTGammaLUTSimple` 注册：`Sony STD1`、`Sony STD2 - x4.5`、
`Sony STD3 - x3.5`、`Sony STD6 - x5`。没有复制旧 17 点样条，也没有把
名称映射到任何公开 transfer。

## 最小数值对照

旧实现先按各自 `clip=4`、`loggy` 参数执行 SimpleLog，再对注册样条求值。
在相同 scene 输入下，旧结果与公开 Rec.709 OETF、BT.1886 γ2.4 明显不同：

| 注册 | scene 0.18 旧值 | Rec.709 OETF | BT.1886 γ2.4 | scene 1.0 旧值 |
|---|---:|---:|---:|---:|
| STD1 | 0.2401697336 | 0.4090077289 | 0.0163175147 | 0.7673692728 |
| STD2 - x4.5 | 0.3039805131 | 0.4090077289 | 0.0163175147 | 0.7751805658 |
| STD3 - x3.5 | 0.2293122862 | 0.4090077289 | 0.0163175147 | 0.7399768369 |
| STD6 - x5 | 0.2797661766 | 0.4090077289 | 0.0163175147 | 0.7555840572 |

四条曲线彼此也不相同；`x4.5`、`x3.5`、`x5` 是历史 look 标记，不是足以
确定连续 gamma、黑位、白位、范围或设备版本的公开公式。固定 Legal/Data
包装也不能消除这些差异。

## 失败契约

新增 `RegistryContractsTests/testSonyStdLookupsCannotAliasPublishedTransfers`，
Release 执行 1 项、0 失败。契约确认四个名称均不能解析为 transfer、色域或
预设，独立的 Rec.709 legacy 与 BT.1886 身份仍保持分离。

实际命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter RegistryContractsTests/testSonyStdLookupsCannotAliasPublishedTransfers
```

结果包：`docs/native-validation/artifacts/2026-10-06-sony-std-look-audit/release.log`；
SHA-256：`302406c4d5853ad469d10802c9e8accbd4060ef8449af2714049f1128fb20a46`。

## 结论

四项仍属于直接查表阻塞，不能由公开 Rec.709、BT.1886 或常规 gamma 推导。
直接查表替代保持 `0/45`；需取得 Sony 官方连续定义、范围／设备语义和独立
17³/33³/65³ 参照后再评估实现。Goal 保持 `active`。


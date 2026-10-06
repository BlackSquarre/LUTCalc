# 2026-10-06 `.labin` 与直接查表替代边界复核

## 范围

本轮只审计内置旧 `.labin` 资源和直接查表注册，目标是寻找一个同时具备公开连续公式、适用范围明确、非灰轴语义可说明、独立参照可构造的最小闭合子集。用户主动导入 `.labin`/LUT 的解析、量化读写和反求路径不在内置替代范围内。

## 复核结果

- 9 个 `.labin`（Sony LC709/LC709A/s709/Cine709、ARRI Amira709/Alexa-X-2、Panasonic V709、Canon CP IDT Daylight/Tungsten）仍只有旧资源身份或采样行为；缺少可追溯的连续定义、版本化设备范围和独立非灰轴参照。
- 45 个直接查表注册仍分为 DJI DLog-M、输入/输出查表、S-Log3 后显示查表、SimpleLog 后查表四类。通用 S-Log3、SimpleLog、SMPTE 240M 或已实现的 DJI D-Log2 不能推出 Sony、ARRI、Canon、RED、Panasonic 显示变换，也不能推出 Nikon/Canon picture style。
- 将旧数组改写为 Swift 常量、压缩文本、Base64、纹理或拟合多项式仍是等价内置采样数据，违反迁移约束；本轮没有新增生产算法、目录身份或采样数据。

## 研发资产指纹与最小复现

当前工作区中可见的九个旧资源仍只作为研发夹具，未被 `Native/Packages/LUTKit` 的 SwiftPM target 声明为资源。为便于后续复核，记录文件长度和 SHA-256：

| 资源 | 字节数 | SHA-256 |
| --- | ---: | --- |
| `LC709.labin` | 3295968 | `085a80e939a33430cc622cd7847d31bbd05024e173388a768568a96b451a88fb` |
| `AlexaX2.labin` | 431724 | `2d04eb19780ab0a91899ea98c4ce6e1430075d5e67636b2f675b6532d56ebdc7` |
| `Amira709.labin` | 431720 | `218a3b5432b180bb5aafbc614385d34a7a9e1c9480f98a45ffc643965abbb9be` |
| `Cine709.labin` | 431712 | `b2c398048bcdea7a7bb06c56f41f122d822cf822fb0342ea1a193ea7c4402093` |
| `LC709A.labin` | 431712 | `2effa330c4df7dda5d13a135f7dc4d7c1930c24a6d9d8f7e999cba187188b76c` |
| `V709.labin` | 431720 | `f835bcb68766a119f11af2ba74c186088c6541e79db4fb992abe9439f887c48` |
| `cpoutdaylight.labin` | 431708 | `551e41b3c03edbd21d09f514865515b932c4bff581b759d313996fade0bd4dcf` |
| `cpouttungsten.labin` | 431708 | `335f68f5650db368b25f2971e5127336a0ff826a488051ee86954efc4b25afb7` |
| `s709.labin` | 431716 | `c0d4de697358f9520b7338d4b64b8904878397a20708def4c58eee05e777e8d1` |

最小复现命令为 `find . -iname '*.labin' -print`、`wc -c < file` 和 `shasum -a 256 file`。这些指纹只证明现有研发资产的身份，不证明其厂商来源、连续定义或适用机型；在获得官方公式、版本范围、非灰轴说明和独立网格参照前，不能据此生成 Swift 算法。

## 契约与命令

`AlgorithmCatalog.blockedLookupRegistrationNames` 继续冻结 45 个名称，并逐项确认 `transfer(named:)`、`colorSpace(named:)`、`preset(named:)` 均为空。定向 Release 命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter RegistryContractsTests/testBlockedLookupRegistrationsHaveNoNativeCatalogIdentity
```

结果：执行 1 项、失败 0；工具链为 Xcode 27 / Swift 6、macOS arm64。日志 `/tmp/lutcalc-labin-lookup-boundary-release-20261006.log`，SHA-256：`64fad2244d0def721df396209b131bcbdbf3f13308c348bea1e3185d61c8c20d`。命令曾等待另一项完整回归释放同一 `.build` 锁，随后完成构建和测试，没有并行复用构建目录。

## 结论与后续条件

本轮没有满足闭合条件的最小子集；`.labin` 替代保持 `0/9`，直接查表替代保持 `0/45`。任一条目只有在取得官方连续公式、适用机型/版本、非灰轴语义和独立 17³/33³/65³ 参照后，才可先加入失败契约，再实现 Swift `Double` 路径并更新台账。Goal 继续 `active`。

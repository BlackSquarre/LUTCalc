# Sony STD4/STD5 直接查表失败契约验收

## 范围

本轮只检查 `Sony STD4 - SMPTE240M` 与 `Sony STD5 - Rec709` 两个旧
`LUTGammaLUTSimple` 注册，判断它们能否被公开标量传递函数安全替代。没有把
旧样条控制点写入 Swift，也没有改变 45 项查表阻塞台账。

## 独立参照与最小复现

- SMPTE 240M 连续 OETF 参照：ITU-R BT.2380-0 section 2.3，原生实现为
  `SMPTE240MTransfer`，分段参数为 `0.0228`、`1.1115`、`0.45`、`0.1115`。
- Rec.709 原生目录身份是 LUTCalc 历史 `Rec709Transfer`，不能把 Sony 的
  SimpleLog 后显示样条名称当成该标量 transfer 的别名。
- 旧注册的行为来自 `js/gamma.js:LUTGammaLUTSimple`：先执行 SimpleLog
  归一化，再对 17 点样条做三次插值；该行为还包含 `clip`、`loggy` 与固定
  Legal 包装，和独立 SMPTE 240M OETF 的输入域并不相同。

用旧注册的首个公开样本和同一 `SimpleLog` 参数反解得到的 scene 值做最小
对照，STD4 的首个样本约为 `0.08797654`，将该 scene 值代入 SMPTE 240M
连续 OETF 得到约 `0.171338`；STD5 首个样本同样为 `0.08797654`，其
SMPTE 240M 结果约为 `0.173850`。这不是实现参照，只证明“STD4/STD5
名称 = SMPTE 240M 标量 OETF”的替换假设与旧行为不等价。完整非灰轴语义、
机型／固件范围和独立 17³/33³/65³ 参照仍缺失。

## 失败契约

`RegistryContractsTests/testSonyStdLookupNamesCannotAliasPublishedScalarTransfers`
在 Swift Release 下通过（1 项，0 失败）。契约逐项确认：

1. 两个 Sony STD 名称不能解析为 transfer、色域或预设；
2. `SMPTE 240M` 仍解析为独立 `.smpte240M`；
3. `Rec.709 (LUTCalc legacy)` 仍解析为独立 `.rec709LUTCalcLegacy`；
4. 目录不会因新增别名而把厂商查表误报为公开公式。

实际命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter RegistryContractsTests/testSonyStdLookupNamesCannotAliasPublishedScalarTransfers
```

工具链为 Xcode 27 / Swift 6，macOS arm64；退出码 `0`。

## 结论

该失败契约关闭了 Sony STD4/STD5 被标准 OETF 误注册的回归风险，但没有关闭
任何直接查表替代项：两项仍计入 `0/45`。只有取得 Sony 官方连续定义、适用
版本／机型、非灰轴语义和独立网格参照后，才能重新打开实现评估。


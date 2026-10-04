# 2026-10-03 HLG OOTF RGB 黑位端点非 UI 验收

## 范围

本阶段修复 HLG 显示 OOTF RGB 逆变换在非零黑位和 `gamma < 1` 时的端点问题，并补齐输入／输出两侧、nits／归一化标度和多个峰值的端点契约。没有执行 UI、屏幕 HDR/EDR、Finder/Files、真机或签名发布。

## 契约先行

先增加均匀输出黑位的 RGB 逆变换契约：输入 `1000/1000 nit`、输出黑位 `10 nit` 时，`(10,10,10)` 必须恢复为场景 `(0,0,0)`，低于黑位必须拒绝。实现前实际失败为 `NumericError.nonFinite`，因为原公式在 `0` luminance 上出现 `0 * infinity`；失败日志为 `/tmp/lutcalc-hlg-black-inverse-contract-first-20261003.log`。

随后扩展契约覆盖 `100/400/1000/4000 nit`、黑位 `0/0.3/10`、nits 与 normalizedBy1000、input/output 两侧及 BBC 系数。第一次扩展契约还暴露了前向黑位端点和 `gamma < 1` 的同类问题，失败日志为 `/tmp/lutcalc-hlg-black-boundaries-contract-first-20261003.log`。

## 实现

- `sceneRGBToDisplay` 对三通道场景黑显式返回对应显示黑位，避免 `0` 亮度与负幂相乘产生非有限值。
- `displayRGBToScene` 将合法域收紧为 `[black, peak]`，三通道精确处于黑位时返回场景黑；低于黑位仍报告 `NumericError.invalidDomain`。
- 其余亮度耦合、峰值裁剪、BBC 系数、Double 精度和既有单位换算均未改变。

## 实际结果

工具链：Xcode 27.0、Swift 6、macOS arm64。

```sh
swift test --package-path Native/Packages/LUTKit --filter HLGOOTFContractsTests
swift test -c release --package-path Native/Packages/LUTKit --filter HLGOOTFContractsTests
swift test -c release --package-path Native/Packages/LUTKit
```

- Debug 定向 10 项，0 失败。
- Release 定向 10 项，0 失败。
- 完整 Release 最终重跑通过：`LUTSharedUITests` 131 项、`LUTCoreTests` 174 项、`LUTCatalogTests` 20 项、`LUTAnalysisTests` 32 项，共 357 项 XCTest，0 失败；既有外部夹具跳过规则保持不变。
- 三个平台未签名 Release 构建均退出 0：macOS、iOS generic、iOS Simulator。日志中的 CoreSimulator 内存／订阅警告不改变构建退出码，也不构成 UI 验收。

独立参照覆盖四个峰值、三个黑位、两种标度和两侧端点；所有合法黑位端点严格恢复场景零，低于黑位明确拒绝。既有非零场景 RGB 往返仍在 `2e-12` 内，未降低网格、位宽、插值规则或放宽阈值。

日志 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `/tmp/lutcalc-hlg-black-inverse-contract-first-20261003.log` | `96f770f91da73120d8e1b786170ed64c61691624f89ea10c3174b12b4de55b55` |
| `/tmp/lutcalc-hlg-black-inverse-debug-20261003.log` | `a366a98625cb4688215b4e86f40c586dcd9b4e688d176a5034a99899595c9bb7f` |
| `/tmp/lutcalc-hlg-black-inverse-release-20261003.log` | `5435bcdd9666c791430f773399677d73970f39f2164e705be5ab63b1550d5601` |
| `/tmp/lutcalc-hlg-black-boundaries-contract-first-20261003.log` | `8ce16296ce202f04e2277cdacd2506c810de79ace49c49fd51f12b8fe561341c` |
| `/tmp/lutcalc-hlg-black-boundaries-debug-20261003.log` | `939e2ae6adf0cb681e3b6ecf40c586dcd9b4e688d176a5034a99899595c9bb7f` |
| `/tmp/lutcalc-hlg-black-boundaries-release-20261003.log` | `797e0ed63fe407037ad551594dd0464689cb4de2d18465c583e6f2d92916ae75` |
| `/tmp/lutcalc-hlg-black-boundaries-full-r1-20261003.log` | `2a974b4ca72e3ccd825fd7f0930869fd144075cead0b01cd5ed7902fb944561c` |
| `/tmp/lutcalc-hlg-black-mac-build-20261003.log` | `bd114b53068e596e5ebea002472727c7ec25cb49276a06050f50e55d4b0d3091` |
| `/tmp/lutcalc-hlg-black-ios-build-20261003.log` | `f917c06e6740f767f8edec898505586902c109fba90fdca97b4f4dd23bc185e3` |
| `/tmp/lutcalc-hlg-black-sim-build-20261003.log` | `49c21edf29492d21ec61fa46eef14abae3d92c60455601c8566f37e96dec6ca0` |

## 未覆盖范围

这只闭合 HLG OOTF RGB 黑位端点的数值子集，不代表完整 HDR/OOTF。PQ/HLG 自动峰值、参考白、屏幕 HDR/EDR、完整限幅与裁剪统计、四种 HDR 显示变体、ICC 完整类型、格式互操作、性能、签名发布及真实 `full-scope-acceptance.json` 仍未完成。FULL-03、FULL-04、H06、H12、H14 和 Goal 继续保持未完成／active。

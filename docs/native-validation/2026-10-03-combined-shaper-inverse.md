# 2026-10-03 组合 shaper 一维反求非 UI 验收

## 范围

本阶段只处理导入组合 LUT 中独立一维 shaper 的反求子集。三维 colour LUT 仍不从采样推断可逆性，也不提供任意三维逆。UI、Files/Finder、真机、项目生成计划、导出服务和目标调色软件往返均不在本阶段范围内。

## 契约先行

- 先增加 `ImportedLUTAnalyzer.inverseShaper` 的契约，要求带 shaper 的组合 LUT 可按所选插值核反求三个独立通道。
- `tricubicLegacyV1` 使用 `LegacyCubicCurve1D.inverse`；线性路径使用现有 `MonotonicCurve1D`。
- 缺少 shaper、平段、非单值曲线、域外输出和求解失败必须显式报错；任意三维 colour LUT 仍报告 `arbitrary3DInverseUnsupported`。
- 实现前的失败日志保留在 `/tmp/lutcalc-shaper-inverse-contract-first-20261003.log`。

## 实现与文件

- 在 `Native/Packages/LUTKit/Sources/LUTAnalysis/ImportedLUTAnalysis.swift` 增加独立 shaper 反求入口，复用已有单调性分析、Legacy cubic 反求和错误映射。
- 在 `Native/Packages/LUTKit/Tests/LUTAnalysisTests/ImportedLUTAnalysisContractsTests.swift` 增加组合 shaper cubic、缺失 shaper、平段和三维逆拒绝契约。
- 生产路径仍为 Swift/Double；没有新增采样表、厂商 LUT、JavaScriptCore、WebView 或自有 C/C++ 内核。

## 实际验证

工具链：Xcode 27.0、Apple Swift 6.4、macOS arm64。

```sh
swift test --package-path Native/Packages/LUTKit --filter ImportedLUTAnalysisContractsTests
swift test -c release --package-path Native/Packages/LUTKit --filter ImportedLUTAnalysisContractsTests
swift test -c release --package-path Native/Packages/LUTKit
```

- Debug 定向 7 项，0 失败。
- Release 定向 7 项，0 失败。
- 完整 Release 8 个测试包共 551 项，0 失败；2 个既有外部夹具按设计跳过。未改变既有 `2e-12` 数值门槛。
- 三个平台未签名 Release 构建均退出 0：macOS、iOS generic、iOS Simulator。日志中的 CoreSimulator 内存／订阅警告不改变构建退出码，也未据此声称模拟器 UI 通过。

独立 cubic 参照使用 unit domain、shaper 样本 `[0, 0.25, 0.75, 1]`，目标值 `0.427424250`，恢复输入 `1.37 / 3`；三个通道均在 `2e-12` 内。平段、缺失 shaper 和任意三维逆拒绝均通过。

日志 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `/tmp/lutcalc-shaper-inverse-debug-20261003-r2.log` | `6e36d9ed78a590363aa91478b3ae4145eef309ceda09c62187bdaefcf70276e3` |
| `/tmp/lutcalc-shaper-inverse-release-20261003.log` | `ed01cb12a68ac42645d33ce2b7e2959a074b9c12fdfb82eea4496a7710d85051` |
| `/tmp/lutcalc-shaper-inverse-release-full-20261003.log` | `3c0e8cacb3e6e2c27616fdb931c8ac3559cc524f436b0777ec8dfdcbb4e1a520` |
| `/tmp/lutcalc-shaper-inverse-mac-build-20261003.log` | `7ecb35732230100133a5be205c8dafdb63e68921f39da1277bbbfb97b5f72b24` |
| `/tmp/lutcalc-shaper-inverse-ios-build-20261003.log` | `fd4650c1532179d9ed2f43c626ae151d387efd8d3a0c4d08e60f8b356eef333d` |
| `/tmp/lutcalc-shaper-inverse-sim-build-20261003.log` | `50be8a106cf640bf74dd50179851bc408e9f5127c32a1f9cc142404477181c7f` |

## 未覆盖范围

本阶段没有接入生成计划、项目持久化或导出服务的 shaper 反求；没有实现任意三维逆、局部 Jacobian、阻尼求解、全局唯一性证明或三维域外策略。完整 LUTAnalyst 的 TF／颜色分离、重建、方向与量化元数据仍未完成。FULL-05、H07、H10、H14 不勾选，`docs/native-validation/full-scope-acceptance.json` 未创建，Goal 保持 active。

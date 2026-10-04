# 2026-10-04 求根容差有限性验收

## 范围

本轮只修正现有 LUTAnalyst 求根契约对无限容差的边界。`SolveTolerance` 的四个 Double 容差必须有限且非负；无效容差应在调用用户函数前返回 `.nonFinite`。该检查同时覆盖 Brent、二分、`LegacyCubicCurve1D.inverse` 和 `allInverseRoots`，不改变合法容差下的求根算法、阈值或 LUT 采样。

## 契约先行

新增 `testInfiniteToleranceIsRejectedWithoutEvaluatingFunction`。旧实现允许 `xAbsolute = .infinity`，实际调用函数 3 次；契约先行因此失败。实现后统一使用 `SolveTolerance.isValid`，并增加 cubic all-roots 的无效容差检查。

## 实际验证

工具链：Xcode 27.0（27A266a）、Swift 6.4（swiftlang 6.4.0.34.1），macOS arm64。

定向命令：

```sh
swift test -c debug --package-path Native/Packages/LUTKit \
  --filter RootContractsTests/testInfiniteToleranceIsRejectedWithoutEvaluatingFunction
```

结果：退出码 `0`，定向测试 `1` 项通过，函数调用次数为 `0`。

完整命令：

```sh
swift test -c release --package-path Native/Packages/LUTKit
```

结果：退出码 `0`，8 个测试包均通过、0 失败；LUTAnalysis 测试包通过。日志 `/tmp/lutcalc-root-tolerance-full-release-20261004.log`，SHA-256 `fa2911b691ba4e931726f7e87b3d73beabaaf809346bb636a40acbe9d30e8add`。

其中 LUTAnalysis 为 `47` 项、0 失败；LUTCore 为 `235` 项、0 失败；LUTCatalog 为 `24` 项、0 失败。macOS、generic iOS 和 generic iOS Simulator 的 Xcode Release 构建均退出码 `0`，并使用同一 Swift 6.4 工具链；构建时 CoreSimulator 报内存不足警告，但未影响三个构建结果。

## 未覆盖

本轮只关闭求根容差的有限性边界。任意 3D LUT 逆、自动 transfer/colour 分离、9 个 `.labin`、45 个查表注册、SUP2 raw、PQ OOTF、Canon CP IDT、RED DRAGONColor2/IPP2、完整 HDR/ICC、UI、设备、性能、签名和发布清单仍未完成。Goal 保持 `active`。

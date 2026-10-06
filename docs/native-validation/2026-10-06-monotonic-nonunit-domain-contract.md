# LUTAnalyst 严格单调一维非单位域契约

## 范围

本项只核对 `MonotonicCurve1D` 的严格单调、均匀采样和非单位输入域。独立参照把三点 `[10, 20, 40]` 放在 `[-2, 1, 4]`，按分段线性公式计算 `x = 2.5` 的结果应为 `30`，再用同一参照确认逆映射应回到 `2.5`。这不是三维 LUT 逆，也不扩展自动 transfer/colour 分离。

## 契约先行与实现核对

新增 `MonotonicAnalysisContractsTests.testStrictCurveUsesIndependentLinearReferenceOnNonUnitDomain`。契约先固定非单位域的坐标归一化、分段选择、线性值和逆结果，再运行现有实现；实现已经使用 `Double` 计算域坐标并通过根求解器回放，因此无需修改生产算法。

## 实际验证

命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter LUTAnalysisTests.MonotonicAnalysisContractsTests
```

工具链：Apple SwiftPM Release，2026-10-06。

结果：`5` 项测试通过，失败 `0`，退出码 `0`。新增案例的正向值误差不超过 `1e-15`，逆值误差不超过 `2e-12`，残差不超过 `2e-12`。

## 边界与未完成项

该证据只关闭严格单调一维非单位域的局部契约，不改变三线性、四面体或 tricubic 任意三维全局根完备性边界。含平台查表、`.labin`、完整 ICC、HDR/OOTF 和 UI 的范围仍按既有记录保持未完成，Goal 继续保持 `active`。

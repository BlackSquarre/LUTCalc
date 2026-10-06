# BT.601 525／625 色域数学验收

日期：2026-10-06。

本项承接 `colour-research-2026-09-23.md` 的 S05，新增两个公开 BT.601 系统色域身份：525 行 SMPTE-C 与 625 行 EBU 3213。两者仅是色域原色和 D65 白点，不新增传递函数、相机预设或 UI 接线；Rec.709 不再被错误地当作两者的同义词。

## 公式与实现

来源为 ITU-R BT.2380-0 §2.2 归档资料。SMPTE-C 原色为 R(0.630,0.340)、G(0.310,0.595)、B(0.155,0.070)；EBU 3213 原色为 R(0.640,0.330)、G(0.290,0.600)、B(0.150,0.060)，两者白点均为 D65 (0.3127,0.3290)。Swift 运行时使用 `Double` 按既有 `ColorPrimaries.rgbToXYZ()` 推导矩阵，没有保存矩阵采样表。

## 契约与结果

先行契约在缺少 `ColorSpaceID`、原色和目录项时编译失败；实现后运行：

```sh
swift test --package-path Native/Packages/LUTKit -c debug --filter BT601ColorSpaceContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter BT601ColorSpaceContractsTests
```

Debug 与 Release 均为 2 项通过、0 失败。独立矩阵锚点包括 SMPTE-C `M[0,0]=0.3935209`、`M[1,1]=0.7010598569257228`，以及 EBU `M[0,0]=0.43055381332990217`、`M[1,1]=0.706654765925283`；误差门槛为 `2e-15`。矩阵由原色和白点独立推导，未使用厂商 LUT 或等价采样表。

## 未覆盖范围

本项不新增 BT.601 OETF、525/625 视频范围量化、历史设备预设、显示管理或 UI；SMPTE-C／EBU 的完整编码链、目标软件往返和发布验收仍未完成。`.labin`、直接查表、完整 ICC/HDR 与 Goal 状态不因本项改变。

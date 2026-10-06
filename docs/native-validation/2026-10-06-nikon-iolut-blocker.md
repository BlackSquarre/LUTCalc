# Nikon IOLUT 直接查表阻塞记录

日期：2026-10-06。

## 复核范围

复核旧 `LUTGammaIOLUT` 的 Nikon Standard、Nikon Neutral、Nikon Vivid、Nikon Monochrome、Nikon Portrait、Nikon Landscape 六项，并同组核对 DJI Mini 2、s709、Rec709 (800%) 三项。检查目标是确认是否存在可追溯公开连续定义、明确适用机型/版本、非灰轴语义和独立数值参照，能够在不搬运旧采样表的前提下实现 Swift `Double`。

## 结论

旧实现只暴露 IOLUT 的样条采样行为及 rec/out 包装；没有提供 Nikon Picture Control 的完整连续曲线、颜色通道耦合定义、机型/固件版本和独立 17³/33³/65³ 参照。Standard、Neutral、Vivid、Monochrome、Portrait、Landscape 不能由 Nikon N-Log、Rec.709、BT.1886 或通用 gamma 公式推断。Monochrome 也不能仅以灰度复制替代其可能包含的对比度/色调处理。

同组的 DJI Mini 2、s709 和 Rec709 (800%) 仍缺少完整连续定义或独立参照；不能以已实现的 D-Log2、S-Log3、Rec.709 或 BT.1886 别名替代。

## 新增负契约

`NikonLookupBlockContractsTests` 逐项确认九个名称仍属于 `AlgorithmCatalog.blockedLookupRegistrationNames`，且不能解析为 transfer、色域或 preset；同时确认可追溯的 `Rec.709 (LUTCalc legacy)` 与 `SMPTE 240M` 独立身份不受影响。

执行：

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter NikonLookupBlockContractsTests
```

结果：Release 定向 `2/2` 通过，失败 `0`，退出码 `0`。

本轮未改生产算法、未新增目录身份、未搬运 Nikon/NCP 或其他等价采样数据。关闭条件是取得公开连续定义、机型/固件范围、非灰轴语义和独立网格参照，再按契约先行实现；在此之前直接查表替代台账仍为 `0/45`，Goal 保持 `active`。

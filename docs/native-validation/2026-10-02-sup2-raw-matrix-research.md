# 2026-10-02 SUP 2 raw 矩阵来源与标题冲突

## 来源

接续 [Log C shoulder 研究](2026-10-02-logc3-shoulder-research.md)。归档 `research/colour/2026-10-02-logc3/arri-logc-vfx-2012-mirror.pdf` 为 ARRI 2012 VFX 文档公开镜像；文本末页明确说明 SUP 2.x（或更早）Log C 记录 raw camera RGB，转换依赖拍摄光源和目标显示设备。来源原字节及 SHA 沿用已冻结内核包，本记录不回写历史归档。

## 最小复现

实际执行：

```sh
sed -n '351,372p' research/colour/2026-10-02-logc3/arri-logc-vfx-2012-mirror.pdf.txt
```

该段列出 tungsten→Rec.709、tungsten→DCI P3、daylight→Rec.709，之后又以 **“The tungsten matrix for DCI P3”** 为标题列出另一个不同矩阵：

```text
1.687399 -0.547351 -0.140048
-0.060610 1.384567 -0.323957
0.025313 -0.337539 1.312227
```

前一个同标题矩阵为：

```text
1.686983 -0.620860 -0.066122
-0.085054 1.314693 -0.229639
0.058272 -0.415287 1.357015
```

## 结论与实现边界

不能继续称 SUP 2 raw 完全没有公开矩阵。已公开的矩阵具有光源／目标显示语义，不等于独立于光源的 AWG3 原色定义；本轮 AWG3 只接 SUP 3 scene 显式 EI 预设。

末尾标题与顺序冲突，不能凭上下文把其自动标为 daylight P3。后续须补来源勘误或第二独立来源，并冻结输入单位、光源及目标白点的契约，再实现显式校准算子；不为 SUP 2 默认选择 AWG3，不以六位显示矩阵替代原色推导的高精度参照。标题冲突按项研究阻塞，其他非 UI 工作继续。

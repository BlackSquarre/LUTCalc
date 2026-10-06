# 2026-10-06 白平衡与 PSST 算法阻塞复核

## 范围

本轮只复核旧白平衡 Kelvin／Duv／Dpl 和 PSST-CDL 固定 Ring 的算法来源，未把旧采样数组搬入 Swift，也没有实现未经证明的近似模型。UI、项目字段和其他调节链不在本轮范围内。

## 实际命令与工具链

在仓库根目录执行：

```sh
node tools/native-validation/inspect-white-balance-locus.js >/tmp/wb-recheck-20261006.log
node tools/native-validation/inspect-psst-fixed-rings.js >/tmp/psst-recheck-20261006.log
sha256sum /tmp/wb-recheck-20261006.log /tmp/psst-recheck-20261006.log \
  docs/native-validation/artifacts/2026-10-02-sdr-saturation/white-balance-locus-reproduction.json \
  docs/native-validation/artifacts/2026-10-02-multitone/psst-fixed-rings-reproduction.json js/colourspace.js
```

Node 两个复现命令均退出 `0`。复核日志摘要分别为“旧白平衡轨迹依赖与五组参数最小复现已保存，仅研发证据”和“PSST 固定环采样依赖和默认控制输出已保存，仅研发证据”。

本轮输出哈希：

- 白平衡复核日志：`26307dc0e7fd209c9c4aa5589795a64e4ec64319f0605d7c11e1f973d68c0184`
- PSST 复核日志：`ba4f92e3c13880cca2db8df3101f7d42aa2922835acaec10b7d205635bcd6aed`
- 白平衡复现 JSON：`ddff1189357056741cd778bcc09b592ef03952c377f476544e03cf289b819ffa`
- PSST 复现 JSON：`3579a00c11a35158b80bfa6fc318f72f5b5d53093a653663ccc76fc96cfe0a87`
- 旧源码 `js/colourspace.js`：`89f5d45d2783056fe663ab045346a25482f6873c74213377ef227865324a622c`

工具链为仓库现有 Node 复现脚本；本轮没有修改旧 JavaScript 源码或复现 JSON。

## 白平衡 Planck／Duv／Dpl

`Planck.setLoci` 只提供 501 个 RGB 数值节点（温度域 100–50100 K），后续 `XYZ`、`uv`、Duv 差分和 CCT 根求解全部读取该 spline。源码没有记录观测者、色匹配函数、积分波段与步长、辐射常数或节点生成方法。复现仍得到旧系统 CCT `6504 K`，以及 `ctMired=-500`、`lampMired=-300` 时 base 被裁为 `1800 K`、ct 约 `18000 K` 的旧参数语义。

黑体辐射定律或公开 CCT 近似只能产生另一个明确版本的物理模型，不能证明与这 501 点旧轨迹逐点相同。Duv／Dpl 的法线、切线、几何裁剪和极端 mired 语义也没有独立参照。因此没有满足“可追溯公式、旧语义、独立参照、2e-12 门槛”四项条件的替代实现。

## PSST 固定 Ring

旧 `initPSSTCDL` 的固定依赖仍为：`psstF` 71 点周期 cubic、`psstB` 8 点周期 cubic、`psstY` 8 点线性环和 `psstM` 71 点线性环。复现确认 `psstF` 周期上升约 `0.9999999999885584`，`psstB` 周期上升约 `2π`，`psstM` 非单调；源码没有记录这些节点的生成方程、拟合目标、色度空间定义或精度来源。

默认用户控制对彩色输入仍非恒等：`[1,0,0]` 最大绝对差 `0.0005277754963962655`，`[0,0,1]` 最大绝对差 `0.0006204653408205946`；中性灰保持恒等。用标准 HSV、规则色相圆或跳过默认算子都会改变旧行为，不能作为兼容迁移。

## 结论与后续条件

白平衡 Planck／Duv／Dpl 和 PSST 固定 Ring 继续标记**研究阻塞**，对应 FULL-03 不勾选，Goal 保持 `active`。本轮没有新增生产代码，也没有降低网格、位宽、插值规则或误差阈值。

解除阻塞必须取得旧轨迹／固定环的可追溯生成定义，或建立明确独立版本并以独立高精度参照冻结差异；之后先写边界契约，再接入 Swift `Double` 计算和项目存储。旧采样数组仍仅用于研发复现，不得打包进 App 或 SwiftPM 资源。

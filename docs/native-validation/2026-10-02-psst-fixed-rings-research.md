# 2026-10-02 PSST-CDL 固定环采样研究

## 当前结论

FULL-03 的 PSST-CDL 尚未迁移。旧算法固定的色相／亮度／色度映射连续来源未闭合，标记研究阻塞，继续其他工作。不能把标准 HSV 或通用 ASC-CDL 当成旧 PSST 的等价替代，也不能直接搬入固定采样环。

来源为保留的 LUTCalc GPLv2 源码 `js/colourspace.js:1205 initPSSTCDL`、`1973 PSSTCDLOut`、`js/ring.js` 及 `js/twk-psstcdl.js`。源码注明上游 `https://github.com/cameramanben/LUTCalc`；本轮没有取得额外的作者生成定义或外部连续公式。

## 实际依赖与最小复现

执行以下命令，实际退出 `0`：

```sh
node tools/native-validation/inspect-psst-fixed-rings.js
```

完整来源哈希、固定环长度／端点／内容哈希、工作空间与实际默认控制输出见[复现 JSON](artifacts/2026-10-02-multitone/psst-fixed-rings-reproduction.json)。脚本只记录依赖与八个最小样本，没有将整组固定数据重新打包为原生资源。

| 固定依赖 | 点数 | 用途 |
| --- | --- | --- |
| `psstF` | 71 | Pb／Pr 角度到 PSST 参数位置，周期 cubic |
| `psstB` | 8 | PSST 位置回到 Pb／Pr 角度，周期 cubic |
| `psstY` | 8 | PSST 位置的亮度标度，线性插值 |
| `psstM` | 71 | PSST 位置的色度幅度标度，线性插值 |

这些环与用户自定义的 29 点 colour／saturation／SOP 控制环不同。后者是用户参数；前者是内置映射数据，当前没有与所存数值对应的完整生成公式和精度契约。

`PSSTCDLOut` 先在 Sony S-Gamut3.cine 工作空间计算 Y、Pb／Pr、角度与幅度，再经上述固定映射及用户控制，按 `0.005` 色度阈值混合灰色附近的效果；包含负值 power 跳过、S/P/saturation 的零下限及旧 NaN→0。原生不能复制旧非有限数值清零行为。

默认用户控制并不令全部彩色输入严格恒等。实际旧输出与输入最大绝对差：

- `[1,0,0]`：`0.0005277754963962655`。
- `[0,1,0]`：`9.195847278875569e-06`。
- `[0,0,1]`：`0.0006204653408205946`。
- 黑色和中性灰 `[0.2,0.2,0.2]`：`0`。

因此，仅实现数学上更规整的色相往返或在“默认控制”时跳过该算子会改变旧语义；不能无版本说明地宣称旧兼容。

## 解除条件

取得固定映射的生成定义，或建立独立、明确版本的连续 PSST 模型，并记录其与旧采样映射的差异；不能隐藏成同一旧版本。必须覆盖周期接缝、负 remainder、色度阈值两侧、灰色、负值、SOP 奇点、两种 chroma／luma scaling 和完整旧链，保持原网格与 `2e-12` 门槛。

此研究不影响公式可追溯的 Multitone：旧 `buildColourSquare` 明确按 HSL 计算，原生可以逐个用户色调直接求值，无需打包 256×256 表。本轮没有实现 PSST 原生算子，不勾选 FULL-03，Goal 保持 **active**。

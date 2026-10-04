# 2026-10-02 白平衡 Planck 轨迹依赖研究

## 结论与影响

FULL-03 旧白平衡的色温／Duv／Dpl 路径存在未闭合的连续算法来源，当前标记**研究阻塞**。这不阻塞其他调节阶段。原生代码尚未加入白平衡算子，不能标记白平衡完成，也不能将既有 CAT02／Bradford 基础矩阵能力计为完整旧白平衡。

本轮依据保留源码直接复现，不声称公开文献没有黑体公式。待解决的是旧表的生成模型／精度和旧 CCT／Duv 语义，与独立物理参照之间的关系。不能拿未经验证的近似多项式替代后放宽 `2e-12` 阈值。

## 来源与依赖

源文件 `js/colourspace.js`：

- `Planck.setLoci`（2323 行起）直接嵌入 501 点 x／y／Y=1 表，温度域 `[100,50100]`，以旧 cubic 取样。
- `Planck.XYZ/uv`、`Duv` 的 ±1 K 差分、`getCCT` 的根求解和整 K 舍入均读取该表。该段源码没有声明观测者、色匹配函数、积分波段／步长、辐射常数或表的生成来源。
- `CSWB`（2763 行起）计算系统 CCT 和偏离量，`setCAT` 将色温 CAT 比例与 lamp 的 Duv／Dpl CAT 比例组合，最后返回工作 RGB 空间。
- `CSWB.setVals` 的 `ref` 未在函数中使用；色温和 lamp 已由 `twk-white.js:217` 换成相对于 ref 的 mired shift。不能重复用 ref 对生成算子施加第二次换算。
- `setVals` 对极端负 mired shift 调整 base；`uvAdd` 还包含 xy 非负／和不大于 1 的几何裁剪。它们都需要作为参数域语义验证，不能只迁移普通温度 CAT。

来源为保留的 LUTCalc GPLv2 源码及其注明的上游 `https://github.com/cameramanben/LUTCalc`。本轮没有获取新的外部公式或作者说明。旧表和脚本仅用于研发，未加入原生产品资源。

## 实际最小复现

执行命令，退出 `0`：

```sh
node tools/native-validation/inspect-white-balance-locus.js
```

该脚本装载实际旧引擎依赖，构造 `LUTColourSpace`，读取七个温度的 `XYZ/uv`，并调用 `wb.setVals(5500, ctShift, lampShift, duv, dpl)` 五组参数。来源 SHA-256、实际矩阵与中间温度保存于[复现 JSON](artifacts/2026-10-02-sdr-saturation/white-balance-locus-reproduction.json)。

- 工作空间实际为 Sony S-Gamut3.cine，D65 的旧系统 CCT 为 **6504 K**。
- 零 shift／零 Duv／Dpl 给出旧路径的中性矩阵；非零 shift 和 Duv／Dpl 改变矩阵。
- `ctShift=-500`、`lampShift=-300` 时，base 实际变为 **1800 K**，ct 为约 **18000 K**，lamp 约 **3913.04347826087 K**，说明简单以 6504 K 固定 base 计算会改变旧语义。

本证据证明实际依赖与参数行为，不证明连续替代算法等价。实际源码哈希与结果哈希归入[SDR Saturation 阶段证据目录](artifacts/2026-10-02-sdr-saturation/)。

## 后续解除条件

1. 找到可追溯的旧轨迹生成定义，或建立明确区分旧版本的连续物理模型；版本差异不能隐藏。
2. 独立高精度计算 XYZ、CCT、法线／切线及 CAT；覆盖极端 mired、负值／域外、Duv／Dpl 几何边界。
3. 冻结旧完整白平衡链与独立物理参照，按原门槛记录差异；无证据时不把 Kelvin 输入认作已迁移。
4. 先落实契约，再接入阶段 6、参数存储和不可变请求。UI 按用户要求暂缓。

与此同时，公式明确的 SDR Saturation 阶段继续实现与验收，整个 Goal 保持 **active**。

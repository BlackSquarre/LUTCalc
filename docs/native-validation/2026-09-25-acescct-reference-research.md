# ACEScct 官方参考核对（2026-09-25）

本记录只做资料核对，未修改 Swift 源码。目标是给原生实现提供可复现的公式、矩阵、切点和契约测试参考。

## 1. 权威来源与哈希

来源仓库：`https://github.com/aces-aswf/aces-core`，官方 ACES v1.0.3 标签，提交
`ed0c686a2067ee1daf60178fecc88633a0af26dc`（标签对象：
`f397ae6b83563b437c1f14a9ed0efa0f1668d069`）。以下文件均按该标签核对；SHA-256 是文件内容哈希，Git blob 是对应 Git SHA-1。

| 文件 | 用途 | SHA-256 | Git blob |
|---|---|---|---|
| [`S-2016-001/specification.tex`](https://raw.githubusercontent.com/aces-aswf/aces-core/v1.0.3/documents/LaTeX/S-2016-001/specification.tex) | ACEScct 正式规范、AP1、白点、编码/解码公式、TRA 矩阵 | `aed71bc370de73eeac070ea2923afba7d1c662efbbe576de0a4a0753ed0d43` | `09d1262768ea7dc513dbce7ec8e4b21fc271a169` |
| [`ACEScsc.ACES_to_ACEScct.ctl`](https://raw.githubusercontent.com/aces-aswf/aces-core/v1.0.3/transforms/ctl/csc/ACEScct/ACEScsc.ACES_to_ACEScct.ctl) | 正向 CTL 分支和常数 | `de399808d15c659a9f42b0183915d02210b2b3d3113de85b67a07a6e5df44c4b` | `2f17788c31ceb1d3fb45195d37b35912cc1f6866` |
| [`ACEScsc.ACEScct_to_ACES.ctl`](https://raw.githubusercontent.com/aces-aswf/aces-core/v1.0.3/transforms/ctl/csc/ACEScct/ACEScsc.ACEScct_to_ACES.ctl) | 逆向 CTL 分支和 AP1→AP0 应用 | `d608d0875a21b317b7338287f65f2bf909e8875280e76b28a6e7be8e74a081ab` | `a5b2aa4c0f0756c6fb5980a997049975762b840a` |
| [`ACESlib.Utilities_Color.ctl`](https://raw.githubusercontent.com/aces-aswf/aces-core/v1.0.3/transforms/ctl/lib/ACESlib.Utilities_Color.ctl) | AP0/AP1 色度坐标常量 | `1f2bd21f2407b227c68f8389cd447778944eff8b4742ba2e3d0f5abc696c10fd` | `0d864bb20893da5a8713dacfe3058a77f35945ce` |
| [`README-MATRIX.md`](https://raw.githubusercontent.com/aces-aswf/aces-core/v1.0.3/transforms/ctl/README-MATRIX.md) | 官方矩阵逐通道展开式 | `069e95a8c1d4718ed9a9c78cb7292e5b5baeb5a9354ea74658741b66a43f2fcb` | `9286a1ef42c8dd5b074b6c9a89c0630d700ee942` |

## 2. ACEScct 颜色空间数据

ACEScct 使用 AP1 原色（CIE 1931 xy）：

- R `(0.713, 0.293)`
- G `(0.165, 0.830)`
- B `(0.128, 0.044)`
- 白点 D60 `(0.32168, 0.33767)`

为计算 AP0↔AP1 矩阵，官方 `ACESlib.Utilities_Color.ctl` 同时给出 AP0（SMPTE ST 2065-1）：R `(0.73470, 0.26530)`、G `(0.00000, 1.00000)`、B `(0.00010, -0.07700)`，白点同为 `(0.32168, 0.33767)`。

白点在 Y=1 归一化下的 XYZ 是：

```text
X = x/y = 0.95264607456984629964
Y = 1
Z = (1-x-y)/y = 1.00882518435158586786
```

## 3. 正向/逆向公式（逐通道）

令 `x = lin_AP1`，`y = ACEScct`。官方常数：

```text
X_BRK = 0.0078125
Y_BRK = 0.155251141552511
A     = 10.5402377416545
B     = 0.0729055341958355
```

正向（ACES AP0 线性值先通过 AP0→AP1）：

```text
y = A*x + B                         if x <= X_BRK
    (log2(x) + 9.72) / 17.52         if x >  X_BRK
```

因此负的 `lin_AP1` 值走线性 toe 分支，不能在负值上调用 `log2`。

逆向（规范 S-2016-001）：

```text
x = (y - B) / A                       if y <= Y_BRK
    2 ** (y*17.52 - 9.72)             if Y_BRK < y < Y_MAX
    65504                             if y >= Y_MAX
```

其中 `Y_MAX = (log2(65504) + 9.72) / 17.52 =
1.467996312044715218450823538236458...`。规范写出 65504 上限；历史 CTL 逆变换文件只实现前两段（`if (in > Y_BRK) pow(...) else ...`），未实现 65504 饱和段。若 Swift 契约要求符合正式规范，应保留上限分支；若要求逐字复刻该 CTL，则记录这一差异。

ACEScct 规范明确为 32-bit IEEE 754 单精度浮点、内部临时工作空间，不用于容器交换或归档，且值不应被任意 clamp（65504 是逆函数定义的浮点上限）。

## 4. AP0↔AP1 矩阵

规范中的 10 位有效数字（逐通道展开，适合与现有 ACES 参考实现对照）为：

```text
TRA1: AP0 -> AP1
[ 1.4514393161, -0.2365107469, -0.2149285693 ]
[-0.0765537734,  1.1762296998, -0.0996759264 ]
[ 0.0083161484, -0.0060324498,  0.9977163014 ]

TRA2: AP1 -> AP0
[ 0.6954522414,  0.1406786965,  0.1638690622 ]
[ 0.0447945634,  0.8596711185,  0.0955343182 ]
[-0.0055258826,  0.0040252103,  1.0015006723 ]
```

按上述 AP0/AP1 xy 和共同 D60 白点，用 SMPTE RP 177 的 RGB→XYZ 构造再求逆，可得到适合作为 Swift `Double` 参考常量的高精度值（矩阵按列向量写法；逐通道方程与官方 README-MATRIX 等价）：

```text
TRA1 =
[ 1.451439316145665490, -0.236510746893740143, -0.214928569251925347 ]
[-0.076553773396020543,  1.176229699833572733, -0.099675926437552190 ]
[ 0.008316148425697785, -0.006032449791021033,  0.997716301365323247 ]

TRA2 =
[ 0.695452241357451763,  0.140678696470294155,  0.163869062172254082 ]
[ 0.044794563372037709,  0.859671118456421882,  0.095534318171540409 ]
[-0.005525882558113590,  0.004025210305978657,  1.001500672252134933 ]
```

双精度重算满足 `TRA2 * TRA1 = I`（误差约 1e-79，使用高精度十进制中间量）。规范正文中 `TRA2` 的最后一行文字仍写成 `NPM^{-1}_{AP1} · NPM_{AP0}`，与数值和 CTL 命名不一致；应以数值和 CTL 的 `AP1_2_AP0_MAT = AP1_2_XYZ_MAT · XYZ_2_AP0_MAT` 为准，即 AP1→AP0。

Swift 若采用行主序数组，应直接按上面每一行的逐通道公式实现；不要把矩阵再转置一次。官方 CTL 的 `mult_f3_f44` 展开结果可在 README-MATRIX 的 AP0-to-AP1/AP1-to-AP0 小节逐项核对。

## 5. 建议的契约参考点（Double 计算值）

以下数值用官方常数和 IEEE 双精度 `log2` 计算，比较时建议允许少量平台误差（例如 `1e-14`；若实现最终存储 Float32，应按 Float32 误差另设容差）。

| 输入 | 期望输出 |
|---|---:|
| `encode(0.0)` | `0.072905534195835495` |
| `encode(-0.01)`（验证负值走 toe） | `-0.032496843220709518` |
| `encode(X_BRK = 0.0078125)` | `0.155251141552511296` |
| `encode(0.18)` | `0.413588402492442275` |
| `encode(1.0)` | `0.554794520547945202` |
| `encode(65504)` | `1.4679963120447153` |
| `decode(B)` | `0.0` |
| `decode(0.5)` | `0.514056913328032938` |
| `decode(encode(0.18))` | `0.18000000000000002`（双精度舍入） |
| `decode(Y_MAX)` | `65504.0`（规范上限分支） |

### 切点舍入注意事项

`A*X_BRK+B` 的高精度结果为 `0.15525114155251128125`，而官方 `Y_BRK` 常数写为 `0.155251141552511`。两者相差约 `2.81e-16`。正向在 `x == X_BRK` 使用 toe 分支；逆向规范/CTL 使用写出的 `Y_BRK` 十进制阈值。因此契约测试应以官方写出的常量和比较方向为准，不要运行时由 `A*X_BRK+B` 重算阈值后再比较分支，否则会在切点附近产生不同的最后几位行为。

## 6. 结论

原生 ACEScct 实现至少应锁定：AP1/D60 色度坐标、AP0→AP1 和 AP1→AP0 矩阵方向、`X_BRK/A/B/Y_BRK` 常数及比较方向、负 toe 输入、以及规范要求的 `65504` 逆向饱和。上表和来源哈希可直接作为 Swift 契约测试的固定参考。

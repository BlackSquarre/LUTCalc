# H11 KineLOG3 阶段验收

日期：2026-09-25

## 范围与来源

来源为已归档的 Kinefinity 官方页面：`research/colour/2026-09-23/pages/kine-spec.html`。本阶段只接入页面明确描述的 KineLOG3 和 Kinefinity Wide Gamut 身份，未把页面列出的设备范围外推到其他 Kinefinity 或第三方设备。

官方分段公式：

```text
a = 66.64, b = 0.296, c = 0.907136, d = 0.092864
cut = -0.008239, s = 0.017178

Linear -> KineLOG3:
  x < cut: (x - cut) / s
  x >= cut: log10(a * x + 1) * b * c + d

KineLOG3 -> Linear:
  y < 0: y * s + cut
  y >= 0: (10^((y - d) / (b * c)) - 1) / a
```

Kinefinity Wide Gamut 的页面坐标为：R `(0.7571, 0.2282)`、G `(0.2139, 1.1480)`、B `(0.0536, -0.2236)`、D65 `(0.3127, 0.3290)`。本阶段只验证同色域计划，不把页面四舍五入的跨色域矩阵当作高精度矩阵来源。

## 契约与实现

先写失败契约，日志为 `/tmp/lutcalc-kinelog3-contract-red-20260925.log`。随后加入 `KineLog3Transfer`、`TransferID.kineLog3`、`ColorSpaceID.kinefinityWideGamut`、变换计划分支、目录注册、CLI 预设和目录身份契约。

定向 KineLOG3 XCTest 3 项通过；目录身份 XCTest 1 项通过。非有限输入仍拒绝，最终计算保持 `Double`。

## CUBE 独立逐节点结果

预设 `kinefinity.kinelog3-exposure-one.v1` 为 KineLOG3 → 线性场景、Kinefinity Wide Gamut 同色域、+1 stop。独立脚本按官方逆函数解码后乘以 2，未读取任何 LUT、`.labin` 或采样表。

| 网格 | 节点 | 最大尺度化误差 | RMS | P99 | 门槛 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 33³ | 35,937 | `1.1150635581761299e-15` | `4.523216143675773e-16` | `1.1150635581761299e-15` | `2e-12` |
| 65³ | 274,625 | `1.1150635581761299e-15` | `4.3422522664887216e-16` | `1.1150635581761299e-15` | `2e-12` |

生成器内部临时文件读回通过，所有节点均为有限 `Double`。

## 哈希

```text
c5526064a6c6384b23b0e87959ccf13ebff16e4480f5d33100d309d78b7d85d7  research/colour/2026-09-23/pages/kine-spec.html
ed7fba35743c31bc913b6c17ce1d8d6f99ad4e54c3e6ed66c84016cf407939a3  Native/Packages/LUTKit/Sources/LUTCore/KineLog3Transfer.swift
b674581b7a97df28bd2d4c3a76f4d8842a0e9b813c2ac7ae928d7e140e571269  tools/native-validation/verify-kinelog3-cube.py
517845c4abaf346d981524a3b3231a94b5a27f4e344eec970870651a5a5caf2d  Native/Packages/LUTKit/Tests/LUTCoreTests/KineLog3ContractsTests.swift
```

## 状态边界

本阶段证明 KineLOG3 标量公式、Kinefinity Wide Gamut 身份、同色域曝光计划和 macOS 独立 CUBE 读回。跨色域矩阵、设备全范围、真机运行、Files 独立读回、目标软件导入和完整 H01–H14 仍未完成；不据此宣称完整迁移或发布就绪。

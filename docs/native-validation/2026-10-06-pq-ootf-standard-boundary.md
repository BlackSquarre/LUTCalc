# 2026-10-06 PQ OOTF 标准边界与最小复现

## 结论

本轮把 PQ OOTF 的未完成状态收紧为可验证的标准边界：SMPTE ST 2084 定义的是绝对亮度编码（EOTF/OETF），BT.2100 的 PQ 系统不会从一个 PQ 码值反推出场景线性参考白、系统 gamma 或显示峰值。因此，标准 PQ 编码不能单独确定 LUTCalc 旧 `LUTGammaOOTFPQ` 所需的 scene-to-display OOTF 参数。旧公式继续作为隔离的兼容内核，不得注册为标准 transfer 或隐式接入 `TransformPlan`。

## 来源

- ITU-R BT.2100（当前项目标准入口）：<https://www.itu.int/rec/R-REC-BT.2100/en>
- SMPTE ST 2084（Perceptual Quantizer，绝对亮度传递函数）：<https://ieeexplore.ieee.org/document/7291452>
- 旧实现：`js/gamma.js` 中 `LUTGammaOOTFPQ`，源码 SHA-256 记录于[2026-10-03 研究阻塞](2026-10-03-pq-ootf-research.md)。

## 最小复现

对同一输入 `s = 0.18`，标准 PQ 参考路径把它解释为相对于 10,000 cd/m² 的绝对亮度，故 `L = 1800 cd/m²`，再由 ST 2084 编码。旧路径则先把输入解释为百分比样式单位，并在 `Lw = 1000`、`scale = nits` 下得到：

```text
LegacyPQOOTF.forward(0.18) = 5.704834098099198 nits
PQ absolute luminance      = 1800 nits
```

两者不是浮点误差；它们采用了不同的输入单位和不同的物理语义。即使固定输入为场景线性 `s`，任意公开 OOTF 候选 `L = Lw * s^gamma` 都需要额外指定 `Lw`、参考白、`gamma`、黑位和峰值裁切策略；标准 PQ EOTF 只会对候选得到的绝对亮度编码，无法从一个输出码值反解这些参数。旧实现的 `Lw/100`、`scale`、BT.709 风格 knee 和 `2.4` 幂次也没有形成 BT.2100 的一一对应公开定义。

旧分段的 knee 仍可独立复现：输入约 `0.03024` 两侧输出差约 `1.7751367975487e-3 nits`。该跳变不能用插值或放宽阈值掩盖，也不能作为标准 OOTF 的连续公式证据。

## 实际验证

独立参照脚本 `tools/native-validation/probe-pq-ootf-boundary.py` 使用 80 位
`Decimal` 复算单位边界，输出固定为：标准绝对亮度 `1800` nits 的 PQ code
`0.81594345511375624873709513777856479684895236322224767623656597597626514015473119`；
历史路径 `0.18` 输入为 `5.7048340980992004621530545445798066323880059788361933019892040526975149591004515`
nits；knee 两侧差值为
`0.00177513679757470482968924608182029565248635948343862707233361890166655776076348`
nits。

```sh
python3 tools/native-validation/probe-pq-ootf-boundary.py
python3 -m py_compile tools/native-validation/probe-pq-ootf-boundary.py
swift test --package-path Native/Packages/LUTKit -c release \
  --filter RegistryContractsTests/testRec2100PQReferenceRemainsSeparateFromLegacyOOTF
swift test --package-path Native/Packages/LUTKit -c release \
  --filter LegacyPQOOTFContractsTests
swift test --package-path Native/Packages/LUTKit -c release \
  --filter BT2100HLGReferenceOOTFContractsTests
```

三组契约均以 SwiftPM Release 执行；第一组确认 `rec2100.pq-reference.v1` 不携带 HLG OOTF、目录没有 `PQ OOTF` 身份，第二组冻结旧公式的单位与 knee，第三组确认 HLG reference 路径仍独立。完整输出保存于本次验证目录的临时日志中；本记录不把这些定向测试扩大为完整 HDR/EDR 验收。

## 未完成

仍缺少一个独立、可引用且逐码可核对的产品 OOTF 定义（包括场景单位、参考白、系统 gamma、黑位、显示峰值和裁切策略）。在获得该来源前，不新增 PQ OOTF 生产实现、不平滑旧跳变、不创建厂商采样表。完整 PQ OOTF、自动峰值、HDR/EDR 设备语义和真实显示参照继续保持未完成，Goal 保持 `active`。

# 2026-10-04 算法闭合核对

## 本轮结论

本轮只核对已有算法范围，没有新增曲线、色域、厂商资源或 UI 范围。Null legacy 接入后的现有解析式批量契约通过；当前仍未闭合的项目不能用猜测公式、拟合采样表或旧 `.labin` 代替。

## 已复核的解析式

使用已经编译的 Swift Release 检查产品运行：

```sh
python3 tools/native-validation/run-check-batch.py \
  Native/Packages/LUTKit/.build/out/Products/Release --workers 2 \
  > /tmp/lutcalc-algorithm-batch-20261004.log 2>&1
```

退出码为 `0`，日志 SHA-256 为 `da79f406521ef8ca90111aa4e9ba41d9065c8f3c720b53176808cbf0763bea47`。7 个独立检查全部通过：

- Rec.709：ITU 分段、旧兼容全码和曝光计划。
- Sony S-Log3：官方／旧兼容、S-Gamut3.Cine／S-Gamut3 到 AP0 矩阵和计划。
- ARRI LogC4：标量、10/12-bit 全码、AWG4 到 AP0 矩阵和计划。
- Panasonic V-Log：标量、10/12-bit 全码、V-Gamut 到 AP0 Bradford 矩阵和计划。
- Apple Log／Apple Log 2：官方标量、10/12-bit 全码和两套 Bradford 计划。
- Rec.2100 HLG：33³ 与 65³ 全节点独立 BT.2100-3 参照。
- BT.1886：33³ 与 65³ 全节点独立公式和逆函数。

Null legacy 的 17³／33³／65³ 独立 Decimal 结果、目录和完整 Release 结果见[Null legacy 算法验收](2026-10-04-null-algorithm.md)。

已有算法的相机默认路由也已按 66 个稳定身份重新核对：legacy 策略 `34/66` 可用，published 策略 `41/66` 可用；其余条目因专用色域、CP IDT、Passthrough、查表曲线或资料不足保持拒绝。逐项 JSON、命令和哈希见[相机默认路由可用性核对](2026-10-04-camera-default-availability.md)。

## 仍未闭合的算法范围

### 已有代码边界之外、资料足够前不得实现

- DJI DLog-M：旧实现依赖曲线采样；现有来源只有设备 LUT 和测试素材，不能提炼成可追溯连续公式。
- `LUTGammaIOLUT`、`LUTGammaLUTSL3`、`LUTGammaLUTSimple` 注册项：均属于旧查表或机内风格，不能把表复制、压缩或拟合进 Swift。
- 9 个 `.labin` 资源：没有公开连续定义，继续保持资源替代阻塞。
- Canon CP IDT、RED DRAGONColor2／IPP2：当前来源不足以确定完整矩阵、色调映射和版本语义。

### 资料冲突或多解，已有最小复现但不能猜测

- ARRI SUP2 raw 光源／目标矩阵标题冲突、连续 EI、sensor 单位和实际高 EI shoulder；记录见 `2026-10-02-sup2-raw-matrix-research.md` 与 `2026-10-02-logc3-shoulder-research.md`。
- PQ OOTF 的分段跳变以及 `Lw`、scale、输入单位语义冲突；记录见 `2026-10-03-pq-ootf-research.md`。
- 白平衡轨迹、PSST 固定映射和任意 3D 逆的多解问题；已有研究记录继续作为阻塞，不用近似替代。

### 尚有数学子集但不等于完整算法完成

- HLG OOTF 已声明参数的 Double 数学、nits 计划边界以及标量／RGB 峰值裁切逆向非唯一域拒绝均有验收；自动峰值、参考白／黑位、四种 HDR 变体、完整限幅和真实 HDR/EDR 仍未完成。边界记录见[HLG OOTF 标量峰值裁切逆向边界验收](2026-10-04-hlg-ootf-scalar-clipped-inverse.md)和[HLG OOTF 峰值裁切逆向边界验收](2026-10-04-hlg-ootf-clipped-inverse.md)。
- ICC 仅完成受限 RGB matrix/TRC、四种 intent 的 `mpet`、三通道 `mft1/mft2/mAB/mBA`、PCS Lab／XYZ 和显式 linking；relative colorimetric 的 `A2B1`／`B2A1` 优先及对明确不支持 tag type 的 `A2B0`／`B2A0` 回退已有独立契约。`mpet` 的 ICC.1:2022-05 当前元素集合（`cvst`、`matf`、`clut`、`bACS`、`eACS`）已覆盖，`parf` type 3/4 明确属于传统 `para`，不应扩展到 MPE。传统 tag 的任意通道 linking、真实 profile 独立参照、黑点补偿和 gamut mapping 仍未完成，详见[ICC MPE 验收](2026-10-05-icc-mpet-absolute.md)、[ICC MPE 任意通道验收](2026-10-05-icc-mpet-arbitrary.md)和[ICC relative colorimetric 标签优先级验收](2026-10-04-icc-relative-intent-tags.md)。
- LUTAnalyst 已补充独立 1D transfer 的 cubic 全域多根诊断：按导数临界点切段，保留全部根和残差；定向 Debug／Release 各 18 项、全量 Release 的 LUTAnalysis 45 项均通过，结果见[一维 cubic 全局多根诊断验收](2026-10-04-lutanalyst-global-roots.md)。另已验收严格单值下降方向 `.labin` transfer 进入反求计划并输出 3D CUBE，见[LUTAnalyst 一维反求导出接线验收](2026-10-04-lutanalyst-inverse-export.md)；调用方显式已知仿射模型的 3D 生成接线，见[LUTAnalyst 显式仿射 3D 反求生成验收](2026-10-04-lutanalyst-affine-inverse.md)。完整 TF／颜色自动分离重建、病态三维／全局多解证明和任意 3D 逆仍未完成。

## 状态

本记录关闭的是本轮解析式回归核对，不关闭上述研究阻塞或 FULL-01 至 FULL-08。UI、真机性能样本、签名发布和 `full-scope-acceptance.json` 继续保持未完成；Goal 保持 active。

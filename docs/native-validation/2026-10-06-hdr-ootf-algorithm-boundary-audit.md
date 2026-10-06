# HDR/OOTF 算法边界审计

## 范围

本记录只审计原生 Swift 算法层的 HDR、EDR 和 OOTF 未闭合项，不涉及 UI、设备显示或性能。复核对象为 `BT2100HLGReferenceOOTF`、`HLGOOTF`、`LegacyPQOOTF`、`HLGOOTFSettings`、`TransformPlan` 中的 HDR 路由，以及 HDR 预览拒绝契约。

## 公开公式与现状

- BT.2100 reference HLG OOTF 已按 BT.2100-3 Table 5 和 Note 5f 实现，支持通常制作范围与显式 extended gamma；黑位抬升按 `beta = sqrt(3) * (LB/LW)^(1/gamma)`，所有峰值和黑位均使用有限 `Double` nits。
- 历史 `HLGOOTF` 保留旧 LUTCalc 的黑位、BBC 系数、12 倍场景范围和 `nits`/`normalizedBy1000` 兼容语义，与标准 reference 路由隔离。
- `LegacyPQOOTF` 仅作为历史兼容核保存。其输入单位、`Lw`/`scale` 关系和 knee 两侧不连续，无法由 BT.2100 或 ST 2084 唯一推导为标准 PQ OOTF，因此没有把它改写成标准算法。
- EDR 屏幕峰值、参考白/黑位自动策略、PQ OOTF 的场景/显示语义、完整四种旧 HDR 显示变体和设备色彩管理仍缺少可追溯且无歧义的契约；本轮不猜测、不增加采样表或伪造设备参照。

## 验证命令与结果

工具链：SwiftPM Release，当前仓库 Swift 工具链。

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter 'BT2100HLGReference|HLGOOTFContractsTests|LegacyPQOOTFContractsTests|PreviewContractsTests'
```

结果保存在 `/tmp/lutkit-hdr-ootf-audit-20261006.log`，选定测试共 32 项、0 失败。独立 Decimal 参照保持：

- HLG reference OOTF scalar `1.1102230246251565e-16`，RGB `1.3342336993997586e-16`；
- extended gamma 最大尺度化误差 `4.974256639474225e-16`；
- extended EOTF 最大尺度化误差 `7.771561172376096e-16`。

## 未覆盖与后续

本审计不勾选完整 HDR/EDR/OOTF。PQ OOTF 公式冲突继续标记研究阻塞；待取得明确的公开单位定义、独立参照和设备语义后，再按“红测、实现、Release 验证”顺序处理。Goal 保持 `active`。

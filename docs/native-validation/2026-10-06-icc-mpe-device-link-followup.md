# ICC MPE 与 device-link 边界复审

## 范围

本轮复审 `ICCMPETransform` 的处理元素通道数、`curf` 末段 `samf`、CLUT/曲线/矩阵组合，以及 `ICCDeviceLinkTransform` 的头部颜色空间语义。目标是只在 ICC.1 公开语义和独立参照同时明确时修改生产代码。

## 结论

- `mpet` 元素的零输入或零输出通道、元素链通道不匹配、CLUT 维度和 `curf` 采样段边界已有明确拒绝或执行规则。
- 末段 `samf` 使用前一段终值作为隐含起点，并延伸到归一化终点 `1.0`；现有 Debug/Release 契约已覆盖。
- 真实 Little CMS device-link 夹具 `lutcalc-srgb-p3-link-20261005.icc` 的头部 `colorSpace=RGB `、输出字段 `RGB `。device-link 的这两个字段描述链接两端颜色空间，不应套用普通 profile 的 PCS 只能为 `XYZ `/`Lab ` 规则。该 profile 的 `cmsPipelineEvalFloat` 三点参照与原生 Double 路径一致，最大差低于 `3e-5`。
- MPE tag 元素末端的额外字节是否属于 tag 对齐填充，当前缺少足够独立规范和真实 profile 对照；未增加猜测性拒绝，避免破坏用户导入 profile。

## 验证

命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter 'ICCMPEContractsTests|ICCDeviceLinkContractsTests'
git diff --check
```

结果：`ICCMPEContractsTests` 28 项、`ICCDeviceLinkContractsTests` 6 项，共 34 项通过，0 失败；`git diff --check` 通过。既有 Little CMS 外部夹具存在时已实际执行，未使用 iPhone 模拟器或厂商 LUT。结果包位于 `docs/native-validation/artifacts/2026-10-06-icc-mpe-device-link-followup/`：`release.log` SHA-256 为 `46ffb5b61b1fc55ff4843a2b4035f06bd394383fbd633d421559c7219ba90261`，`diff-check.log` SHA-256 为 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。

## 未覆盖范围

本轮不宣称完成完整 ICC、全部 MPE 元素、profile 逐码参照、黑点补偿、gamut mapping、ColorSync、`.labin`、直接查表、LUTAnalyst 全局反求或 Goal。上述范围继续保持 `active`。

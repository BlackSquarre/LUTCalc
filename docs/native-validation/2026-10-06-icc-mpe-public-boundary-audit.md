# ICC MPE 与 device-link 公开边界审计

## 范围

本轮复核 `ICCMPETransform` 与 `ICCDeviceLinkTransform` 的用户导入路径，重点检查 `cvst` 曲线集、`samf` sampled curve、`matf` 动态矩阵、`clut` 元素、ACS 占位元素、元素链通道数以及 device-link `A2B0` 的 `mpet` 路由。

## 已验证事实

- `samf` 只允许在首段之后出现；前一段提供隐含起点，末段可延伸到归一化终点；中间段按 Double 线性插值。
- `cvst` 的曲线 offset、长度、四字节对齐、共享范围和通道数均经过边界校验。
- `matf` 支持输入/输出通道数不同的动态矩阵，矩阵参数使用有限 Float32 解码后进入 Double 计算。
- `clut` 按 ICC 规范使用第一输入维度最慢、最后维度最快的索引顺序，并校验网格、长度和通道链。
- `bACS`/`eACS` 仅在输入输出通道一致时作为显式 pass-through 元素处理。
- device-link 的 `A2B0` `mpet` 路由已与真实 LittleCMS 2.19 `RGB/RGB` profile 参照复核；普通 profile 的 PCS 限制没有错误套用到 device-link。

## 验证命令与结果

```text
swift test --package-path Native/Packages/LUTKit -c release --filter ICCMPEContractsTests
```

Release `ICCMPEContractsTests`：29 项通过，0 失败。此前 device-link 组合测试及总数值门禁保持通过；`git diff --check` 通过。

## 未闭合与研究阻塞

完整 ICC MPE 元素集合、全部 profile class/intent、BPC、gamut mapping 与 ColorSync 仍未实现。对尚无公开且无独立逐码参照的元素语义不作猜测性放行或转换；本记录不扩大现有生产子集范围。


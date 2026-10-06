# LUTAnalyst 四面体分区全根枚举边界验收

## 范围

本次只闭合现有 `tetrahedral` 插值在有限 3D LUT 网格上的严格分区子集。每个输入单元固定划分为 6 个四面体；实现逐一枚举全部四面体，对输出包围盒命中的候选执行仿射矩阵反解，并以生产四面体采样器回放和 `2e-12` 相对尺度阈值认证根。相同输入根按最小回放残差去重。

报告新增 `enumeratedTetrahedronCount`、`candidateTetrahedronCount` 和 `isGloballyComplete`。只有完整遍历且没有奇异、非有限或无法认证的候选时，才允许将 `isGloballyComplete` 视为有限分区内全根枚举完成；它不表示连续 LUT 的逆存在，也不适用于三线性或 tricubic。

## 契约与实现

先行契约覆盖：恒等网格的全部 `3^3*6` 四面体计数、折叠映射的两个根、输出域外无解、严格仿射单纯形外无解，以及奇异映射必须保持 `unresolved`。实现只增加可审计计数和完成性标记，不改变 Double、网格、插值、阈值或候选算法。

## 实际验证

工具链：SwiftPM，当前 Xcode Swift 编译器，macOS 主机。

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter TetrahedralInverseContractsTests
git diff --check
```

Release 定向测试执行 12 项、0 失败。恒等 4^3 网格枚举 162 个四面体；输出包围盒命中 6 个候选。折叠网格保留两个输入根；奇异映射的 `isGloballyComplete` 为假。

## 未覆盖与阻塞

- 三线性混合项、tricubic 张量多项式存在跨单元根和奇异连续根，当前仍只能报告 `unresolved`，没有全根完备性证明。
- 任意 3D LUT 的自动 transfer/colour 分离、设备语义推断、完整重建和生成导出仍未接线；`reconstructionReport` 仅验证调用方明确提供的参考对。
- 该子集不关闭 `.labin`、直接查表、完整 ICC/HDR 或 Goal。

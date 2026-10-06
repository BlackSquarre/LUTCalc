# 并行算法工作包验收

## 范围

本轮将三个互不覆盖源码的算法工作包并行执行：三线性局部反求的严格仿射判定、传统 ICC `mft/mAB/mBA` 用户导入解析资源边界、目录到 Double 生成路径审计。没有改变 UI、设备验收或发布清单状态。

## 三线性严格仿射判定

对严格仿射单元检查混合差分；非奇异时直接求解 3x3。目标逆坐标在单位单元外时可证明返回 `noSolution`；奇异、非线性或回放失败继续返回 `unresolved`，不把有限种子结果扩展成任意 LUT 全局证明。

契约：`testStrictAffineCellCertifiesNoSolutionOutsideParallelepiped`。Release 定向 `TrilinearInverseContractsTests` 11 项通过，日志：

`docs/native-validation/artifacts/2026-10-06-parallel-algorithm-packages/trilinear-release.log`

SHA-256：`25ca523b6f3fc2d1ec96cebedddcae5b6ea3ad35e5d5bd0c26ca5f5fc787ddda`。

## 传统 ICC 资源边界

`ICCMFTTransform` 的 CLUT、输入/输出表及总字节数使用溢出安全乘加并受 profile 资源预算限制；`ICCMABTransform` 的曲线条目、CLUT 段末、对齐和样本索引同样安全。极端网格或 `UInt32.max` 曲线条目在资源使用前稳定拒绝，合法 profile 数值路径不变。

Release `ICCMFTContractsTests` 12 项通过，日志 SHA-256：`3d1ea674ef181c3402fc3b99e35920225fb86c5c7358644d7123fc6c209bfcf0`。

Release `ICCMABContractsTests` 19 项通过，日志 SHA-256：`7cf0da71119bb9096a5c700097c63e20d45a252f10ec4051cf4a40988fbe0052`。

## 目录生成路径审计

核对 `TransferID` 的 `TransformPlan` 输入解码、`NativeOutputEncoder` 输出编码和 `ColorSpaceID` 矩阵映射：79 个 transfer、20 个色域、75 个预设均有对应路径。Release `LUTCatalogChecks` 和 `RegistryContractsTests` 20 项通过。该项没有发现可安全接线的遗漏，不代表所有公式或厂商算法已经存在。

审计记录：[目录 Double 生成路径审计](2026-10-05-catalog-double-path-audit.md)。

## 未覆盖范围

这些工作包不关闭任意非线性 3D LUT 的全局根完备性、多根/切向根、自动 transfer/colour 分离、完整重建、`.labin` `0/9`、直接查表 `0/45`、完整 ICC、HDR/EDR/OOTF、资料阻塞、平台交互或发布验收。Goal 继续保持 `active`。

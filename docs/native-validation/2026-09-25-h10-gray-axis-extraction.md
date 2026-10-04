# H10 灰轴提取阶段验收

日期：2026-09-25。范围：从已有纯 Swift `LUTVolume3D` 提取输入域归一化对角线的样本，并报告这条线的分段重建残差。这只是 LUTAnalyst 的灰轴基础，不表示三维 LUT 可被一维曲线完整重建或已恢复原始相机曲线。

## 契约与实现

- 先新增 `GrayAxisContractsTests`，Release 定向运行在编译阶段因缺少 `GrayAxisAnalyzer` 失败；红灯日志 `/tmp/lutcalc-gray-axis-red.log`，SHA-256 `5a615ee58fb2465b01ae0f46d44590197ac614c1f115a87181e07d856199c8ff`。
- `GrayAxisAnalyzer.extract` 对每个 `i/(N-1)` 取输入域各通道最小值到最大值的归一化对角线，按显式指定的三线性或四面体插值读取 Double 输出。每相邻节点的中点再独立读取原三维 LUT，报告原值与两端灰轴输出线性重建间的最大通道绝对误差；报告中保留采样方法、插值方式和探针数量。
- 批量覆盖 3 条仿射灰轴（含负斜率）、非线性通道交叉项、三通道输入域各不相同的样本。非线性交叉项中点残差实测 `0.0625`，防止把三维耦合误报为零。域外策略固定拒绝，未改原数据或最终 LUT 生成。

## 验证与边界

- `swift build --package-path Native/Packages/LUTKit -c release --target LUTAnalysis`：通过。
- `swift test --package-path Native/Packages/LUTKit -c release --filter GrayAxisContractsTests`：3 项通过、0 失败；绿灯日志 `/tmp/lutcalc-gray-axis-green.log`，SHA-256 `417db9c1cd7670958bca0f892eee63e6e54a456b6cbb82a0d08e685f858db4fd`。
- 实现与测试源码 SHA-256 分别为 `ce38f59b933629b7c9d9c0d520311262a4402515515ba48445a82f8c2870e4e9`、`9a1a83f0f2da8ce8cd4b0f74ed2b7bee637dca9a8682ee262b4c6420b04ee00c`。
- 残差仅检查归一化灰轴相邻样本中点。3D 全域重建、TF/颜色分离、非唯一性、强裁剪、噪声/病态输入及真实导入/设备运行仍未验收，H10/FULL-05 不勾选；发布门槛未通过。

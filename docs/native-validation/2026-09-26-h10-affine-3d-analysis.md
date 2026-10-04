# H10 已知可逆仿射 3D 分析阶段验收

日期：2026-09-26。

## 范围

本阶段只增加“显式 3×3 矩阵 + RGB 偏置”的仿射 3D 反求。构造时复用 `Matrix3x3.inverted(maxCondition:)` 的条件数和单位矩阵残差门槛；反求时分别检查有限值、可选输入/输出域和前向重建残差。它不把任意采样 3D LUT 当作可逆，也不实现局部 Jacobian、阻尼或全局搜索。

## 修改

- `Native/Packages/LUTKit/Sources/LUTAnalysis/Affine3D.swift`
  - 新增 `KnownAffine3DTransform` 和结构化错误。
  - 缓存通过矩阵条件检查的逆矩阵；反求后再次前向计算并检查残差。
- `Native/Packages/LUTKit/Tests/LUTAnalysisTests/Affine3DContractsTests.swift`
  - 覆盖非对角矩阵往返、域外/裁剪结果拒绝和奇异矩阵拒绝。

源码 SHA-256：

- `Affine3D.swift`：`e958cc39b305eb63e46d27738ec4ef74f18314f78a6982de641164de962ef9ec`
- `Affine3DContractsTests.swift`：`515521caa67e652e127bb00245511841f8c59572b29b2df1513b8c51905ea458`

## 实际验证

1. `swift test --package-path Native/Packages/LUTKit -c release --filter Affine3DContractsTests`
   - 退出码 `0`。
   - `Affine3DContractsTests`：3/3 通过。
2. `swift test --package-path Native/Packages/LUTKit -c release list`
   - 当前测试清单：259 项（包含本阶段新增 3 项）。
3. `swift test --package-path Native/Packages/LUTKit -c release > /tmp/lutcalc-affine-3d-swift-release-20260926.log 2>&1`
   - 退出码 `0`；`LUTAnalysisTests` 16/16 通过，整包测试通过。
   - 日志 SHA-256：`5e514e698f3405cac50f958c366cedaf6c7ce32080c5343c85e5837afa4980aa`。
4. `bash tools/native-validation/verify-native-release.sh > /tmp/lutcalc-h10-affine-3d-release-20260926.log 2>&1`
   - 7 个公式检查、46 对 CUBE 生成/读回、三平台 Release 构建和三个 App 包资源审计通过。
   - 入口退出码 `2`，唯一失败项仍是缺少真实 `docs/native-validation/full-scope-acceptance.json`。
   - 日志 SHA-256：`4605238e7c6f58bf0c9204ba8f4f13f46168dd3cf300a537b6a5efeca50179aa`。

## 结论与边界

已知仿射模型的逆变换、条件数门控、域外和奇异失败均有可运行契约。该实现不能证明任意 3D LUT 的全局唯一性；裁剪、多对一和局部奇异仍须报告失败或保持研究阻塞。完整 LUTAnalyst TF/颜色分离、旧 cubic/tricubic、真机 Files/File Provider 与全量发布验收仍未完成。

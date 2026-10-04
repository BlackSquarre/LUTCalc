# H11 ProPhoto 与 BBC 参数化 Gamma 批次验收

日期：2026-09-25。状态：阶段通过；H11、CORE-03、完整调节链、真机和发布门槛仍未完成。

## 本批实现

- `ProPhotoTransfer` 按公开 ROMM/ProPhoto 的 `1/512` 线性切点、16 倍低段斜率和 1.8 幂律实现纯 Swift `Double` 编解码；负值按扩展数据的线性分支保留，不夹取。
- `BBCGammaTransfer` 批量接入 BBC 0.4、0.5、0.6，显式保存指数、偏移、线性切点和 data/legal 标度，严格区分正向 `>` 与逆向 `>=` 边界。
- ProPhoto D50 色域原色由解析色度计算矩阵，未打包 LUT、`.labin` 或等价采样表。
- 三条 BBC 曲线与 ProPhoto 已接入 `TransformPlan`、`TransferID`、`ColorSpaceID` 和 `AlgorithmCatalog`。

## 先失败后通过的契约

- `ProPhotoBBCContractsTests` 定向 Release 5 项通过。
- 覆盖 ProPhoto 分段常数、负值/超白往返、BBC 三条曲线的低段/高段和逆函数、非有限拒绝、TransformPlan 恒等往返及注册表来源/身份。
- `LUTCoreTests` 对 `LUTCatalog` 的依赖已显式声明，避免测试目标只在增量构建中偶然链接成功。
- 注册表当前为 37 条曲线、13 个色域、23 个研发预设；APP-03 检查入口的固定计数已同步更新。

## 限制

本批只验证解析曲线与同空间最小计划。ProPhoto 的完整 D50↔D65 工作流、BBC 设备范围、HDR/OOTF、其他参数化 Gamma、完整旧调节链、目标软件往返、真机和发布验收仍未完成；不把阶段结果称为完整迁移。

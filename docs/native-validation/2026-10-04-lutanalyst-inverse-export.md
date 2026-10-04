# 2026-10-04 LUTAnalyst 一维反求导出接线验收

## 范围

本项只核验已有 LUTAnalyst 严格单值 1D transfer 反求计划到 3D CUBE 写出的接线，不实现自动 TF／颜色分离、重建推断或任意 3D 逆。测试从下降方向的一维 transfer 构造 `.labin`，经真实 `LABinWriter` 序列化和 `LABinParser` 解析，使解析后的量化样本、范围／插值 metadata 和方向语义进入 `ImportedLUTInversePlan`，再调用 `NativeExportService` 生成并重新解析 3D CUBE。

## 数值契约

- 使用 Double 和既有 `tricubicLegacyV1` 插值；不改变 LUT 网格、插值规则或生产阈值。
- 3³ 导出网格共 27 节点、81 个 RGB 通道值，逐值与独立反求关系 `output = 1 - coordinate` 比较。
- 最大绝对误差：Debug `0.0`，Release `0.0`；测试上限保持 `2e-12`。
- 另两项契约确认 exposure batch 的每项都携带反求计划且 fingerprint 区分该计划；1D 格式导出遇到 3D 输入反求会明确报 `.lossyRepresentation`，不会静默丢弃语义。

## 验收命令和结果

工具链：Xcode `27.0 (27A266a)`，Swift `6.4`，目标 `arm64-apple-macosx27.0.0`。

```sh
swift test --package-path Native/Packages/LUTKit -c debug \
  --filter UserLUTInverseExportContractsTests
swift test --package-path Native/Packages/LUTKit -c release \
  --filter UserLUTInverseExportContractsTests
swift test --package-path Native/Packages/LUTKit -c release
```

- 定向 Debug：3 项通过、0 失败、退出码 `0`。
- 定向 Release：3 项通过、0 失败、退出码 `0`。
- 全量 Release：LUTSharedUI `163`、LUTProject `64`、LUTPreview `94`、LUTJobs `68`、LUTFormats `61`（其中旧 `.labin` 研发样本与公开 NCP 样本各 1 项跳过）、LUTCore `236`、LUTCatalog `24`、LUTAnalysis `47`；合计 `757` 项，0 失败、2 项按既有规则跳过，退出码 `0`。

原始日志：

- `artifacts/2026-10-04-user-lut-inverse-export/targeted-debug.log`，SHA-256 `fe6889d5deffbc68f53c1f98f68a5fa04e2f9d96086e92cfe9e842c7e39a5f64`
- `artifacts/2026-10-04-user-lut-inverse-export/targeted-release.log`，SHA-256 `0e5ec9ca5fe7399f82478973dd802f62cee363cf658f8c9fb93c74c3e0217e11`
- `artifacts/2026-10-04-user-lut-inverse-export/full-release.log`，SHA-256 `67be11c0e11d1b59c3f1d25efb9e0a860e76fb9f74c3fa0a46113c7f0bbdcb6f`

## 未覆盖范围

本验收不证明用户提供任意非单调／平台 1D LUT 可逆，也不证明厂商 `.labin` 连续定义。9 个旧 `.labin` 资源、45 个直接查表注册、自动 transfer／颜色分离及完整重建、病态三维的全局多解证明和任意 3D 逆仍未完成或受资料阻塞。完整 HDR／OOTF、ICC、UI、真机性能和发布验收也不在本工作包内；不据此关闭 H11、H13、FULL 项或 Goal。

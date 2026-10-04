# 2026-09-27 VLT 可表示预设与 Swift 导出契约

## 修改

注册表新增 `dji.dlog2-to-dlog2-identity.v1`：输入/输出均为 DJI D-Log2 与 D-Gamut2，Data 范围，曝光 `0`。该预设只表达现有公式链的同空间恒等场景，不内置 LUT 或采样表。

## 契约验证

- `RegistryContractsTests.testDLog2IdentityPresetIsVLTRepresentable`：通过；三个代表性 Double 点逐通道恒等，输出均在 `0…1`。
- `VLTExportContractsTests.testDLog2IdentityPresetExportsVLT17Cube`：通过；Swift `GenerationCoordinator` 生成完整 `17³ = 4913` 节点，`FileCubeSink(.vlt)` 写出并由 `VLTParser` 读回，所有样本保持 `0…1`。
- 实际命令：`swift test --package-path Native/Packages/LUTKit -c release --filter VLTExportContractsTests.testDLog2IdentityPresetExportsVLT17Cube`，退出码 `0`；日志 `/tmp/lutcalc-vlt-export-contract.log`。
- 注册表批量检查同步更新为 44 个 transfer、14 个色域、31 个预设；`bash tools/native-validation/verify-native-subset.sh` 在预设新增后重跑退出码 `0`，日志 `/tmp/lutcalc-native-subset-after-vlt-20260927.log`。

## 未覆盖

该阶段只证明算法目录与 Swift VLT 写出具备合法项目设置；尚未取得 iPhone 11 系统保存面板、Files 独立列表、第三方 Panasonic 软件导入或 File Provider 往返证据。VLT 真机验收仍保持未完成。

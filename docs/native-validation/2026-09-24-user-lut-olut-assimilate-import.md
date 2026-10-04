# 用户 LUT `.olut` 与 Assimilate `.lut` 导入阶段验收

日期：2026-09-24。范围：将既有纯 Swift `.olut` 与 Assimilate 1D `.lut` 解析器接入用户主动只读导入草稿；仅覆盖明确的 1D 文本子集，不代表 FULL-06 或目标软件兼容完成。

## 先失败后实现

先在 `UserLUTImportContractsTests.swift` 增加 `.olut` 4,096 点和 `.lut` 三通道 2 点临时文件用例。接线前执行 Release 定向测试按预期编译失败：`UserLUTFormat` 尚无 `.olut` / `.assimilate` 成员。随后在 `UserLUTImportSession.swift` 增加两种格式枚举和扩展名分派，并在 `ProjectDocumentView.swift` 的系统选择器允许 `.olut`、`.lut`。

## 契约

- `.olut` 调用 `OLUTParser`：固定 4,096 点、12-bit 六列整数，归一化到单位域；输入 `(0.5, 0.25, 0.75)` 线性取样得到相同三通道数值。
- `.lut` 调用 `AssimilateLUTParser`：支持现有 1D `LUT: 3 N` 三通道块布局，导入值保持 Double 后取样；非 Assimilate 文本不会被猜测接受。
- 两种格式均在后台读取并沿用请求 ID 隔离、取消和 security-scoped 资源生命周期；导入只用于临时数值检查，不写入项目资产或内置转换。

## 验证

`swift build --package-path Native/Packages/LUTKit -c release --target LUTFormats` 通过；`LUTSharedUI` Release 目标也通过。定向 XCTest 已成功进入构建，但当前工作区并行 H12/H11 契约改动使全测试编译被其它目标阻断（现报 `LegacySettingsReport` 接口和缺失 `HLGTransfer`，均不在本次文件）。因此本记录不把 XCTest 通过写成已完成证据，待共享工作区恢复后由主任务统一重跑。

续接复核：并行实现合入后，`swift test -c release --package-path Native/Packages/LUTKit` 于 2026-09-24 从当前源码重新构建并退出 0；`UserLUTImportContractsTests` 两项通过，Swift XCTest 全包合计 96 项、0 失败。上述阻断仅是开发中的暂时状态，现已解除。该包级结果仍不等于系统文件面板或真机 Files 的完整验收。

本次源码 SHA-256：

- `UserLUTImportSession.swift`：`c8ce656cbe9c3e72bccac935fc7a0776764fb06aeea3a7087c8df5b2c69142df`
- `ProjectDocumentView.swift`：`16949a378345325ae237d0f850c5596f369aefb5765c4f32a97bdc3d6dd83ef2`
- `UserLUTImportContractsTests.swift`：`ddf772831d102deebac34b5fb5962b692122476a589a24f137e026f21fa3008e`

## 未覆盖范围

未验证 Assimilate/Resolve 实际软件导入、真实厂商方言、iPhone/iPadOS Files 授权、File Provider、项目持久化、`.olut`/`.lut` 写出及其它 FULL-06 格式；FULL-06、FLOW-03/04/06 仍未完成。

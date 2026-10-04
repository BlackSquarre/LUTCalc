# H04 `.ncp` 0100 写出边界阶段验收

日期：2026-09-25。范围：FULL-06 的 Nikon Picture Control `.ncp` 写出边界。此次交付没有伪造厂商编码器，也没有声称相机兼容；它把证据不足时的失败行为固定下来，避免误写目标文件。

## 失败契约（先于实现）

`NCP0100Writer.write(_:to:)` 对任意已解析的 `NCP0100PictureControl` 都必须抛出 `NCP0100Failure(.writeUnsupported)`。调用不得创建、截断或替换目标路径；已有目标字节必须保持不变。该契约对应当前可追溯证据：公开 638 字节 `0100` 样本和独立读取器只能支持只读布局核对，尚无带机型/固件/基础 Picture Control/生成工具记录的官方导出样本、Nikon 软件独立读回或相机导入结果。

契约先写入 `NCP0100ContractsTests.testWriterRejectsWithoutChangingTarget`，再加入实现；缺少 `NCP0100Writer` 和 `.writeUnsupported` 时预期编译失败，随后实现使该测试具备可执行的拒绝边界。

## 实现与定向检查

- `Native/Packages/LUTKit/Sources/LUTFormats/NCP0100.swift` 新增 `writeUnsupported` 失败类别和失败式 `NCP0100Writer`；实现只读取参数并抛错，不触碰文件系统。
- `Native/Packages/LUTKit/Tests/LUTFormatsTests/NCP0100ContractsTests.swift` 新增已有目标保护契约。
- 当前文件 SHA-256：源码 `7729cff05c13756eb4834db5c548e8062793cc06f98ed05abd560b5f464061ef`；契约 `674a8c788be677a6fc54ea783f072f193720680d04c0e9d8a342f575f3aad7e2`。
- `swift build --target LUTFormats --configuration release`：通过。
- 直接以 Swift 6.4 编译 `NCP0100.swift` 与最小调用器，输出 `writeUnsupported`，退出码 0；目标路径未创建。
- `swift test --filter NCP0100ContractsTests --configuration release`：当前工作树在共享 `LUTCoreTests` 的 BT1886 测试与实现不一致处先行失败（缺少 `BT1886Transfer.encodeDisplayToLuminance`、`decodeLuminanceToDisplay` 等符号），未能进入测试执行；该失败与本次 NCP 变更无关，完整回归不能据此宣称通过。

## 后续解锁回归

BT.1886 共享实现补齐后，重新执行 `NCP0100ContractsTests`：4 项中 3 项通过，公开实样 1 项因未设置路径按设计跳过；`testWriterRejectsWithoutChangingTarget` 已确认 writer 不创建、截断或修改目标文件。合并 Release 回归日志为 `/tmp/lutcalc-after-bt1886-ncp-release-20260925-rerun.log`，SHA-256 为 `cd1ca8a07166fd816ae852cf2d22cb3d54e2c61cb3f71dd545cf28dc8f6a0f62`。

NCP 写出仍保持明确拒绝；没有伪造 Nikon 编码或设备兼容性。FULL-06 仍未完成。

## 剩余限制与解锁条件

NCP 写出仍保持关闭，FULL-06 不勾选。解锁至少需要：带机型、固件、基础 Picture Control 版本和生成工具版本的受控 `.ncp` 实样；多样本字段/控制点/完整 LUT/标题编码及量化比较；Picture Control Utility 2 或 NX Studio 独立读回；对应相机实际导入。取得证据后应先扩展失败契约（仅允许已证明的 profile/参数域），再实现原子写出和独立读回，不能把旧 JS 自回归当作厂商验收。

# H12 旧设置 legal 范围只读映射阶段记录

日期：2026-09-24。状态：仅完成两个字段的候选映射；旧设置项目迁移仍关闭。

## 范围与依据

旧版 `js/lutlutbox.js:getSettings`（约第 398–412 行）将 `lutBox.legalIn`、`lutBox.legalOut` 保存为两个 radio 控件的 `.checked` 布尔值；`setSettings`（约第 446–453 行）把它们分别写回 legal/data 互斥选项；`getInfo`（约第 547–555 行）再次以布尔值传入导出流程，`js/lut-lut.js`、`js/lut-cube.js`、`js/lut-3dl.js` 用其标注输出元数据。原生 `SignalNormalization` 的 `.video`、`.data` 表达同一设置二态。本次没有证明旧引擎 legal 数值路径与原生 `CodeRange` 全程等价，因此映射仅为只读候选值，不可用于创建项目。检查器现在仅对已识别的 `v4.09`、`v4.10`，且两个字段都是真正 JSON 布尔值时，报告映射路径与原生候选值。缺失字段、数字 `0/1`、未知版本不做映射，字段仍列在 `unmappedPaths` 中。源文件继续只读，`canMigrate` 恒为 `false`。

本次没有根据旧网格尺寸、曲线显示名或其他设置推断默认值；没有创建原生项目，也没有改动旧 JS。即使两个 legal 字段已识别，旧代码的位深、裁剪、缩放、相机、调节、格式与精度语义仍待逐项核对，不能宣称无损导入。

## 契约与验证

`LegacySettingsContractsTests` 新增成功映射及缺项、数字类型、未知版本的拒绝契约。首次尝试编译因实现缺少 `LUTCore` 导入失败，修正后再次运行整包 `swift test --filter LegacySettingsContractsTests`，被共享工作区 `LUTCoreTests/NumericContractsTests.swift` 中尚无对应实现的 `HLGTransfer` 和 `AlgorithmCatalog` 引用阻断；因此**本阶段新增 XCTest 尚未得到通过结果**。`swift test --skip-build` 只运行了旧二进制的两项测试，不作为新增契约结果。

已将成功映射和数字 `1` 拒绝断言加入 `LUTProjectSessionChecks`，`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --package-path Native/Packages/LUTKit LUTProjectSessionChecks` 从新源码构建，退出码 0。既有 H12 项目会话与旧设置只读检查也通过。无数值算法或误差门槛改动。

## 剩余范围

需要在共享工作区相关测试可编译后重新运行新增 XCTest；继续逐字段验证旧设置的算法和导出语义，取得真实旧文件样本，再评估完整导入门控。当前无 UI 文件选择、File Provider 协调或真机验证。

续接复核：并行 HLG 实现完成后，`swift test -c release --package-path Native/Packages/LUTKit` 于 2026-09-24 从当前源码退出 0，`LegacySettingsContractsTests` 四项通过（含本次两个映射契约），全包 96 项、0 失败。先前的测试编译阻断已解除；其余旧字段和无损迁移仍未完成，`canMigrate` 继续为 `false`。

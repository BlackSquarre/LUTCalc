# F-Log2 C 计划色域方向身份验收

## 发现与修复

`TransformPlan.basePlanVersion` 在启用 Fujifilm F-Log2 且任一侧为 F-Gamut C 时，原先只返回固定 `minimal-flog2c-v1`。因此 `inputSpace=F-Gamut C, outputSpace=F-Gamut` 与反方向路由会获得同一计划身份；但两者的输入／输出 primaries 不同，实际矩阵路由也不同，缓存和批次身份不能合并。

现在 F-Gamut C 分支在计划身份中写入 `inputSpace` 与 `outputSpace` 两个 `ColorSpaceID`。新增契约比较 F-Gamut C 位于输入侧与输出侧的两个计划，并断言身份不同；既有 F-Gamut C 到 AP0 的计划断言同步更新。

## 验证

- 命令：`swift test --package-path Native/Packages/LUTKit -c release --filter FLog2ContractsTests`
- 工具链：Apple Swift 6.4 (`swift-driver` 1.168.6)，arm64 macOS 27.0.0
- 结果：Release `FLog2ContractsTests` 9 项通过，0 失败。
- 独立数值：本修复只改变计划身份，不改 F-Log2 公式、矩阵、精度或 LUT 生成路径；既有 published matrix 和标量/计划契约同批通过。
- `git diff --check`：通过。

## 未覆盖

该修复仅闭合 F-Gamut C F-Log2 路由的双端色域身份。其他算法分支是否将所有影响数值执行的 input/output primaries 与参数写入计划身份，仍需按族继续审计；不据此宣称全部 `TransformPlan` 身份无碰撞，也不代表完整迁移或 Goal 完成。

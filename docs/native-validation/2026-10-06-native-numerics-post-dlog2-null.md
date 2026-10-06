# D-Log2/Null legacy 修复后的原生数值门禁

## 命令与工具链

```sh
Scripts/verify-native-numerics.sh
```

工具链为当前 macOS arm64、Apple Swift 6.4 与仓库固定的 Node/原生验证脚本。完整日志保存于 `/tmp/native-numerics-20261006-dlog2-null.log`。

## 结果

命令退出码 `0`。独立数值参照、54 对 CUBE 生成/读回、目录与静态边界、H08 分块/取消、H09 导出会话、H10 根求解、H12 项目契约、H13 图像与显示取样均通过；脚本报告当前原生子集通过。已有精度样本保持：AWG3 全码最大误差 `4.246603069191224e-15`，ProPhoto 274625 节点最大误差 `2.220446049250313e-16`，均低于既定阈值。

## 未覆盖

该门禁不等价于完整 ICC/HDR/EDR/OOTF、`.labin` 与直接查表替代、任意三维全局反求、macOS/iPadOS 真实平台验收、实体 iPhone 11 新证据或发布清单完成。

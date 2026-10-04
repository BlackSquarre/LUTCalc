# H07 资源共存、H10 灰轴与 H04 NCP 稳定源码合并回归

日期：2026-09-25。源码稳定后重新执行完整入口，避免上一轮并行写入期间的静态扫描与后续构建对应不同源码状态。

命令：`bash tools/native-validation/verify-native-release.sh`。日志 `/tmp/lutcalc-h07-h10-ncp-final-release-20260925.log`，SHA-256 `997d27899ee6b98c3f63b4df4a9a100efbb204c70f68a2d0f204a0177be16005`。

| 门槛 | 实际结果 |
| --- | --- |
| 静态原生边界 | 80 个 Swift 源文件检查通过；未发现所列禁止运行时或内置 LUT 资源 |
| Swift Release XCTest | 191 项进入执行，190 项通过、0 失败、1 项按设计跳过；跳过项是未设置公开 NCP 实样路径的可选测试，实样定向 3 项通过另见 NCP 阶段记录 |
| 数值批次 | 6 个独立公式检查、36 对 33³/65³ CUBE 生成与独立逐节点读回通过；Double 与冻结门槛保持 |
| 平台构建 | macOS、iOS Simulator、iOS generic 三个 Release 构建通过 |
| App 包 | 3 个实际 App 包审计通过，没有列明的 LUT、旧 `.labin`、脚本或 WebKit/JavaScriptCore 直接链接 |
| 真机 | 本批未运行；剩余 Files/取消验收按用户安排最后集中进行 |
| 发布 | 入口退出码 2：缺少真实 `docs/native-validation/full-scope-acceptance.json`；未创建占位清单 |

这只证明上述代码与样本当前通过，不覆盖完整旧调节、目标软件/设备兼容、File Provider、全量数值或发布条件。Goal 保持 active。

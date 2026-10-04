# H12 网格与 SPI1D 边界修正后发布入口验收

日期：2026-09-24。命令：`bash tools/native-validation/verify-native-release.sh`。完整日志：`/tmp/lutcalc-native-release-final2-20260924.log`，SHA-256 `5624763bd861268c9acbbc4d06c12d9eedef944fe3c3a31d63f5ce6214a0a4dd`。

| 维度 | 本次结果 |
| --- | --- |
| 代码 | 纯 Swift 源码静态边界检查通过；此检查不能单独证明全部公式来源或间接采样依赖。 |
| 数值与契约 | 旧版 Node 11 项、Python 资源审计契约 3 项、Swift Release XCTest 111 项均通过，0 失败；现有 33³/65³ 独立逐节点参照维持原门槛。 |
| 构建 | Xcode 27.0 / Swift 6.4 下 macOS、iOS Simulator、iOS generic 三个 Release 构建均 `BUILD SUCCEEDED`。 |
| App 包 | 三个实际 App 包资源审计通过，未发现所列厂商 LUT、旧 `.labin`、脚本资源或 WebKit/JavaScriptCore 直接链接。 |
| 真机 | 本次发布入口不包含真机交互；iPhone Air 的 SPI3D 导出、独立逐节点比较以另立真机记录为准。 |
| 发布 | 退出码 2：缺少真实 `docs/native-validation/full-scope-acceptance.json`；发布门槛未通过。 |

首次完整入口在 H12 `LUTProjectSessionChecks` 遇到旧候选报告期望，退出码 1；更新夹具对明确 `oneD:false`/33³ 的期望后，独立 Release 集成入口通过，再执行以上完整入口。未创建全量验收清单，也不把局部阶段成果算作完整迁移。

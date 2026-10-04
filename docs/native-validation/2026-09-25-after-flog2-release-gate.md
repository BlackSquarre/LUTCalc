# F-Log2 官方子集后的完整回归与发布门槛

日期：2026-09-25。对应日志 `/tmp/lutcalc-flog2-release-20260925.log`。本记录只证明该次工作区源码的实际结果，不把子集通过写成全量迁移完成。

运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash tools/native-validation/verify-native-release.sh`，最终退出码 **2**。入口先完成原生子集与三平台 Release 构建，再因缺少真实全量发布验收清单 `docs/native-validation/full-scope-acceptance.json` 而拒绝发布。未生成虚假清单。

| 维度 | 实际结果 |
| --- | --- |
| 代码边界 | 静态检查 72 个 Swift 源文件；未检出该脚本所列禁止运行时、内置 LUT 文件或 Package resources 声明 |
| 旧版回归 | Node 11 项通过；Python 审计契约 3 项通过 |
| Swift 契约 | Release XCTest 125 项通过，0 失败；注册表命令行契约为 13 曲线、10 色域、13 研发预设 |
| 数值 | F-Log2 33³/65³ 全节点 Decimal 参照最大尺度化误差 `2.0677889068274172e-16`；其他已接入子集按原生入口复跑通过 |
| 构建 | macOS、iOS Simulator、iOS generic 三个未签名 Release 构建均 `BUILD SUCCEEDED` |
| App 包资源 | 三个实际 App 包审计通过，未见所列 LUT/脚本文件或 WebKit/JavaScriptCore 直接链接；不能由此证明二进制中不存在等价采样表 |
| 真机 | 本次未运行。既有 SPI3D 真机逐节点结果仍单独有效；Files 独立读回和取消状态按用户要求暂缓，最后集中验收 |
| 发布 | **未通过**。全量功能、来源/许可、真机、性能及交付证据未齐；缺少真实发布清单是入口当前报告的直接拒绝原因 |

F-Log2 的来源、切点、旧版差异与单项数值见[阶段验收](2026-09-25-h11-flog2-official-stage.md)。本次脚本不改变 H01–H14 或 FULL 项的完成勾选。

## 批量验证入口优化

原入口在每个 `swift run -c release` 时重复触发 SwiftPM 产品规划；改为一次 `swift build -c release` 后，通过同一 Release 产品目录直接连续运行 21 个契约/生成检查。优化前后 20 组数值 JSON 逐字一致，91 条契约消息中只有临时目录 UUID 不同；两次均退出码 0。

| 运行方式 | 结果 |
| --- | --- |
| 优化前 | 100 秒，全部子集通过 |
| 优化后 | 42 秒，全部子集通过 |
| 变化 | 约减少 58 秒（约 58%），不改变检查内容或门槛 |

后续新增曲线会先加入共享产品批次和独立参照，再统一构建；单条定向契约仍保留，便于失败定位。

# H13 文稿切换图像身份隔离阶段验收

日期：2026-09-25。范围：原生文稿功能草稿中已导入图像的数值取样身份；不改变图像颜色解释、显示变换或最终 LUT 生成。

## 契约与修复

`ProjectDocumentView` 原来只在文稿 ID 改变时清理用户 LUT 检查状态。若同一视图承载另一文稿，已加载的图像、取样记录和“按当前项目解释源 RGB”的确认仍可能留存。H13 的文稿身份约束要求切换后不能复用前一文稿的源解释，也不能让取消后迟到的图像覆盖新文稿状态。

先在 `LUTDocumentSampleChecks` 增加两条可观察契约：已加载图像切换文稿后清空图像、URL 与取样，取样报 `noImage`；加载中切换后，即使模拟加载器随后返回，旧图像也不被接纳。首次 Release 构建因 `resetForDocumentSwitch()` 尚不存在而失败；日志 `/tmp/lutcalc-h13-document-switch-red-20260925.log`。

新增 `ProjectSampleSession.resetForDocumentSwitch()`：取消当前加载任务、失效请求 ID、清空图像与取样并将状态恢复为 `idle`；已关闭会话不重新打开。文稿 ID 变化时，草稿界面同时撤销源解释确认并清空坐标与错误。旧版迟到结果由现有请求 ID 门控拒绝，未将任何图像缓存在新文稿中。

## 已完成验证

独立夹具由 `python3 tools/native-validation/generate-preview-fixtures.py /tmp/lutcalc-h13-document-switch-20260925` 生成，仅在研发临时目录。执行 `swift run -c release --package-path Native/Packages/LUTKit LUTDocumentSampleChecks /tmp/lutcalc-h13-document-switch-20260925` 退出码 0；原有 8-bit RGB Double 曝光样本最大绝对误差仍为 0，新增切换与迟到结果契约通过。日志 `/tmp/lutcalc-h13-document-switch-green-20260925.log`。

与 H04 CUBE 非有限值修复整合后，`bash tools/native-validation/verify-native-release.sh` 的 Node 11 项、Python 审计 3 项、Swift Release XCTest 121 项、macOS/iOS Simulator/iOS generic 三个 Release 构建及三个 App 包资源审计通过。日志 `/tmp/lutcalc-h04-h13-integrated-release-20260925.log`；发布入口退出码 2，仅因真实全量验收清单 `docs/native-validation/full-scope-acceptance.json` 尚不存在，未伪造清单。

| 文件 | SHA-256 |
| --- | --- |
| `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectSampleSession.swift` | `ed4e0adc59c2e518b5eb435d0c9036ad95e6a957556745d38a70ecd1a10488b7` |
| `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift` | `4a0a9f2e322c5931c985c8511836615b7821256756a8f27f9d7216b261edb10d` |
| `Native/Packages/LUTKit/Sources/LUTDocumentSampleChecks/main.swift` | `f252d060da652b97a3cefaef595c4980938fac69c0d3ebb6e2fd29c4ac4e4cc1` |

## 边界

此次只验证纯 Swift 会话与草稿接线的文稿切换状态；整图显示、ICC 字节校验、显示空间转换、Core Image、iPad/真机交互和完整 H13/UI-03 验收仍未完成。后续真机测试按用户安排集中到最后进行。

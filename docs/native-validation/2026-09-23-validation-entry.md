# 原生验证入口阶段记录

日期：2026-09-23。本阶段增加可重复运行的原生子集检查与发布检查入口；子集通过不代表完整迁移或发布就绪。

## 修改与执行

新增 `audit-native-sources.py` 静态检查：扫描两端 App 和 Package 的 Swift 源码目录，拒绝 WebKit/JavaScriptCore 运行时符号、自有 C/C++/JS/HTML 源文件、常见 LUT 采样资产和 Package resources 声明。它只能证明本次扫描范围内没有这些直接依赖，不能证明矩阵参数、间接采样依赖或最终 `.app` 资源包完整合规；后续仍需完整 ALG-01/02 审计。

新增 `verify-native-subset.sh`，串行执行静态扫描、旧风险复现、冻结夹具校验、旧 JS 测试、Swift Release 构建，以及数值、注册表、项目、CPU 预览、任务、会话和分析的可运行 Swift 契约入口。实际运行 `tools/native-validation/verify-native-subset.sh` 退出码 `0`；扫描到 34 个 Swift 源文件；旧 JS 测试为 9/9；其余子集契约均通过。旧风险工具输出 `LEG-01…07` 是已知缺陷复现，不是新 Swift 的预期结果。

新增 `verify-native-release.sh`，在子集检查后要求完整 Xcode、iPhoneOS/模拟器 SDK、XCTest 与 Mac/iOS/iPadOS 对应构建，再用 `check-release-evidence.py` 要求 H01–H14、三平台、算法审计、精度、覆盖和使用说明都有已验证证据引用且无未解决能力阻塞。结构检查无法证明证据内容真实，发布前仍需人工审阅。实际运行 `tools/native-validation/verify-native-release.sh` 退出码 `2`：子集检查先通过，随后 `xcodebuild -version` 提示当前开发目录是 `/Library/Developer/CommandLineTools`，缺完整 Xcode，脚本明确报告发布门槛未通过。单独运行 `python3 tools/native-validation/check-release-evidence.py` 也以退出码 `2` 报告缺少全量验收清单；没有创建虚假的通过清单。

随着 Package 增加检查 target，重新实际执行 `xcodegen generate --spec Native/project.yml` 与 `plutil -lint Native/LUTCalc.xcodeproj/project.pbxproj`；工程成功生成，项目文件语法为 `OK`。这仍不等于 `.app` 构建。新增中文 [`Native/README.md`](../../Native/README.md) 说明研发预览、可运行命令与未完成范围。

SHA-256：`audit-native-sources.py` 为 `b93ccaa2500127157bdec4720bf7287a204cb77a9c89a0d9f1de1eddbac06f0c`；`verify-native-subset.sh` 初版为 `07bd788d62d76c123c245d52ab4c30bf524d41ea697f1d51a1b8693abf8c7069`，增加 H04 六方言检查后的当时版本为 `08e2feedb1d76cf710179c76f2952a6cc87ab96dd0cf9a0801331adacea773f3`，最新版本哈希见[BASE-05 阶段诊断记录](2026-09-23-base05-stage-diagnostics.md)；`verify-native-release.sh` 为 `0bb45ee9322f6fa69e821c8e85704a29794f188be545c0803c0440d6b45204dc`；`check-release-evidence.py` 为 `7144bd8bcd721199408510650da2822839affc64422dc4c889cd61c2eb8abcb1`。

## 未覆盖

发布脚本尚未运行到 Xcode 构建和真机/文件提供者阶段，完整资源包审计和全量功能证据缺失。完整迁移仍有大量 H14 功能和资料阻塞，Goal 不得标记完成。

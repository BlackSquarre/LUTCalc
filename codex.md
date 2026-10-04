# LUTCalc Codex 项目规则

## 执行前提

- 每次处理任务前先读取根目录的 `AGENTS.md`；它包含文档语言、手工 bundle 镜像和测试入口等项目约定。
- 本项目没有 npm 依赖或构建脚本。Node 测试使用 Node 18+ 内置 test runner，Swift 原生包使用 SwiftPM，App 使用 Xcode。
- 文档使用中文撰写；代码注释沿用现有英文风格。不要把构建缓存、临时日志或生成的 `.xcresult` 提交到仓库。
- `Native/Packages/LUTKit/.build` 和 `Native/DerivedData` 是增量缓存。默认不要清理；只有缓存损坏、工具链变化或明确要求时才清理。

## 最快测试路径

### 快速 Test

```bash
Scripts/verify-native-fast.sh
```

此入口同时启动 Swift Release XCTest 和 Node 契约测试。Swift 编译、Swift 测试和 Node 测试默认使用全部逻辑核心，复用已有 SwiftPM 增量缓存。

### 原生数值与静态验证

```bash
Scripts/verify-native-numerics.sh
```

该入口通过 `tools/native-validation/verify-native-subset.sh` 执行静态检查、冻结夹具、Node 测试、Swift 命令行契约、公式批次和 CUBE 生成/读回。彼此独立的验证命令、公式检查和 CUBE 案例默认并行运行，输出仍按清单顺序报告。

### 完整 Release 验证

```bash
Scripts/verify-native-release.sh
```

Release 入口必须保持以下并发关系：

- macOS、iOS Simulator、iOS device 三个 Xcode Release 构建同时启动。
- 三个目标使用独立的 `DerivedData` 子目录，避免并发构建锁互相等待。
- App 构建期间同时运行原生子集验证和 App bundle 审计测试。
- Xcode 使用 `-jobs` 和 `-parallelizeTargets`，SwiftPM 使用全核编译和测试。
- 构建完成后才运行 App 包审计和全量发布证据清单检查。

发布入口最后可能因为缺少 `docs/native-validation/full-scope-acceptance.json` 返回退出码 2。这是发布证据门槛，不代表编译、单元测试或 App 包审计失败；不能通过脚本绕过该门槛。

## 并行参数

默认并行度是当前机器的逻辑核心数，优先保证速度。只有机器出现内存压力、系统过热或工具链不稳定时才降低并行度：

- `LUTCALC_CPU_COUNT`：所有入口的默认逻辑核心数。
- `LUTCALC_SWIFT_JOBS`：Swift 编译任务数。
- `LUTCALC_TEST_WORKERS`：Swift XCTest worker 数。
- `LUTCALC_VALIDATION_WORKERS`：静态/冻结夹具验证 worker 数。
- `LUTCALC_BATCH_WORKERS`：公式和 CUBE 批次 worker 数。
- `LUTCALC_DERIVED_DATA_PATH`：Release 持久化 DerivedData 根目录。

例如，在 10 核机器上保持最快默认配置：

```bash
LUTCALC_CPU_COUNT=10 Scripts/verify-native-fast.sh
LUTCALC_CPU_COUNT=10 Scripts/verify-native-release.sh
```

## 修改后的验证选择

- 只改 JavaScript 或网页 bundle：先运行 `node --test tests/*.test.js`；若涉及注册表或 bundle 镜像，再运行 `Scripts/verify-native-numerics.sh`。
- 只改 Swift Package：运行 `Scripts/verify-native-fast.sh`；涉及格式、数值、项目存储或导出边界时追加 `Scripts/verify-native-numerics.sh`。
- 修改 App target、Info.plist、Xcode 工程或 SwiftUI 入口：运行 `Scripts/verify-native-release.sh`。
- 修改验证脚本本身：至少运行 `bash -n Scripts/*.sh tools/native-validation/*.sh`、`python3 -m py_compile tools/native-validation/*.py`，再运行受影响的入口。
- 不要重复执行同一入口来“确认通过”；使用一次完整结果和失败命令定位问题。只有修改后或缓存状态改变时才重跑。

## 现有手工 bundle 约定

如果修改色彩空间或伽马注册表，必须同步检查并更新以下手工镜像：

- `js/lutcalccombined.js`
- `js/gammaworkerscombined.js`
- `js/colourspaceworkerscombined.js`

注册表覆盖位置见 `docs/cs-tf-coverage.md`。

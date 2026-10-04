# 2026-10-02 曝光批量自动检查点与本地进程恢复验收

## 范围与契约

UI 继续暂缓。本阶段新增 `ExposureBatchCheckpointStore` 与 `ExposureBatchCoordinator.generate(...checkpoint:resuming:)` 后端入口。调用方提供重建后的同一不可变请求和检查点目录；选择此入口后，初始状态、每项生成意图、准备提交、完成、失败／取消及最终状态由后端自动保存，不再要求调用方逐项写报告。此前显式 `resumeFrom` 入口保持原有语义。

这是本地 macOS 进程恢复阶段，不是 iOS 后台终止、真实 File Provider/iCloud、全部格式或全量迁移验收。原生项目仍 schema 15，曝光批次尚未保存为项目预设；来源项目／用户资源的自动重发现、授权书签和 App 后续入口仍欠。

### 持久化顺序

1. 用排他 `mkdir` 创建用户明确指定的检查点目录（输出目录的直接子目录），创建 owner UUID；已有目录／符号链接拒绝，不覆盖现有内容。
2. 对 lease 文件持有非阻塞 `flock` 排他锁，覆盖整次生成／恢复，防止不同 actor／不同进程同时操作。进程退出后由系统释放锁。
3. 先保存 generating 意图：项索引、UUID staging 文件名和已授权目标的原始 device／inode／SHA-256，或明确不存在。使用既有流式服务生成到该专用目录中的 staging 目标，不能先发布到用户目标。
4. 生成成功、节点数验证后，取得 staging 的 device／inode／SHA-256，保存 prepared 意图。报告中该项仍为 running。
5. 在 NSFileCoordinator 回调内重新检查目录、staging 和原始目标身份，再原子发布／授权替换。默认不覆盖；目标已被外部替换则停止。
6. 成功发布后先保存 completed 收据，再允许取消阻止下一项。最后保存整个批次 completed。

检查点 schema 1 为带 SHA-256 的 payload envelope，含 owner UUID、递增 revision、请求指纹、完整报告、单项 active 意图及已放弃的 staging 名称。写入独占临时文件、同步数据、原子替换及目录 fsync；所有普通返回路径释放租约。暂存与目标同一目录树，不跨卷复制替代原子发布。

### 恢复与拒绝边界

- 先核对版本、owner、全部结构／重复字段／未知字段、4 MiB 预算，再匹配请求指纹和逐项身份。复用原生项目的严格 JSON key scanner，移至 LUTCore 包内共享；不是另建第二套解析实现。
- 全部已完成目标先核对真实 device／inode／SHA-256，任何缺失、修改或等字节 inode 替换拒绝；不重新生成掩盖变化。
- active=prepared：目标已经具有所记录 staging 身份时，补记完成；目标仍为原始授权身份、staging 身份未变时，继续发布，不重复计算。其余情况停止。
- active=generating：没有持久化提交证明。使用新的 UUID 重新生成；未记录身份的旧 staging／半成品仅保留在专用目录中，不当成完成数据，不自动发布或删除。
- 检查点写入／提交错误向调用方抛出，保留最后持久化事实和已有目标。保存失败时不能把内存状态冒充落盘状态；重新进入必须重新核对。导出服务明确失败／取消且检查点仍可写时，会保存对应终态。
- prepared 尚未发布时取消，保存 cancelled 和 prepared 意图；显式恢复才能继续。发布成功后的取消保留 completed 收据。

SHA-256、UUID 与 inode 不是签名、授权凭证或防恶意伪造机制。恢复依赖调用方明确选择此目录并重建同一请求；不能凭外部 JSON 授权覆盖、推断来源项目，或把修改过的采样表冒充可信算法。此阶段证明正常本地进程被终止后的恢复，不声称突然断电／损坏存储的持久性或非协作外部写入的全域原子性。

## 先行测试、失败与修复

- `contract-red.log`：接口缺失，实际退出 1，保留原编译失败。
- `debug-first.log`：实际退出 1，Swift 6 检出局部 async 保存函数捕获可变状态的隔离问题。改为 actor 内部接受不可变快照的保存方法，不使用 unchecked Sendable 绕过。
- 初始五边界及追加严格结构／取消契约的通过日志全部保留。
- `cancellation-red.log`：prepared 阶段取消抛出而未记录取消状态，实际退出 1；随后按契约修复。
- 最新 `debug-final-eight.log`：**8 项／0 失败**，包含真实进程、独立文件、原子提交窗口、同进程／跨进程租约、外部目标变化／检查点写入竞争、严格结构／归属／等字节 staging inode 替换及取消边界。

## 真实进程终止与独立重启

研发 CLI `LUTBatchRecoveryChecks` 是独立 Swift Package executable，不是 App 依赖或资源。XCTest 启动其实际可执行文件，到边界写标记并 SIGSTOP 后，另一个进程核对租约 busy，再以 Darwin `kill(pid,SIGKILL)` 终止子进程，确认退出原因 uncaughtSignal／信号 9。随后启动新的 CLI 进程恢复，确认退出 0。

| 实际终止边界 | 当时用户目标 | 新进程实际生成的 stop |
| --- | --- | --- |
| generatingSaved | 尚不存在 | 0、1 |
| partialStaging：真实文件首块已写入 | 尚不存在；专用目录中存在不可完整解析的半成品 | 0、1 |
| staged：整份文件完成，但 prepared 尚未写入 | 尚不存在 | 0、1 |
| preparedSaved | 尚不存在；准备身份已持久化 | 1 |
| published：目标已发布，completed 尚未写入 | 已存在 | 1 |
| completedSaved：首项完成收据已落盘 | 已存在 | 1 |

每个场景保存 `crash.json`（实际 pid／信号／目标存在状态／半成品）、`checkpoint-before-kill.json`、恢复后检查点、`restart-stats.json`（实际生成 stop）、完整目标 CUBE 及报告。上述事实来自实际子进程，不是只在同一 actor 中抛出异常来模拟重启。

## 数值、工具链与门槛

本包不修改数值算法、Double 路径、插值、位宽、网格或 `2e-12`。实际单批两个完整 17³ CUBE 按独立恒等／2 倍曝光定义逐节点检查 29,478 通道，最大／RMS／P99 为 0；六个真实进程恢复场景也逐节点按相同独立定义核对。33³／65³ 与其他算法／格式的既有验收由完整回归保留，不用本包 17³ 取代它们。

工具链日志为 Xcode 27.0（27A266a）、Swift 6.4、macOS 27.0（26A428）arm64、Node 22.21.0、Python 3.14.6。

全包 Release **476 项／0 失败／2 项既有可选夹具跳过**；macOS／generic iOS／generic iOS Simulator 三平台未签名 Release 构建、数值子集、源码边界与三个实际 App 包审计均退出 **0**。源码审计实际计 125 个 Swift 源文件；研发恢复 CLI 没有进入 App 资源。

独立 Python 读回检查器另核对最终 Debug／Release 的 12 个真实进程恢复案例，共 **24 个完整 CUBE／353,736 通道**，最大／RMS／P99 全为 **0**。该检查同时核对实际文件 device／inode／SHA-256、kill 前后请求／owner／revision、prepared 收据与最终目标身份及实际重生成 stop，实际退出 0；不是只汇总测试日志中的通过字样。

全量发布证据检查实际退出 **2**，真实 `full-scope-acceptance.json` 仍缺失。未创建清单、未执行完整发布入口或签名发行。

命令、先行失败、进程原始文件、实际 Debug／Release 恢复 CLI 二进制、机器结果、源码／参照／日志／App／进程产物哈希及源码内容归档保存在 [artifacts/2026-10-02-batch-checkpoint](artifacts/2026-10-02-batch-checkpoint/results.json)。历史曝光批量／1D 调度等工作包的冻结哈希保持原样。

## 尚未覆盖

真实 iPhone 11 后台挂起／终止与恢复、iPad 模拟器计算恢复、File Provider/iCloud 授权失效／外部替换竞争、磁盘故障全矩阵；源项目／用户资产重发现与安全书签、项目批次预设、全部八格式的恢复与第三方往返；设备内存／CPU／取消预算、完整相机／旧算法／ICC-HDR／LUTAnalyst 和签名发布仍欠。

本入口需调用方显式选择持久化与 resuming；不代表 App 会在任意启动时自动发现或执行遗留任务。专用目录保留孤立 staging／半成品供核对，自动回收政策尚未实现。UI 暂缓，H08/H12／FULL-08 与整体 Goal 保持 **active／未完成**。

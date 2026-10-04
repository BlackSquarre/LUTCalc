# 2026-10-04 本地文件 fingerprint 读取一致性验收

## 结论与范围

本轮修复 `LocalFileCommit.fingerprint` 的实际竞态：旧实现先按 URL 取得 device／inode，随后重新打开路径读取 SHA-256；目标在两步之间被替换时，可能将旧 inode 与新文件字节拼成一个身份，等字节替换甚至返回此前身份。晚到符号链接、打开后路径替换以及读中写入／读后截断也未被拒绝。

当前实现让身份和哈希来自同一个已打开 regular file，并核对读取前后可观察的文件／路径状态。该 helper 被现有 LUT 文件 sink 和批量 checkpoint 使用，不改变数值内核、Double、网格、位宽、插值、项目 schema 或导出内容。

UI 继续暂缓。本轮只证明本地 APFS 文件读取一致性子集，未证明真实 iCloud／File Provider 或最终替换全域原子性。H08/H12/FULL-08 与整体 Goal 保持 active。

## 契约先行与原始红灯

先新增八项 `LocalFingerprintStabilityContractsTests`。为了在真实操作边界确定性复现竞态，给旧生产实现加入默认 nil 的内部 boundary 钩子；钩子只在原有识别／打开／逐块读／读完处回调，没有改变旧读取和返回逻辑。保留此时源码 `before-repair-LocalFileCommit.swift`。

运行旧实现退出 1，八项测试、六次失败、0 unexpected。失败包括：打开前等字节 inode 替换未报错，晚到 symlink 被打开且未拒绝，打开后路径替换未拒绝，读中原位写入未拒绝，读完后的截断未拒绝。正常空／小／多块文件、初始非 regular 拒绝和异常关闭契约同时保留。

随后实现修复，Debug 八项通过。再补独立进程 `/bin/mv` 实际替换契约，在新证据目录最终 Debug 九项通过。这里不是只用内存 mock 模拟外部竞争：结果包保存实际父／子 PID、退出码、源／目标和替换后的 inode／SHA。

## 实现与规范来源

使用 Apple 系统文件 API，不增加自有 C/C++ 内核：

1. `lstat` 检查文件 URL 指向 regular file，拒绝非法 URL、NUL 和非 regular 对象。
2. 使用只读 `open`，带 `O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK`。从 `fstat` 获得真实已打开对象，核对与识别阶段相同。
3. 用该描述符的 Foundation FileHandle 和 CryptoKit SHA256 按既有 1 MiB 块读取；累计字节数检查溢出。
4. 读后重新 `fstat` 和 `lstat`，比较 device、inode、mode、size、mtime／ctime 秒和纳秒，要求实际字节数与起始 size 相同。观测到变化报 `targetChanged`；symlink 或非 regular 报 `unsafeTarget`。
5. 所有打开后的异常都关闭描述符；不修改竞争方文件。稳定输入保留 `device:inode:sha256` 格式，不以缺失属性替代成 0。

公开原语来源：[Apple open(2)](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/open.2.html)、[Apple stat(2)](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/stat.2.html)。当前三个 SDK 的 `sys/fcntl.h`／`sys/stat.h` 路径及 SHA-256 同时存入 `sources.json`，实际跨平台编译验证这些系统入口。本轮未把公开手册描述扩展成 File Provider 或非协作写入的原子事务保证。

boundary 钩子是内部测试诊断，正常生产调用默认 nil；不经用户参数、项目 JSON 或 UI 启用。没有把测试样本或合成字节打入 App。

## 最终九项契约

| 契约 | 实际证据 |
| --- | --- |
| 正常身份兼容 | 空、`abc`、3 MiB 合成文件；独立 SHA 常量与 device／inode 格式一致 |
| 打开前等字节替换 | 原子写入替换 inode，读取拒绝，竞争方字节保留 |
| 晚到 symlink | 在识别后替换为链接，未进入 opened 回调，referent 字节不变 |
| 打开后路径替换 | fd 仍指向旧对象时改变路径 inode，读取拒绝 |
| 多块读中原位变化 | 读取首块后原 inode 写入首 1 MiB，读取拒绝；实际新字节保留 |
| 读后截断 | read 结束边界把文件改为一字节，读取拒绝 |
| 非 regular | directory／symlink／FIFO 初始对象在读取前拒绝 |
| 异常关闭 | opened 回调抛 CancellationError，fcntl 观测 EBADF，源文件字节保留 |
| 实际独立进程 | `/bin/mv -f` 在识别／打开间完成等字节替换，子进程与父 PID 不同且退出 0，helper 拒绝变化目标 |

## 独立核对与误差

[`verify-fingerprint-stability.py`](../../tools/native-validation/verify-fingerprint-stability.py) 使用 Python `os.lstat`／`hashlib` 和独立构造字节核对实际文件；不用生产 Swift 获取 expected。两套最终产物各核对 11 个 regular file、6,291,493 字节，全部字节完全一致，最大字节差为 0；记录的当前 fingerprint 与 Python 的实际 device／inode／SHA-256 相同。

脚本同时要求等字节替换前后 inode 不同、原位修改的 inode 相同但 digest 改变；确认 symlink／FIFO 实际结构和独立进程 PID／exit。正常三文件的已知 SHA-256 未改变。此工作包没有修改色彩计算，字节／身份一致性不当作新的浮点精度提升；原有 `2e-12` 数值门槛保持。

## 编译、回归与发布边界

- 最终 Debug／Release 定向各九项，0 失败，退出 0。
- macOS、iOS generic、iOS Simulator 未签名 Release 三平台均 `BUILD SUCCEEDED`，退出 0。复用三个独立 DerivedData 目录并对当前源码重新构建。
- 150 个生产 Swift 文件和三个实际 App 包审计通过，退出 0；静态扫描不能证明完整公式来源或所有间接采样依赖。
- 完整 Swift Release `--no-parallel` 执行 654 项、0 失败，退出 0；既有 `.labin`／NCP 两项可选外部夹具按设计跳过。各 bundle 计数见 `results.json`：LUTSharedUI 145、LUTProject 56、LUTPreview 91、LUTJobs 67、LUTFormats 56、LUTCore 183、LUTCatalog 24、LUTAnalysis 32。
- 发布证据检查仍退出 2，缺少真实 `docs/native-validation/full-scope-acceptance.json`，没有创建或伪造该清单。

## 复现与结果包

工作目录 `/Users/lingru/claude/LUTCalc`。Xcode 27.0（27A266a）、Swift 6.4、macOS 27.0 arm64、Python 3.14.6，三平台 SDK 27.0。命令、工具链、红灯／绿灯／构建／审计原始日志、真实文件、进程／身份 JSON、独立核对、SDK 来源哈希、修改前／后的源文件快照和 SHA-256 清单保存在 [`artifacts/2026-10-04-fingerprint-stability/`](artifacts/2026-10-04-fingerprint-stability/)。

```sh
LUTCALC_FINGERPRINT_ARTIFACT_DIR="$PWD/docs/native-validation/artifacts/2026-10-04-fingerprint-stability/debug-final" swift test --package-path Native/Packages/LUTKit --filter LocalFingerprintStabilityContractsTests
LUTCALC_FINGERPRINT_ARTIFACT_DIR="$PWD/docs/native-validation/artifacts/2026-10-04-fingerprint-stability/release" swift test -c release --package-path Native/Packages/LUTKit --filter LocalFingerprintStabilityContractsTests
python3 tools/native-validation/verify-fingerprint-stability.py docs/native-validation/artifacts/2026-10-04-fingerprint-stability/release --output docs/native-validation/artifacts/2026-10-04-fingerprint-stability/independent-release.json
swift test -c release --package-path Native/Packages/LUTKit --no-parallel
```

重跑生成应使用新的证据目录，避免旧 symlink／FIFO／目标干扰。

## 未覆盖范围

- 只验证可观察的本地文件状态变化，不承诺任意并发写入的数学快照、对抗性时间戳恢复或路径 compare-and-swap。
- 哈希返回后到 `replaceItemAt` 的非协作写入窗口仍未闭合；本轮未改动 NSFileCoordinator／最终替换策略，不能据 helper 的绿灯证明所有目标替换竞争已解决。
- 末端 O_NOFOLLOW 不提供祖先目录身份保护；目录替换、路径别名及真实 File Provider 语义还需单独契约和实际平台证据。
- 缺少真实 provider 授权／stale／生命周期、完整磁盘故障、iPhone 11 后台终止恢复、设备 CPU／峰值内存／取消预算、iPad 模拟器基线、签名发布及完整算法／ICC／HDR／LUTAnalyst／第三方互操作验收。
- 本轮没有新增 UI、设备或目标调色软件操作；H/FULL 不勾选全量完成。

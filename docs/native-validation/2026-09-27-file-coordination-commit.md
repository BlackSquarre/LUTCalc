# 2026-09-27 文件提交协调与替换竞态阶段验收

## 范围

本阶段把本地导出提交的协调边界集中到 `LUTJobs/LocalFileCommit`，供 CUBE、SPI1D、SPI3D、3DL、VLT、ILUT、OLUT 和 Assimilate sink 复用。目标是让 File Provider 可插入的协调回调与本地“目标身份未改变”检查位于同一提交边界；不把本地测试当作真实第三方 Provider 行为证据。

## 契约与实现

- `publishNoOverwrite` 现在通过 `NSFileCoordinator.coordinate(writingItemAt:)` 执行 `beforePublish` 与硬链接提交；目标在回调期间出现时返回 `FileSinkError.targetExists`，临时文件保留给 `abort` 清理。
- 新增 `replaceIfUnchanged`，在同一协调回调内校验设备号、inode 和 SHA-256 指纹，再调用 `replaceItemAt`；外部替换即使字节相同也返回 `FileSinkError.targetChanged`。
- 删除 SPI1D、ILUT、OLUT、Assimilate sink 中重复的仅内容哈希实现，统一使用 `LocalFileCommit.fingerprint`。

## 实际命令与结果

- 工具链：Xcode `27.0`（`27A266a`），Apple Swift `6.4`；本阶段只改变文件提交路径，不改变 Double 样本、网格、插值、格式量化或冻结误差阈值，因此数值误差增量为 `0`（代码路径未触及）。
- `swift test --package-path Native/Packages/LUTKit --filter LocalCommitRaceContractsTests`
  - 初次实现验证：5 项通过、0 失败。
  - 补充显式覆盖成功路径后，Release 定向复验：6 项通过、0 失败；日志 `/tmp/lutcalc-coordination-overwrite-tests.log`，SHA-256 `74799098a4c2ac06824644877866f34b53a03dc037674965e9d77c571a6d89e3`。
  - 覆盖：发布边界竞争、无覆盖发布、显式覆盖的同字节换 inode、原目标未变时协调覆盖成功、协调提交成功、协调提交失败时临时文件保留。
- `swift test --package-path Native/Packages/LUTKit -c release`
  - 退出码：`0`。
  - 日志：`/tmp/lutcalc-file-coordination-release.log`。
  - SHA-256：`5aa26bab6b786436ae70dbd5322dec53e466299808887a94c3d72c5e333ed7f5`。
  - Swift Package Release 测试全部通过；编译器仅报告既有 `try` 标记警告。
- 三平台 Release App 构建分别以 `xcodebuild -quiet` 执行：macOS、iOS Simulator、iOS generic 均退出码 `0`。日志为 `/tmp/lutcalc-coord-mac-release.log`（SHA-256 `612d7cf2a9fa7654dca3ee9b110a6c14a1fdf03707816ff7bd45d16737add333`）、`/tmp/lutcalc-coord-sim-release.log` 和 `/tmp/lutcalc-coord-ios-release.log`（后两者均为空日志，SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`）。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash tools/native-validation/verify-native-release.sh` 最终退出码 `2`；Node/Python/Swift、数值批次、三平台 Release 构建和 3 个 App 包资源审计通过，发布证据检查因缺少真实 `docs/native-validation/full-scope-acceptance.json` 拒绝。日志 `/tmp/lutcalc-file-coordination-native-release.log`，SHA-256 `bb7d4d65134af29bedd3b368e45817ef353fd9a2a335ac9ee5bfd631b5292b38`。
- `git diff --check`
  - 通过。

## 未覆盖与边界

- 尚未在真实 iCloud/File Provider 文稿上观察授权撤销、协调回调错误、外部替换和磁盘故障。
- 本地 `NSFileCoordinator` 通过不等于第三方 Provider 支持；H08/FLOW-02/FLOW-04/QA-02 仍不完整。
- 未改变 Finder 双击、iPad 多窗口/旋转、目标软件往返、完整 ICC/HDR/LUTAnalyst、性能预算、签名和发布清单状态。

## 2026-09-27 失败路径补充

为授权失效和不安全目标补充两项契约：父目录不存在时在创建暂存文件前返回 `destinationUnavailable`；目标为符号链接时拒绝准备并保持真实目标字节不变。`LocalCommitRaceContractsTests` Debug 8 项、Release 8 项均通过。

- 命令：`swift test --package-path Native/Packages/LUTKit -c release --filter LocalCommitRaceContractsTests`
- 日志：`/tmp/lutcalc-local-commit-contracts-after-provider-failures-20260927.log`
- SHA-256：`805c94529f211b673354606dc88c3f0aaeb191319c9fa36e1735e1099956c14c`

这些是本地文件系统的可执行失败语义，不等同于真实 iCloud/File Provider 授权撤销或协调错误；该外部平台验收仍未取得。

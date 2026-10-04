# H08 本地文件拒绝覆盖的原子发布阶段验收

日期：2026-09-25。范围：在本地同目录临时文件事务中，收窄“确认目标不存在”与最终提交之间的竞争窗口。此项不推广为 File Provider 或 iCloud 的语义。

## 先失败契约

新增 `LocalCommitRaceContractsTests`。一项契约在 `prepare`、写块与 `validate` 后让另一方创建目标文件，验证 CUBE/SPI3D 默认拒绝覆盖、保留竞争方字节并清理临时文件。另一项把竞争方创建精确注入到发布操作之前，要求原子发布返回 `targetExists` 且两份字节各自保持。实现前 Release 定向构建因缺少 `LocalFileCommit` 失败；日志 `/tmp/lutcalc-local-commit-red.log`，SHA-256 `d0a7bf6609fc405061cb16a02047d216a1c275b3698c3cfe1bf778347da2090f`。

## 实现与定向验证

`LocalFileCommit.publishNoOverwrite` 对与目标同目录的临时常规文件执行 POSIX `link`：若目标已存在，内核返回 `EEXIST`，映射为 `FileSinkError.targetExists`，不会替换目标；发布成功后清除临时目录项。CUBE/SPI3D/3DL/VLT 共用的 3D sink 和 SPI1D、ILUT、OLUT、Assimilate 1D sink 的默认新建提交均改用该入口。显式授权覆盖仍保持既有 fingerprint 与 `replaceItemAt` 路径，尚未证明其最终替换瞬间的竞争安全。

`swift test --package-path Native/Packages/LUTKit -c release --filter LocalCommitRaceContractsTests`：2 项通过、0 失败；日志 `/tmp/lutcalc-local-commit-green.log`，SHA-256 `0704fdda7405a256d1c79144a914efc6c076cc096346eb14a8fbb97f007c3dd7`。新增代码未改 Double、量化或文件轴序。

新增实现 `LocalFileCommit.swift` 与契约 `LocalCommitRaceContractsTests.swift` 的源码 SHA-256 分别为 `9a0014251bc8066dca25b4b3ad21e3274bc879f39fad527574e932fcc33d6faa`、`0d8b758e3108fbac2a1d3c689b6d1490ef0e9f80d3ea1366dab13711014ca328`。

此项仅证实当前本地文件系统的默认拒绝覆盖路径。硬链接能力、跨进程协调、File Provider 权限/版本竞争、显式覆盖的原子条件提交、断电持久性与真机取消仍需独立验收；H08/FLOW-02/QA-02 和发布门槛不勾选。

## 2026-09-25 显式覆盖身份竞争补充

先新增失败契约：已有目标文件在 `prepare` 后被删除并用相同字节创建新文件时，显式覆盖也必须拒绝，不能只依赖内容哈希。原实现只比较 SHA-256，因此该契约先失败并实际把新目标替换成生成结果。

修复后 `LocalFileCommit.fingerprint` 同时记录文件系统编号、文件编号和 SHA-256。内容相同但文件身份改变时返回 `FileSinkError.targetChanged`；旧目标字节保持不变，临时文件由 `abort` 清理。目录不存在、目标父路径为普通文件或无写权限时，所有流式文件 sink 在创建临时文件前分别返回 `destinationUnavailable` 或 `destinationPermissionDenied`。

定向 Release 验证：

- `LegacySettingsContractsTests`：24 项通过（H12 同批次）。
- `LocalCommitRaceContractsTests`：3 项通过，其中新增相同字节新文件身份竞争 1 项。
- 本地路径边界：普通文件父路径和只读目录各 1 项通过，均未留下临时文件。

这仍不是 File Provider/iCloud 的版本条件提交证明；显式覆盖在外部系统提供者上的竞争、断电持久性、真机取消和第三方往返继续待验收。

## 合并回归

代码稳定后执行 `bash tools/native-validation/verify-native-release.sh`，日志 `/tmp/lutcalc-h08-local-publish-release-20260925.log`，SHA-256 `6f63fa67097db42fb497bf8cb081ec04fea64ced8c551e7c41a854a53b676164`。Swift Release XCTest 193 项进入执行，其中 192 项通过、1 项可选 NCP 公开实样测试因未设置路径按设计跳过、0 失败；6 个独立公式检查与 36 对 CUBE 生成/独立逐节点读回通过。macOS、iOS Simulator、iOS generic 三个平台 Release 构建及 3 个 App 包资源审计通过。发布证据检查仍因缺少真实全量清单使入口退出码为 2；本轮未做真机运行。

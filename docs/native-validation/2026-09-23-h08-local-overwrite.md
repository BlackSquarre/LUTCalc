# H08 本地 CUBE 授权覆盖事务

日期：2026-09-23。接续[强制乱序记录](2026-09-23-h08-forced-reorder.md)。本步为 `FileCubeSink` 增加显式授权的本地已有文件替换。默认仍拒绝覆盖；只有调用方传入 `allowOverwrite: true`，且准备时目标为普通文件，才允许在验证完新临时文件后提交。UI 草稿未修改，尚未把覆盖授权接入平台文件选择界面。

## 契约、资料与实现

先在 `LUTJobChecks` 写入成功覆盖、写块中真实取消、生成期间外部修改目标，以及符号链接目标四类测试。首次 Debug 构建退出码 1，明确报缺少 `allowOverwrite` 参数与 `targetChanged` 错误类别。实现后，已有目标在 `prepare` 时流式计算 SHA-256；提交前再次流式核对，发生外部变更则拒绝覆盖。成功路径使用 Foundation `FileManager.replaceItemAt` 替换同目录的任务临时文件，并使用新文件元数据。Apple 的[替换 API 文档](https://developer.apple.com/documentation/foundation/filemanager/replaceitemat%28_%3Awithitemat%3Abackupitemname%3Aoptions%3A%29)说明此 API 的数据保全语义，且建议新文件位于目标卷的合适临时目录；本实现将临时文件放在目标同一目录。它不等同于 iCloud/File Provider 全平台原子性证明。

`FileCubeSink` 新增 `targetChanged`、`unsafeTarget` 诊断；拒绝符号链接和非普通已有目标。默认未授权路径继续返回 `targetExists`。代码没有删除用户已有文件，也没有改动旧 JS 或测试冻结预期。SHA-256 比较能检出准备与提交之间的内容变更；提交前最后一次核对与替换之间仍需平台文件协调解决竞争，故此步只作为本地文件阶段实现。

## 实际运行与结果

```text
swift run --package-path Native/Packages/LUTKit LUTJobChecks
tools/native-validation/verify-native-subset.sh
```

两条命令最终退出码 0；子集入口实际执行 Swift Release 构建与 Release `LUTJobChecks`，旧 JS 测试 9/9，静态扫描 35 个 Swift 源文件。自有临时目录中用不同于新 CUBE 的旧内容测试：授权成功后目标不再含旧字节，独立 `CubeParser` 读回的 17³ Double RGB 样本与串行生成完全相同。取消时旧字节逐字节不变，sink `aborted`；外部写入后提交得到 `targetChanged`，保留外部新字节；对指向已有目标的符号链接得到 `unsafeTarget`，被指向文件字节不变。检查目录中没有 `.lutcalc-` 任务临时文件。未授权覆盖的既有测试仍返回 `targetExists` 且原字节不变。

修改源码 SHA-256：`Native/Packages/LUTKit/Sources/LUTJobs/FileCubeSink.swift` `8986ac7309c8235c72c502ae4f343a2cb3be2c932052706ffe7ddde18889ad1f`；`Native/Packages/LUTKit/Sources/LUTJobChecks/main.swift` `bc8f8806446509edfd247727333e7ccbe57ed68b5675f30e460fa5ce68b76b2e`。`Generation.swift` 未改，哈希 `1c8fd286deedd07edad3c1052ad7220248daa8dd3825fb671e2b354c186b87a9`。本步仍用 H06–H07 已冻结数值链及原误差门槛，未改网格、位宽或插值。

## 平台与未覆盖

本次只在本机临时目录验证 Foundation 本地替换。File Provider/iCloud 协调、权限书签、目标文件在最后哈希核对与替换之间被并发改变、替换操作自身抛错后的平台位置恢复、空间不足及真实目标软件导入仍待单独验证。当前机器只有 Command Line Tools，没有完整 Xcode/iOS SDK；XCTest、两端 `.app`、模拟器和真机未执行。H08/FLOW-02/QA-02 仍只部分完成。

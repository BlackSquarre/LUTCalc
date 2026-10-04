# 2026-10-02 批次项目预设非 UI 阶段验收

## 契约和实现

UI 继续暂缓。本包将已有精确曝光批次配置保存到原生 `.lutcalc` 项目 schema 16，并在项目重开后重建不可变批次请求。不保存目标目录或覆盖授权，不在读取项目时自动生成。算法身份仍为 `native.exposure-batch-rational.v1`。

- `ExposureBatchSequence` 移入 LUTCore；LUTJobs 保留 `ExposureBatchSettings`／`ExposureBatchError` 兼容别名。整数 tick 的 Double 曝光公式、请求指纹序列化字段和用户 LUT 数值身份保持原样，与此前冻结源码的相同片段实际比较结果保存于 `identity-source-comparison.json`。
- 格式枚举移入 LUTFormats，保留 8 个 rawValue 和 `FileLUTFormat` 别名。序列共享 POSIX 命名与路径拒绝规则；完整文件名新增 UTF-8 255 字节预算，超限拒绝，不截断或降低输出尺寸。
- `ExposureBatchPreset` 保存算法、序列、basename、格式、blockNodes、workerCount；严格根／嵌套字段、未知算法／格式、无效参数及不可计算曝光拒绝。原生 schema 1–15 迁移为 nil；旧 schema 偷带新字段或身份拒绝。
- 项目 helper、文稿后端预设／gamma／用户 LUT 编辑、导入、EditorSession 保存和 undo／redo 保留配置。重建请求仍来自项目当前网格、域、算法及自包含用户资产，目录和覆盖授权由调用方显式提供。
- 没有修改界面行为。`ProjectDocumentView` 仅增加显式 `import LUTFormats`，修复共享类型迁移后的编译依赖警告；界面旧重建 manifest 路径尚未验收，留到 UI 重做，不声称 UI 字段保留。

## 先行失败和实际结果

先落实 6 项项目／文稿后端契约，再实现接口。`contract-red.log` 实际退出 1，接口缺失；`debug-first.log` 退出 1，Swift 6 要求 `ProjectExportSession` 显式导入 LUTFormats。修复后 `debug-second.log` 6 项通过，失败记录保留。

随后移除不能证明磁盘不变的重复序列化断言，新增实际 schema 15 `.lutcalc`：分别由 ProjectStore 与 ProjectEditingSession 打开，核对读取前后 manifest 字节完全一致且磁盘仍为 schema 15。保存实际前后字节和项目包。最终 `debug-final.log` 6 项／0 失败。

三平台首轮构建退出 0，但共享格式别名的 `@State` 宏产生导入缺失警告。添加显式导入后重跑完整 Release 和三平台构建；最终三个构建日志均为零字节，实际退出 0。初始警告日志继续保留，没有以首轮 App 包代替最终构建结果。

最终 `release-after-import.log`：**482 项执行、0 失败、2 项既有可选夹具跳过**（旧 `.labin` 研发夹具与公开 NCP 样本未提供）。包括 schema 1–15 迁移、全部 8 格式预设身份、参数拒绝、程序化磁盘项目重开、源用户 LUT 删除后的自包含资源重建、请求指纹一致及同检查点显式恢复。

## 独立实际文件读回

Debug 和最终 Release 各保留两个完整 33³ CUBE、两个固定 1024 点 SPI1D、项目包、检查点及旧 schema 项目。Python 检查器直接读取文本，不调用产品解析器或数值算法；预期来自有理数定义：

- 曝光序列为 −1／0 stop，即增益 1/2／1；批次替换项目原曝光，不累加。
- CUBE 用户 1D LUT 通道斜率分别为 1、1/2、1/4；R 最快，轴值为整数／32。
- SPI1D 无用户 LUT，各通道轴值为整数／1023；格式长度仍固定为 1024，不受项目 33 网格影响。

实际 **8 个文件／443,532 个通道**，最大尺度化误差、RMS、P99 均为 **0**，门槛保持 **`2e-12`**。另核对 schema 16 的全部预设字段、资源原字节／SHA-256、源文件确已删除、检查点 payload SHA 与 completed 文件收据、两份 schema 15 前后字节。文件为测试完成后的复制留存，检查点原 inode 不用于核对复制文件；同 inode 恢复由原 Swift 契约在原目录中执行证明。

本包不改数学精度、位深、插值或既有 33³／65³ 验收网格。完整数值子集另实际通过 54 个 CUBE 生成／读回对等既有门槛；本包的存储恒等夹具不冒充全部旧算法数值覆盖。

## 工具链、平台与归档

实际工具链：Xcode 27.0（27A266a）、Swift 6.4、macOS 27.0（26A428）arm64、Node 22.21.0、Python 3.14.6。

macOS、generic iOS、generic iOS Simulator 未签名 Release 构建均退出 0；数值子集、128 个 Swift 源文件边界审计及最终 3 个实际 App 包审计退出 0。静态与链接审计只证明列出的运行时／资源检查通过，不能单独证明所有间接表来源已闭合。本轮没有 UI、模拟器运行或真机操作，没有签名发行。

实际命令、工具链、红灯／警告／终态日志、独立误差结果、项目与输出文件、源码归档和哈希均保存于 [本包 artifacts](artifacts/2026-10-02-batch-project-preset/)。冻结状态见 `results.json` 与 `artifact-check.txt`。此前检查点阶段的历史证据未重新冻结。

全量发布证据检查实际退出 **2**，真实 `full-scope-acceptance.json` 仍不存在，未创建清单、未执行完整发布入口。

## 未覆盖范围

本包关闭批次预设的非 UI 项目保存与显式请求重建缺口。来源项目／用户资源自动发现、安全书签／授权恢复、真实提供商目标竞争、iPhone 11 后台恢复、孤立 staging 回收、全部格式实际批量、完整相机 ISO/EI、完整旧算法／ICC-HDR／LUTAnalyst、设备数值／性能和签名发布仍欠。自包含项目重开不等于自动发现或授权恢复；FULL-08、H08/H12/H14 不勾选，Goal 保持 **active**。

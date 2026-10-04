# 2026-10-02 Log C scene 显式 EI 与非 UI 生成接线阶段验收

## 范围与来源

接续已冻结的[公开内核](2026-10-02-logc-compact.md)，新增两条独立曲线身份 `arri.logc-sup2-scene-published.v1`／`arri.logc-sup3-scene-published.v1`，接通 SUP 2／3 各 11 个公开离散 EI 的 scene exposure 公式。`ARRILogCSceneSettings` 保存必需算法身份和 EI；输入／输出独立。阶段 2 和阶段 13 使用初始化时准备的不可变内核；后者也用于 Knee、黑白电平和 Black Gamma 的编码锚点。保持 Double、完整网格和 `2e-12`。

产品直接执行公开分段公式，不读取 PDF、参照文件、旧 JavaScript 或采样资源。参数和来源沿用归档 ARRI 2017 官方 PDF及 2012 厂商文档公开镜像；独立来源 SHA 与系数检查重新运行。完整来源、公开接缝、EI 1600 相机高光近似和旧实现冲突见[研究记录](2026-10-02-logc3-shoulder-research.md)。

当前计划的线性单位是 scene reflectance。sensor signal 的黑电平和单位不同，仍通过已有独立内核 API 表达，不混入此计划。本包没有新增相机预设或默认色域；测试的 Rec.2020 是显式同空间数值载体，不能作为 SUP 2 raw camera RGB／SUP 3 AWG3 映射证明。当前目录为 **46 曲线、14 色域、31 预设**。完整相机及 shoulder 未完成。

## 项目和后端行为

原生 schema **17** 保存 `inputLogC`／`outputLogC` 的 `algorithm`、`exposureIndex`，并在 `algorithmVersions` 保存两槽身份。缺参、未知字段、未知算法、曲线／载荷错配、未公开 EI 拒绝，不回退 EI 800或插值。schema 1–16 无新字段迁移为 nil；旧 schema 偷带字段、算法身份或新曲线拒绝，实际 schema 16 磁盘读取不写回。

计划身份包含输入／输出算法及 EI；快照保留旧配置，批次指纹随 EI 改变。设置 helper、文稿后端 `applyLogCScene`、gamma 编辑、用户 LUT 资产、批次预设、撤销／重做和磁盘重开均有契约。输出 EI 变化重置未锁定的黑白默认锚点；换掉曲线只清理对应槽的 Log C 载荷。

**UI 继续暂缓。** 未修改控件、布局或 `ProjectDocumentView` 的旧字段重建路径；本包不证明该 UI 路径保留新参数或批次预设。

## 先行失败与验证

- `debug-before.log` 退出 1：先行核心／项目契约时接口缺失；`debug-second.log` 退出 1：测试锚点表达式遗漏 `try`，原始失败保留。修复后 `debug-third.log` 核心／项目 5 项通过。
- `document-red.log` 退出 1：先补文稿、生成、文件和任务契约，后端 `applyLogCScene` 尚未实现。实现后 `debug-final.log` 8 项／0 失败；追加独立 Decimal 锚点和 EI 默认重置契约后 `debug-anchors-final.log` 核心 3 项／0 失败。
- 首轮全包 `release-final.log` **493 项／0 失败／2 项既有可选夹具跳过**。随后补足 schema 16 原始项目、读取前／后 manifest 的实际文件留存，并完整复跑 `release-with-disk-final.log`；该轮遇到已有进程恢复测试的退出等待，保存采样与子进程状态后终止等待中的 XCTest，实际退出 1，未计为通过。修复观察方式后 `release-observed-final.log` 最终 **494 项／0 失败／2 跳过**，详见 `results.json`。
- 完整 CUBE／SPI1D 真实写出和原生解析全点读回、输入／输出跨固件 EI 与 `1/3` stop 组合、磁盘文稿重开、worker 1／4 相等、注入取消后的 abort、stage 2／sample 0 非有限失败定位均有证据。这里的取消为 sink 注入，不新增真实设备后台证据。

## 已有进程测试退出等待的实际诊断与修复

追加文件留存后的完整复验，其 stdout末行由于缓冲停在 BlackHighlight 测试；实际对 PID 1486的线程采样显示等待位于 `ExposureBatchCheckpointContractsTests.swift:128` 的 `NSConcreteTask.waitUntilExit()`。进程列表中没有该 XCTest 的子进程，CPU接近空闲。保存 `release-wait-sample.txt`／`wait-diagnosis.json`，明确终止此轮 XCTest并收取退出 1；不声称确定 Foundation 内部根因，也不把未完成复验计为通过。

先补“快速子进程退出后才等待”的20次契约，`process-exit-contract-red.log` 因新观察 helper缺失退出 1。测试 harness改为运行前安装 `terminationHandler`，异步等待 XCTest expectation，15秒未观察到退出则失败；不再阻塞调用 `waitUntilExit()`。保留六个真实 SIGKILL、同一恢复进程、租约、检查点和完整文件检查。`process-exit-release.log` 9项通过；`debug-storage-process-final.log` 项目2项＋进程9项共11项通过；修复后的全包 Release 494项通过。生产算法、任务调度和事务代码没有因该测试观察修正而改变。

## 独立数值

沿用内核包独立 80／120 位 Decimal 系数参照，新增独立 SPI1D 轴、混合曝光和 Legal 锚点参照；生成器不调用产品或旧引擎，两个精度转换到 Double 一致。新增验证器独立用 Python 重读全部实际文件、项目 EI／算法身份、来源哈希和历史项目原字节。

| 验证范围 | 数量 | 最大尺度化误差 | RMS | P99 |
| --- | --- | --- | --- | --- |
| 22 配置的计划路径边界及 10/12-bit 全码，最终 Release | 113,080 值 | `1.29121509482886e-14` | `2.5131245865722955e-16` | `8.223777217213309e-16` |
| 最终 Release 真实文件的独立 Python 全点重读 | 10 CUBE、4 SPI1D／4,670,718 通道 | `2.8464710760791997e-15` | `1.6111459968779501e-16` | `6.36662777534631e-16` |

CUBE 为 SUP 2 EI 800、SUP 3 EI 1600的编码／解码各完整 33³／65³，加上 SUP 2 EI 800解码→`1/3` stop→SUP 3 EI 1600编码的两个完整网格；SPI1D 为前两配置编码／解码的完整 1024 点。其余 EI 有全码和边界覆盖，不声称 22 配置的所有网格均已运行。最终复跑的逐次指标、独立重读、schema 16 文件和哈希保存在结果包。

门槛仍为 **`2e-12`**。这验证实现相对选定公开公式的误差，不证明实际相机 shoulder、连续唯一反求或旧边界逐位兼容。

## 平台、归档与未覆盖项

工具链：Xcode 27.0／27A266a、Swift 6.4、macOS 27.0／26A428 arm64、Node 22.21.0、Python 3.14.6。macOS、generic iOS和 generic iOS Simulator 的新路径未签名 Release 构建通过，三个构建日志为零字节；数值子集、130 个 Swift 源文件边界审计和三个实际 App 包审计通过。补原字节留存与退出观察只修改测试，不改变已构建产品源码。测试编译保留既有 UserLUTProjectAssetContractsTests 的多余 try 警告；三个产品构建日志为零字节。

实际命令、终态、来源、最大／RMS／P99、14 个文件、10 份项目、schema 16 原始字节和源码／App／helper 哈希见[结果目录](artifacts/2026-10-02-logc-scene-routing/)。未覆盖真机、提供商、UI或签名发行。全量证据检查实际退出 **2**；真实 `full-scope-acceptance.json` 缺失，未创建清单，也未执行完整发布入口。

下一步继续 AWG3 的独立原色／CAT 参照和默认映射、sensor 生成单位、相机稳定 ID／ISO-EI／裁剪与 Generic；高 EI shoulder 按项研究阻塞。原有旧曲线／色域／调节链、ICC-HDR、LUTAnalyst／格式、来源重发现／提供商／设备后台、性能与签名发行范围保持。FULL-01／02、H06／H12／H14 不勾选，Goal **active**。

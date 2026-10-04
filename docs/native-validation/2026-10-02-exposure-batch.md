# 2026-10-02 精确曝光批量非 UI 阶段验收

## 实现范围

新增纯 Swift `LUTJobs/ExposureBatch.swift`：精确曝光序列、不可变逐项请求、确定文件名、单文件顺序调度、逐文件事务、取消／失败报告和显式恢复。身份 `native.exposure-batch-rational.v1`。`NativeExportService` 对批次显式传递覆盖政策，独立单次导出默认仍不覆盖；`LUTProjectDocument.makeExposureBatchRequest` 从文稿和用户资源捕获快照，不编辑文稿。

UI 暂缓，未执行设备、系统面板或第三方软件交互。当前是 FULL-08 的后端阶段；相机模型／原生预设、自动持久化检查点、进程终止和提供商恢复等仍未完成，FULL-02／FULL-08、H08/H12/H14 不勾选，Goal **active**。

## 先行契约和失败

- `contract-red.log`：实际退出 1，缺曝光批量类型／服务接口。
- 独立参照生成后，`debug-core.log` 退出 0，初始 4 项通过，包括真实文件和恢复。
- 旧 64 组矩阵对照追加后，`debug-matrix.log` 退出 0，5 项通过。
- `document-contract-red.log`：实际退出 1，文稿还没有 `makeExposureBatchRequest`。接入该后端入口后保留原失败日志。
- 最终 `debug-final.log` 退出 0，**7 项／0 失败**；全包 `release-final.log` 退出 0，**464 项／0 失败／2 项既有可选夹具跳过**。

## 曝光与名称的可追溯定义

旧来源为 `js/lutgeneratebox.js` 的 generateSet／oneDLUT／threeDLUT／got1D／got3D／saved 及 buildGenSetPopup。研发脚本实际执行 handler，冻结全部正常 64 组选项／864 点；相机列表与 CineEI 舍入的实际规则另见[相机曝光复核](2026-10-02-camera-exposure-research.md)。研发 JavaScript 未进入 App。

- minimum／maximum 为整数 stop，subdivisions 支持旧 1–4；每项为 `Double(minimum*subdivisions+i)/Double(subdivisions)`，不累加 1/3 的近似值。包含端点，零为正零，默认 -2…2／三分之一 stop。
- 曝光替换源请求的 exposureStops，不加到当前修正。本轮特意以源曝光 7 验证替换规则；曲线、色域、范围、调节、Final Output、网格、域、worker、块和用户 LUT 配置在请求层保留。单通道实际服务的既有默认行为见未覆盖范围。
- 非零后缀使用 POSIX locale 的两位 stop 小数、用 p 代替小数点；零后缀为 `0-Native`。全部 64 组名称与旧 handler 相同。两位名称不参与数值计算。
- Int 乘减溢出、反向区间、subdivisions 非 1–4、超过 1024 项资源上限、非法 basename／重复文件名、非法曝光计划在请求构造时拒绝。只拒绝超预算，不自动减少曝光项、网格或改为 Float。
- 旧 1/3 累加与一次有理换算不是逐位相同，最大 stop 差 `8.881784197001252e-16`。独立 80 位 Decimal 验证 64 组增益，最大尺度化误差 `1.3987933588031886e-16`，算法身份明确保留。

旧 minimum=0 的 handler 会抛未定义 setVal；这不在旧正常 UI 范围。最小复现保留，原生零起点有契约，没有把这项异常声称为所有旧默认曝光组不能执行。

## 实际文件与独立参照

`generate-exposure-batch-independent-reference.py` 独立计算有理 stop 和 `2^(numerator/subdivisions)`，80 位 Decimal，不读取旧输出作为预期。

- 七个曝光值 -1、-2/3、-1/3、0、1/3、2/3、1，各完整 17³ CUBE，真实磁盘写出并由 CubeParser 全节点读回。
- 曝光 0、1/3、2/3、1，各完整 33³ 和 65³，共八个真实 CUBE；同样逐节点独立比较。
- 以上共 **3,829,917 通道**，误差定义 `abs(actual-reference)/max(1,abs(reference))`；最大 `2.220446049250313e-16`，RMS `6.109331599752529e-17`，P99 `2.1314946419858114e-16`。门槛保持 `2e-12`。
- 一个原生 SPI1D 的 1024 点／三通道与独立 `i/1023` 逐项相等。其他格式沿用服务路由，但不能计作本阶段全部格式真实批量验收。

没有降低网格、位宽、插值或门槛，没有只取灰轴代替三维验证。本批数学链为 Rec.2020 同空间、Linear scene → Linear scene；不是相机 ISO/EI、HDR 或完整调节组合证明，已有调节链回归另外保留。

## 事务、取消、快照与恢复

每个文件使用既有 NativeExportService／bounded writer／暂存提交。同批只运行一个文件，不把所有 LUT 攒在内存；任务启动前已准备所有小型计划和文件名。

- 默认已有目标拒绝；实际中间目标保持原用户字节，前一文件 completed、当前 failed、下一文件 pending，未产生部分下一文件。
- allowOverwrite 显式传给全部格式 sink；实际 CUBE 授权替换通过，没有先删除已有目标。既有单文件本地修改／符号链接／替换保护契约也在全包与数值入口回归。
- 注入第二项取消得到 completed／cancelled／pending，第一项磁盘文件保留。报告实际 Codable 写入磁盘、重读后，用新 coordinator 恢复，跳过首项并完成其余项。
- 恢复先匹配算法和请求指纹，再核对每个 completed 文件的设备／inode／SHA-256 与节点数；等字节替换 inode 仍拒绝。更改源网格也拒绝恢复。请求指纹包含设置／计划版本、域、网格、块、worker、目录、名字、格式、覆盖政策及用户 LUT／shaper 参数与 Double 样本位型。
- 真实 Task.cancel 在首文件写出前取消，目标不存在；在首文件成功提交后、服务返回前取消，首文件仍记 completed，下一文件 cancelled。未将成功提交后取消误报为该文件未生成。
- 相同 coordinator 的并发启动明确拒绝。文稿后续编辑不能改变已捕获批次，Final Output 配置和用户 LUT 保留；用户资源变化改变请求指纹。真实文件事务结束后没有残留 `.lutcalc-*.tmp`。

报告 schema 1 仅定义显式保存与恢复协议，不是自动检查点，也不是带签名的可信凭证。源项目／资源仍须调用方重建同一请求；没有真实崩溃、后台终止或提供商授权证明。原生项目 schema 15 本轮未增加批次预设字段。

## 工具链与门槛

实际工具链为 Xcode 27.0（27A266a）、Swift 6.4、macOS 27.0（26A428）arm64、Node 22.21.0、Python 3.14.6；输出保存于 artifact。

- 7 项定向 Debug、464 项全包 Release，退出 0；Release 2 项既有可选夹具跳过。
- macOS／generic iOS／generic iOS Simulator 三平台未签名 Release 构建退出 0。
- 新旧曝光参照重生成核对、既有数值批量入口、Node／Python／Swift 和程序化文件契约的数值子集退出 0。
- 源码边界和三个实际 App 包审计退出 0；静态审计不证明所有间接表、完整公式来源或发行许可已经闭合。
- 全量发布证据检查实际退出 **2**，真实 `full-scope-acceptance.json` 缺失，未创建清单、未运行完整发布入口或签名发行。

命令、原失败／最终日志、机器结果、源码／夹具／日志／App 哈希及本阶段源码内容归档保存于 [artifacts/2026-10-02-exposure-batch](artifacts/2026-10-02-exposure-batch/results.json)。历史工作包哈希保持冻结，不因本阶段修改源码而更新历史记录。

## 未覆盖范围

自动检查点的原子写入与版本／归属校验、提交与记录之间的崩溃窗口、进程终止恢复、项目／用户资源重发现、安全书签、真实 File Provider/iCloud 授权失效／竞争；批次预设项目保存和完整相机 ISO/EI／Generic；全部格式批量、格式自定义精度／方言和目标软件往返仍未完成。

单通道服务沿用既有固定尺寸及默认 worker／块，批次请求中的这些提示尚未全部传递到实际 1D coordinator，需后续接通并核对资源预算。本阶段未声称所有单通道工作负载都按源 worker 配置运行。

完整旧功能、ICC/HDR、LUTAnalyst、算法来源阻塞、跨设备数值／性能、发布签名与安装升级继续未完成。UI 暂缓；可继续批次持久化／恢复和相机独立模型，Goal active。

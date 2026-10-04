# Assimilate 1D `.lut` App 导出阶段验收

日期：2026-09-24。范围：把已实现的 Assimilate 1D `.lut` 格式子集接入原生文档功能草稿导出；不代表 H04 或 FULL-06 完成。

## 实现与边界

- `NativeExportService` 按 `.lut` 扩展名建立固定 4,096 点的 `LUT1DGenerationRequest`，通过现有 `OneDGenerationCoordinator` 以 `Double` 分块独立计算 R/G/B。仅允许位模式精确的单位输入域和相同输入/输出色域；`-0.0` 域、跨色域与不可表示请求显式失败。
- `FileAssimilateLUTSink` 收集有序块，交由既有 `AssimilateLUTWriter` 写出 `LUT: 3 4096` 与 R、G、B 三个整数块。整数码值使用既有 JavaScript `Math.round` 半值向正无穷取整契约；量化前与舍入后的码值均检查有符号 32 位范围，超界时拒绝，未裁剪结果。
- 写出先在目标目录的暂存文件完成并核对字节数，再按既有文件事务提交；默认拒绝覆盖，覆盖模式检查原文件指纹，失败/取消时清理暂存文件。`ProjectDocumentView` 增加 Assimilate LUT 1D 格式选项，`ProjectExportSession` 产生可分享的 `.lut` 文件。未引入厂商 LUT 或采样资产。

## 契约与验证

先新增 `AssimilateExportContractsTests` 和 `AssimilateServiceContractsTests`。首次运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Native/Packages/LUTKit -c release --filter 'Assimilate(Export|Service)ContractsTests'` 因 `.lut` 格式枚举及 `FileAssimilateLUTSink` 缺失而编译失败；日志 `/tmp/lutcalc-assimilate-export-red-20260924.log`。实现后同命令原有 4 项通过，0 失败；日志 `/tmp/lutcalc-assimilate-export-green-20260924.log`。

随后增加三通道块位置和正负半值舍入的文件级断言；此时全包 104 个 XCTest 用例通过、0 失败，日志 `/tmp/lutcalc-assimilate-export-full-20260924.log`。进一步补入服务与 sink 的 `-0.0` 域拒绝契约，先红测复现：sink 错误进入写入态，服务误由通用 1D 请求返回 SPI1D 错误；日志 `/tmp/lutcalc-assimilate-negative-zero-red-20260924.log`。位模式精确门控及最大码值/超界 `nextUp` 的 writer 测试加入后，定向 14 项通过、0 失败，日志 `/tmp/lutcalc-assimilate-negative-zero-green-20260924.log`。最终 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Native/Packages/LUTKit -c release` 全包共 107 个 XCTest 用例通过、0 失败；日志 `/tmp/lutcalc-assimilate-export-final-20260924.log`。覆盖文档会话 4,096 点文件解析读回、固定行数与头、同色域及位模式单位域限制、已有目标保护、码值溢出时的清理，以及 R/G/B 块布局。该测试仅证明包级路径，未代替 App 平台构建。

## 未完成

尚未在 macOS/iOS 系统保存或分享面板、真机 Files/File Provider 和 Assimilate 实际软件中验证本版文件。整数文件保留格式固有量化误差，不宣称与原始 Double 样本无损一致。其他 `.lut` 方言及 FULL-06 格式矩阵仍待验收；FULL-06 保持未勾选。

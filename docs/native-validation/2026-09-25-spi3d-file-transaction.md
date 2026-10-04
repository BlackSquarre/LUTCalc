# SPI3D 本地文件事务阶段验收

日期：2026-09-25。范围：补测已有 `FileCubeSink(format: .spi3d)` 的取消与默认覆盖边界；本段未修改生成器、格式编码器或颜色算法。

## 契约与结果

- 在独立临时目录先写入已有目标，再以显式 `allowOverwrite: true` 准备 SPI3D、写入首块并取消。目标文件逐字节保持原样，sink 为 `aborted`，目录中没有 `.lutcalc-` 临时文件。
- 已有目标上使用默认未授权写出，`prepare` 返回 `targetExists`，目标字节不变，也未创建临时文件。
- 新增契约位于 `Native/Packages/LUTKit/Tests/LUTJobsTests/SPI3DExportContractsTests.swift`。首次执行因测试在 XCTest 断言的 autoclosure 内读取 actor 状态而编译失败；修正测试写法后运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Native/Packages/LUTKit -c release --filter SPI3DExportContractsTests`，4 项通过、0 失败，其中新增 2 项。生产代码无需改动。

## 边界

这只验证 macOS 本地临时目录和明确触发的 SPI3D sink 状态。真实 Files/File Provider 权限、系统分享后的保存提交、最终哈希检查与替换之间的竞争、写入介质故障及 iPhone/iPad 上的取消仍未验证；H08、FLOW-02、QA-02 保持未完成。真机 SPI3D 生成和容器取回有[独立记录](2026-09-24-spi3d-device-export.md)，不能替代这些文件事务场景。

# SPI1D 生成与读回预算一致性阶段验收

日期：2026-09-24。范围：H04/FULL-06 已有 `.spi1d` Double 流式生成路径的资源边界；不代表完整格式、真机或发布验收。

## 问题与契约

原 `LUT1DGenerationRequest` 以 SPI1D 文本文件的 256 MiB 上限除以 `RGB64` 步长限制节点数，但本方 `SPI1DParser` 在解析节点时复用 CUBE 的 64 MiB 解码预算。因而请求可接受超过解析预算一个节点的尺寸，最终文件将无法由本方读回。`FileSPI1DSink.prepare` 直接调用时也会创建临时文件。

先添加两个契约：最大可读节点数 `CubeParser.maxDecodedBytes / MemoryLayout<RGB64>.stride` 可被请求接受，再多一个节点必须返回 `SPI1DFailure(.resourceLimit)`；直接调用 sink 的越界尺寸必须在创建临时文件前返回同类错误。两项测试在修改生产代码前均实际失败，分别表现为请求未抛错，以及 sink 创建临时文件。测试只检查边界判定，不分配最大尺寸样本数组。

## 实现与验证

请求和 sink 统一使用 64 MiB 解码预算；sink 同时检查 SPI1D 的最小 2 节点。没有修改采样公式、Double 计算、1024 点文档草稿导出尺寸或已有文件事务顺序。

实际执行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test -c release --package-path Native/Packages/LUTKit --filter SPI1DGenerationContractsTests`：10 项通过、0 失败。随后执行同一工具链的全包 `swift test -c release --package-path Native/Packages/LUTKit`：8 个 XCTest bundle 共 111 项通过、0 失败，日志 `/tmp/lutcalc-spi1d-budget-full-20260924.log`。首次定向回归曾在并行变更的 H12 测试编译时读到临时不一致的接口；该接口完成后重跑上述两项验证通过。没有把首次编译错误归因于 SPI1D。

当前文件 SHA-256：

```text
Native/Packages/LUTKit/Sources/LUTJobs/Generation.swift a28b96074245d3dfc1adf20a4ca26d678794d7b6d3cefdf9f638c9f9840e2770
Native/Packages/LUTKit/Sources/LUTJobs/FileSPI1DSink.swift f9975f1824062b1299596deb6cd33c855d4f8a2f290250104e441d99a2da68b7
Native/Packages/LUTKit/Tests/LUTJobsTests/SPI1DGenerationContractsTests.swift ead957c13c0182c7623d9704ea89ea842ed0469095abd72aede886c461aba6aa
```

## 剩余边界

此项为构造与文件准备阶段的预算契约，没有实际生成上限尺寸文件，也没有测量极限内存或设备耗时。SPI1D 真机生成、Files/File Provider 保存、目标软件导入与独立完整 1D 旧管线兼容仍待验收；H04/FULL-06 和发布门槛均不勾选。

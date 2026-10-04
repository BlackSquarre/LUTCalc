# `.spi1d` 生成阶段验收

日期：2026-09-24。范围：FULL-06 中 `.spi1d` 的纯 Swift Double 生成、暂存文件提交和功能草稿导出；不代表 FULL-06 或 H04 完成。

## 先失败后实现

先加入 `SPI1DGenerationContractsTests`，要求 1D 生成请求、独立通道取样和 SPI1D 文件提交接口存在。首次运行失败，编译器报告 `LUT1DGenerationRequest`、`OneDGenerationCoordinator` 和 `FileSPI1DSink` 尚不存在。首次文件读回还暴露结束括号缺失，解析器以 `rowCountMismatch` 拒绝；修正后通过。

## 实现范围

- `LUT1DGenerationRequest` 使用 `Double`，限制至少 2 个节点、统一标量输入域、资源上限，并拒绝输入输出色域不同的跨通道计划；跨色域变换不能无损表示为 1D LUT，因此返回 `lossyRepresentation`。
- `OneDGenerationCoordinator` 采用有界 TaskGroup、顺序单 writer、取消检查、验证和提交边界。每个节点分别以 `(x,0,0)`、`(0,x,0)`、`(0,0,x)` 求值并取对应输出通道。
- `FileSPI1DSink` 写入临时文件，追加 SPI1D 头、3 分量行和结束括号；验证节点数与字节数后提交，保留覆盖指纹与符号链接拒绝。
- 导出服务、文档会话和功能草稿新增 `.spi1d` 分支，固定生成 1024 点。SPI3D/CUBE 路径保持原逻辑。

## 实际验证

工具链：Xcode 27.0，Apple Swift 6.4，macOS 27 SDK。命令：

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test -c release --package-path Native/Packages/LUTKit --filter 'SPI1D(Generation|Service)ContractsTests'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test -c release --package-path Native/Packages/LUTKit
```

筛选契约在加入文件事务契约后共 9 项通过（生成与文件事务 8、文档服务 1）。完整 Swift Release XCTest 共 61 项通过、0 失败。D-Log2→同色域线性 17 点 SPI1D 逐通道独立公式参照的 `scaledError` 最大值不超过 `2e-12`；服务生成并读回 1024 点。跨色域、非标量域、超大尺寸、取消、默认拒绝覆盖和外部改写检测契约通过。文件事务的受控写块证据见[SPI1D 文件事务阶段验收](2026-09-24-spi1d-file-transaction.md)。

## 平台与发布边界

本段没有新版 SPI1D 真机导出或 Files/File Provider 往返证据。`xcrun devicectl list devices` 当前仍将实体 iPhone Air 列为 `unavailable`；iPhone Air 模拟器仅有安装/启动记录，未进行界面点选导出。代码、包级数值和 macOS Swift 测试通过，真机和发布分别保持未验收。

发布入口仍要求真实完整 `full-scope-acceptance.json` 与全部 H01–H14 证据；本段不创建或伪造该清单。SPI1D 目标软件导入、其他 FULL-06 格式、用户 LUT 持久化和完整 UI 仍未完成。

源码 SHA-256：

```text
Native/Packages/LUTKit/Sources/LUTJobs/Generation.swift 53a9120df2a5046305d0b855aa11b757bbe498f117d04092d59a410372e60af4
Native/Packages/LUTKit/Sources/LUTJobs/FileSPI1DSink.swift c5927c028d392c02eea3d987ad0b6d1f62ea6836e5b2fb8dcae797f4580f362a
Native/Packages/LUTKit/Sources/LUTSharedUI/EditorSession.swift 2a8453aa737c68ecff43f189fbf9bcb646bebf2cb19539fc9bb36eeda485341c
Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectExportSession.swift 56235446606a0dc10f84a21cead791e2cb18e88d4cd30028eeb190ecc8b70533
```

# H11 Fujifilm F-Log2 官方公式阶段验收

日期：2026-09-25。状态：**官方 F-Log2 标量、F-Gamut 身份和同色域最小曝光计划的本地数值验证通过；H11、FULL-01、完整迁移及发布验收仍未完成。** 真机剩余测试按用户要求暂缓，待其他工作就绪后集中进行。

## 来源与范围

- [Fujifilm《F-Log2 Data Sheet》Ver.1.1](https://dl.fujifilm-x.com/technical-data/F-Log2_DataSheet_E_Ver.1.1.pdf)，本地 `research/colour/2026-09-23/whitepapers/fuji-flog2-v1.1.pdf`，SHA-256 `0aadf0c504dc374c3e19ee82bb67576cce3d28f603938000e14d84db1f2129cc`。第 2-3 节定义传递函数及双切点，第 3 节定义 F-Gamut 原色。完整公式与 80/120 位十进制参照见[先行研究记录](2026-09-25-fuji-flog2-reference-research.md)。
- Swift 运行时只包含上述解析常数和原色，不打包富士 LUT、PDF、旧 `.labin` 或采样表。F-Gamut 的公布原色与本项目 `rec2020` 数值一致，但用独立稳定 ID 和来源登记。
- 当前接入的是**原厂 v1.1**。旧 `js/gamma.js:216` 为 0.9 线性标度及截断常数的旧实现；官方与旧兼容结果不能混称。旧兼容独立 ID、完整旧管线、F-Log2C、富士相机预设及跨色域计划未在本段完成。

## 契约先行与实现

先写 `FLog2ContractsTests` 的官方标量点、切点、非有限输入和同色域 Double 计划。首次 Release 定向编译因 `FLog2Transfer` 不存在失败，错误见 `/tmp/lutcalc-flog2-contract-red-20260925.log`。随后加入 `FLog2Transfer.swift`，在 `TransformPlan` 注册传递函数和 F-Gamut，在 `AlgorithmCatalog` 登记独立 ID、来源及研发预设，并更新目录计数契约。切点以数据表的 `<`/`>=` 分支执行，未强制连续或夹负值。`LUTReferenceCLI` 新增仅供研发的 `flog2-exposure` 预设入口。

独立 Python 读回器使用 80 位 `Decimal`，按输入 Double 的确切值算出每个唯一轴点，再逐行检查 CUBE 的尺寸、有限值、节点顺序及三个通道；阈值预先保持 `scaledError = abs(actual-reference)/max(1,abs(reference)) <= 2e-12`。该脚本已接入原生子集回归。

## 本段实际结果

| 检查 | 结果 |
| --- | --- |
| 首次失败契约 | 缺 `FLog2Transfer`，预期编译失败 |
| Release 定向 XCTest | 3 项通过；包括分段邻域、非有限输入和同色域曝光计划 |
| Release 全包 XCTest | 125 项通过、0 失败；目录新增条目的契约包含在内 |
| 注册表命令行契约 | 更新计数为 13 曲线、10 色域、13 研发预设后通过 |
| 33³ CUBE 独立全节点 | 35,937 节点，最大尺度化误差 `2.0677889068274172e-16`，RMS `5.0793702028671634e-17`，P99 `2.0677889068274172e-16` |
| 65³ CUBE 独立全节点 | 274,625 节点，最大尺度化误差 `2.0677889068274172e-16`，RMS `4.469139027650494e-17`，P99 `2.0677889068274172e-16` |

复跑命令：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test -c release --package-path Native/Packages/LUTKit --filter FLog2ContractsTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test -c release --package-path Native/Packages/LUTKit
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run -c release --package-path Native/Packages/LUTKit LUTCatalogChecks
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run -c release --package-path Native/Packages/LUTKit LUTReferenceCLI --size 33 --output /tmp/flog2-33.cube --preset flog2-exposure
python3 tools/native-validation/verify-flog2-cube.py /tmp/flog2-33.cube --size 33
```

本段 Swift 公式 SHA-256 `95a9b1de03b96286fd3038bdd9890aaf3e8f23f0a4ac8d9c64b8fdf58a6cfb84`；独立读回脚本 `db9b6c60d59c0c0592e95e025767aaad66f52fe12cff94e529b3874df888f6d5`。完整构建与发布门槛将在此段接线后另行复核，不以本地 XCTest 或 CUBE 数值结果代替。原厂舍入常数使编码切点出现约 `3.5458e-8` 的向下跳变；因此不能用全域严格单调或切点连续性作为错误的验收条件。

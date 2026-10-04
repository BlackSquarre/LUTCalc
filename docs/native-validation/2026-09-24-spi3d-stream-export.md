# SPI3D 流式导出阶段验收

日期：2026-09-24。范围：H04/H08 与 FULL-06 的 `.spi3d` 流式写出和功能草稿导出入口；不代表格式全覆盖或完整迁移。

## 修改与版本

- `Native/Packages/LUTKit/Sources/LUTFormats/SPI3D.swift`：提供文件头和显式坐标行写出函数，SHA-256 `e555e88e231a64efcece8f575bbd399cb9f9eff34720f672de1bb3fabcb4a2f6`。格式依据与旧实现版本见[先前格式验收](2026-09-24-spi3d-format.md)。
- `Native/Packages/LUTKit/Sources/LUTJobs/FileCubeSink.swift`：在现有单写入者、临时文件、提交和取消机制内增加 `.spi3d` 分支；各块按内核红轴最快节点编号写显式 RGB 整数坐标，SHA-256 `7d381da34b7904ed65271124a17b17b53f4afe47da192514dc4cd7fee9616095`。
- `Native/Packages/LUTKit/Sources/LUTSharedUI/EditorSession.swift`：导出服务按目标扩展名选择 CUBE 或 SPI3D，未知格式明确拒绝，SHA-256 `8c4f48a52577d766d7085fbe0dec102e5377cc4e3ed45437a66a063dacca8e15`。
- `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectExportSession.swift` 与 `ProjectDocumentView.swift`：文档会话接受输出格式并形成对应临时文件；功能草稿可选择 CUBE/SPI3D、生成及通过系统分享面板保存，SHA-256 分别为 `56235446606a0dc10f84a21cead791e2cb18e88d4cd30028eeb190ecc8b70533`、`41ac9ad343626cd5e0b8581535428147e00e03cc63831996388ca34ffd8f8c1c`。界面仍为功能草稿，用户将另行设计。
- `Native/Packages/LUTKit/Package.swift` 调整测试依赖，SHA-256 `fef20dfd3ba8120285f52c2197b6383a8c7e5fd956d55f34509d234f94ea737b`。两份新增契约的 SHA-256 分别为 `6c729c3b5070baacdb5313b362964f0dd3886049b26715b39bc4f8335988e291`、`e3263043ba33bfba7aaf489f6439a09e5dc75104fde57e4cde06bc694d2f6c0d`。

## 测试先行与数值结果

先写流式坐标、Double 节点和非单位域拒绝契约。`swift test --filter SPI3DExportContractsTests` 编译失败，错误为 `FileCubeSink` 不接受 `format` 参数，日志 `/tmp/lutcalc-spi3d-stream-red-20260924.log`。实现后同命令 2 项通过，日志 `/tmp/lutcalc-spi3d-stream-green-20260924.log`。

随后写导出服务和文档会话契约。`swift test --filter SPI3DServiceContractsTests` 先因缺少 `NativeExportError` 失败，补实现后两项通过；再增加文档会话生成与读回契约，先因 `start(document:format:)` 缺失而失败，最终运行 `swift test --filter 'SPI3D(Service|Export)ContractsTests'` 共 5 项通过、0 失败。失败日志 `/tmp/lutcalc-spi3d-service-red-20260924.log`、`/tmp/lutcalc-spi3d-session-red-20260924.log`；服务阶段通过日志 `/tmp/lutcalc-spi3d-service-green-20260924.log`。

3³ 非恒等 D-Log2/D-Gamut2→曝光 +1→线性 AP0 请求拆成 5 节点块，由 2 个 worker 生成。输出文件实测 30 行，显式坐标从 `0 0 0` 到 `2 2 2` 且按红轴最快前进；SPI3D 读回 27 个节点的 81 个 `Double.bitPattern` 与不经文本的 `CubeGenerator` 结果完全相等。文档会话的默认 17³ 实际生成 4,913 节点，能以 SPI3D 解析。扩展输入域在临时文件创建前拒绝；未知扩展名也不创建输出文件。

## 平台与剩余范围

本段的数值和文件事务是 Swift 包级实测；两端实际系统分享面板中的 SPI3D 文件保存、第三方软件导入、File Provider 和真机导出读回尚未实测。现有 CUBE 文件事务契约通过同一个 sink 的默认分支，但未把这次 SPI3D 格式视为完整平台事务验收。`.spi1d` 的流式生成功能及 FULL-06 其他格式仍未完成。

SPI3D 没有输入域和标题字段。非单位域（包含负零）明确拒绝；生成协调器传入的内部标题仅用于 CUBE，SPI3D 不将它伪装为文件元数据。生成路径和写入使用 `Double`，无厂商 LUT、旧 `.labin` 或采样表进入 App。

## 完整回归结果

在上述源码版本实际运行 `bash tools/native-validation/verify-native-release.sh`，完整日志 `/tmp/lutcalc-spi3d-stream-release-20260924.log`。Xcode 27.0 / Apple Swift 6.4：旧 Node 9 项、App 包审计 Python 3 项、Swift Release XCTest 52 项均通过，macOS、iOS Simulator、iOS generic 三个 Release 构建均为 `BUILD SUCCEEDED`，三个实际 App 包资源审计通过。该入口最终退出码为 2，仅因缺少全量发布验收清单 `docs/native-validation/full-scope-acceptance.json`；没有将子集测试通过标为发布就绪。实际 iPhone 上运行的是上一阶段用户导入草稿的 Debug 版本，**尚未安装或测试本次 SPI3D 导出版本**。

## 本次设备与模拟器复核边界

尝试使用此前已成功签名的团队 `DD4V6SJ9XL` 和 iPhone Air UDID `00008150-0012709121D2401C` 执行本版 Debug `xcodebuild ... -destination 'platform=iOS,id=00008150-0012709121D2401C' ... build`。实际退出码 70：Xcode 未找到匹配目标；随后的 `xcrun devicectl list devices` 显示该 iPhone 为 `unavailable`。构建日志 `/tmp/lutcalc-spi3d-device-build-20260924.log`，SHA-256 `34e7ed9078f73279100c9ee13970e76cfe60e80fd27ecb0f65077694d6f4ade1`。因此本版没有签名真机包、没有安装，也没有真机 SPI3D 导出结果。设备在此前阶段已解锁并成功运行旧版本；这里仅报告当前连接不可用，不推断签名或代码失败。

在 iPhone Air 模拟器 `E371A154-E717-4E80-864D-6BD16E0BCA52` 上，使用 `xcrun simctl boot`、`simctl install` 安装上述 Release Simulator App，`simctl launch` 返回进程 31575；`simctl io ... screenshot` 捕获的[启动截图](artifacts/2026-09-24-spi3d-iphone-simulator-start.png) SHA-256 为 `d21eb70090bfac5fe572a602c8a217f0ac647b639b5c32238c0ccbe52fedf399`，画面显示 LUTCalcIOS 原生文档浏览器和“创建文稿”。这仅证明本版模拟器安装、启动和文档首页显示。当前环境没有可调用的 XcodeBuildMCP 模拟器交互工具，也没有可打开的 Simulator.app 窗口，故**未点选 SPI3D、未从模拟器 UI 生成文件**；包级 17³ 生成读回不能冒称为模拟器 UI 结果。

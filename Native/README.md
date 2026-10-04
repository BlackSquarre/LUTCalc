# LUTCalc 原生版研发预览说明

当前版本是全 Swift 迁移中的**阶段性子集**，不是完整产品或发布版本。macOS 与 iOS/iPadOS SwiftUI 工程已创建；本机仅有 Command Line Tools，尚未实际构建或运行两端 `.app`。界面只保留参数、导出和数值取样的操作草稿，详细 UI 将由用户单独设计。

## 已实现的链路

- 共用 Swift Package 包含 Double 数值核、DJI D-Log2/D-Gamut2、Sony S-Log3 官方与旧兼容解析版本、ARRI LogC4/AWG4、Panasonic V-Log/V-Gamut、Apple Log/Rec.2020 与 Apple Log 2/Apple Wide Gamut、矩阵/CAT02/Bradford、标准与旧兼容 sRGB 标量、用户 3D LUT 三线性/四面体插值、基础 CUBE 解析与三种方言写出、分块导出、项目包和 CPU 数值取样。
- 草稿界面可编辑输入范围、曝光、输出模式与 17³/33³/65³ 尺寸；当前输出模式只有线性 ACES AP0 和 DJI D-Log2/D-Gamut2。完成生成后提供系统分享入口。该界面尚未通过 App 实机验证。
- 草稿界面可导入图像并按明确确认的项目输入解释选定像素，以 Double 显示源 RGB 与变换输出；尚未进行 ICC 匹配或屏幕图像显示。
- `LUTReferenceCLI` 可导出研发用 D-Log2/D-Gamut2 → 曝光 +1 → 线性 AP0 或标准 sRGB 的 CUBE。标准 sRGB 链路仅做数学曲线编码，不等于完整场景到显示输出变换。
- 研发 CLI 还可导出 S-Log3 双版本在 S-Gamut3.Cine 内曝光 +1，以及 Sony 官方版 S-Gamut3.Cine 或 S-Gamut3 → 线性 ACES AP0 的 CUBE；上述 33³/65³ 已独立逐节点核对。其他跨色域组合与相机预设尚未验收。
- 研发 CLI 可导出 ARRI LogC4/AWG4 → 线性 ACES AP0 的 CUBE；33³/65³ 已按官方矩阵逐节点核对。
- 研发 CLI 可导出 Panasonic V-Log/V-Gamut → 线性 ACES AP0 的 CUBE；预设明确选择 ACES CTL 使用的 Bradford，33³/65³ 已按独立解析参照逐节点核对。Panasonic 手册公布矩阵与 ACES 解析矩阵存在已记录的差异。
- 研发 CLI 可分别导出 ACES CTL 定义的 Apple Log/Rec.2020 与 Apple Log 2/Apple Wide Gamut → 线性 ACES AP0 CUBE；两者共用公开解析曲线，各自的 Bradford 矩阵和 33³/65³ 已独立核对。Apple 原厂白皮书与具体设备适用范围仍待核验。
- `.lutcalc` 本地项目包保存版本化 JSON 与用户资源副本，并核对 SHA-256；`FileDocument`/`DocumentGroup` 已接入双端功能草稿，并与目录存储完成磁盘往返验证。Finder/Files 打开、自动保存和文件授权行为尚未经过 App 实测。

## 开发者验证

在仓库根目录运行：

```bash
tools/native-validation/verify-native-subset.sh
```

这会运行当前子集的静态检查、旧夹具、Swift Release 构建与契约入口。要检查完整发布门槛，运行：

```bash
tools/native-validation/verify-native-release.sh
```

发布入口在缺少完整 Xcode、双端构建、真机记录或 H01–H14 全量证据时返回非零。**当前机器可完成 XCTest 与 macOS/iOS App 构建，但仓库缺少 `docs/native-validation/full-scope-acceptance.json` 时仍返回退出码 2。** 共享包编译通过不等于双端 App 或完整发布验收通过。

命令行导出示例，目标路径必须尚不存在：

```bash
swift run -c release --package-path Native/Packages/LUTKit LUTReferenceCLI --size 33 --output /tmp/lutcalc-example.cube --preset dji.dlog2-to-srgb-w3c.v1
python3 tools/native-validation/verify-srgb-cube.py /tmp/lutcalc-example.cube --size 33
```

## 尚未完成

完整旧功能迁移、所有曲线/色域/调节、其他导入导出格式、整图预览与显示色彩管理、完整项目 UI、Mac/iPhone/iPad 文件集成、性能预算、目标软件导入、真机与发布验收均未完成。厂商 LUT-only、OPPO 资料冲突、任意 3D 反求和完整 ACES 输出等项目按[迁移任务清单](../docs/native-swift-roadmap.md)保留为明确研究或实现阻塞，不能用内置采样表替代公式。

每个阶段的真实命令、误差、文件哈希和未覆盖范围记录在 [`docs/native-validation/`](../docs/native-validation/)；最新状态以[迁移任务清单](../docs/native-swift-roadmap.md)为准。

## 流程性能

快速入口 `Scripts/verify-native-fast.sh` 会复用 Swift 的增量构建缓存，并使用全部逻辑核心并行执行 XCTest 与 Node 契约测试。原生数值子集的独立夹具检查也会使用全部逻辑核心并行调度，输出顺序仍按清单稳定排列，失败时保留所有失败命令和退出码。Release 入口会同时启动 macOS、iOS Simulator、iOS device 三个 Xcode 构建，并与原生验证重叠执行。

可按机器资源覆盖并行度：`LUTCALC_CPU_COUNT` 设置默认逻辑核心数，`LUTCALC_SWIFT_JOBS` 控制 Swift 编译任务数，`LUTCALC_TEST_WORKERS` 控制 Swift 测试 worker，`LUTCALC_VALIDATION_WORKERS` 控制静态验证 worker，`LUTCALC_BATCH_WORKERS` 控制 CUBE/公式批次 worker。Release 构建使用 `Native/DerivedData` 增量目录，也可通过 `LUTCALC_DERIVED_DATA_PATH` 指定持久化缓存位置。

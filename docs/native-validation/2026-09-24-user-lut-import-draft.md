# 用户 LUT 只读导入与数值检查阶段验收

日期：2026-09-24。范围：H07/FULL-05 的部分用户主动导入能力，接入 `.cube`、`.spi1d`、`.spi3d` 的原生功能草稿；不代表完整 LUTAnalyst、用户资产持久化或双端文件验收完成。

## 修改与来源

- `Native/Packages/LUTKit/Package.swift`：共享界面模块显式依赖纯 Swift `LUTFormats`，SHA-256 `0918c9ac825bae1bbfa9d9da1374dcd5987df9abe04ae0c39916ffa8d6cb4001`。
- `Native/Packages/LUTKit/Sources/LUTSharedUI/UserLUTImportSession.swift`：用户选取的 URL 在后台任务内成对开启/结束 security scope，按扩展名调用现有三种 Swift 解析器；会话以请求 ID 隔离晚返回，支持关闭、清空、直接数值取样。SHA-256 `a9c2d4c599271362aa4cd610a8199ecfb2c788d0725b17a8e8b73763a3a5f838`。
- `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift`：功能草稿添加系统文件选择、格式/尺寸/输入域展示、RGB Double 输入与 1D 线性或 3D 指定插值取样；明确标为临时读取，不写入项目或内置算法。SHA-256 `2352f126c52a820d253c661a0b6498d84c934969cd48195186f10adfcdee11c7`。用户将单独设计最终 UI，此处不作为视觉定稿。
- `Native/Packages/LUTKit/Tests/LUTSharedUITests/UserLUTImportContractsTests.swift`：三种真实临时文件读取、数值结果、未知扩展名拒绝、乱序完成与关闭隔离。SHA-256 `2c2fea71cb03a1081fa2ab37298956af1cd405070d060f65fcec08789b07948f`。
- 格式定义与版本见[`.spi1d` 阶段记录](2026-09-24-spi1d-format.md)、[`.spi3d` 阶段记录](2026-09-24-spi3d-format.md)，CUBE 定义沿用 H04 已有记录；没有把测试 LUT 打包入 App。

## 测试过程

先添加契约并运行 `swift test --filter UserLUTImportContractsTests`，因尚无会话和导入模型而编译失败，日志 `/tmp/lutcalc-user-lut-import-red-20260924.log`。实现后同一命令 2 项通过；Release 命令 `swift test -c release --filter UserLUTImportContractsTests` 亦为 2 项通过，日志分别为 `/tmp/lutcalc-user-lut-import-green-20260924.log`、`/tmp/lutcalc-user-lut-import-release-20260924.log`。工具链 Xcode 27.0 / Apple Swift 6.4。

测试的 1D 输入 `(0.5, 0.25, 0.75)` 得到 `(0.5, 0.5, 2.25)`；3D 身份表在非对称输入逐通道误差不超过 `1e-15`。错误扩展名拒绝，旧请求即使晚于新请求完成也不能替换新结果。

## 未覆盖范围

包级测试证实文件路径读取和会话状态；系统 Files/File Provider 的实际授权、iPhone/iPadOS 真机选取、外部目标软件导入、持久化为项目资产及完整 LUTAnalyst 未验收。macOS 系统面板的单项 SPI1D 交互见下节。所导入 LUT 仅用于用户主动查看和直接取样，未用于内置颜色转换。

上述源码随后实际执行 `bash tools/native-validation/verify-native-release.sh`，日志 `/tmp/lutcalc-user-lut-import-full-20260924.log`：旧 Node 9 项、App 包审计 Python 3 项、Swift Release XCTest 47 项均通过；macOS、iOS Simulator、iOS generic 三个 Release 构建均显示 `BUILD SUCCEEDED`，三个实际 App 包资源审计通过。发布入口仍因缺少 `docs/native-validation/full-scope-acceptance.json` 而退出码 2，未认定发布就绪。

## macOS 实际系统文件面板

使用本次 Release 构建重新启动 `LUTCalcMac.app`，在系统文稿界面新建未命名项目，再从草稿中的“导入 CUBE / SPI1D / SPI3D”打开 macOS 系统文件选择面板。通过完整路径选取 `/tmp/lutcalc-user-import-ui-20260924.spi1d` 并点击“打开”，界面实际显示文件名、`spi1d，1D，2` 和输入域 `0…1`。输入非对称 RGB `(0.5, 0.25, 0.75)` 并点“取样”，界面无障碍文本实际显示输出 `(0.5, 0.5, 2.25)`，与独立手算的两个样本逐通道线性插值一致，误差为 0。这是 macOS 用户界面实际操作结果，不替代 iPhone/iPadOS Files 验收。

所选的 57 字节合成文件仅存于验证目录，见[macOS 导入复现文件](artifacts/2026-09-24-mac-user-import.spi1d)，SHA-256 `f481b45785e7750a65934af8f30d28e3ab2999b4a47d7000b81f1cd406af37ae`。它是用户主动导入路径的验收输入，不进入 App 包；三个 Release 包资源审计已确认无 `.spi1d` 文件。未命名测试项目未保存到用户目录。

## iPhone Air 真机入口

以 Xcode 27.0、当前开发团队 `DD4V6SJ9XL` 对 iPhone Air（iOS 27.2）实际执行以下命令，签名 Debug 构建 `BUILD SUCCEEDED`、安装退出码 0、启动报告 `Launched application`。构建日志 `/tmp/lutcalc-user-import-iphone-build-20260924.log`；本次未出现先前方向与启动屏警告。Debug App 可执行文件 SHA-256 `dd7d15672c951e701c17d83ac86f25f40f3bfa7f7616f8b31fc9132b96f98e29`，`Info.plist` 源文件 SHA-256 `0594747f63a1f27ae2e1ddcf0de9049f53953649e3a1ba15b23f1a06fe4bb885`。对该签名包额外执行资源审计也通过。

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'platform=iOS,id=00008150-0012709121D2401C' -derivedDataPath /tmp/lutcalc-device-derived -allowProvisioningUpdates CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=DD4V6SJ9XL build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl device install app --device 00008150-0012709121D2401C /tmp/lutcalc-device-derived/Build/Products/Debug-iphoneos/LUTCalcIOS.app
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl device process launch --device 00008150-0012709121D2401C org.lutcalc.native.dev.ios
python3 tools/native-validation/audit-native-bundles.py /tmp/lutcalc-device-derived/Build/Products/Debug-iphoneos/LUTCalcIOS.app
```

iPhone 镜像实际显示新建文稿中的“用户 LUT 数值检查”及“导入 CUBE / SPI1D / SPI3D”。点击后系统 Files 选择界面打开，能切换“最近项目”和“浏览 / 我的 iPhone”；选择器可见的是设备上已有文件，本次没有打开、复制或分析它们。由于未能把合成验收文件送入设备可选择的位置，故真机**尚未验证选中 LUT 后的解析、授权和数值取样**。一次 `devicectl device info files` 查询本 App `Documents` 时返回 CoreDevice 4016 设备状态断言错误；未据此推断 Files 文件事务正常或异常。此项仍保留在 H07/H08 平台待验收范围。

随后关闭镜像再尝试把上述 57 字节合成文件复制到**本 App** 的 `Documents/lutcalc-validation.spi1d`，`devicectl device copy to` 返回 CoreDevice 4000、网络隧道建立超时，退出码 1；没有复制成功，也没有读写设备上的其他文件。因此没有可受控的真机导入输入，本轮停止该项设备操作，继续其他有证据的工作；不能把 macOS 取样结果外推为 iPhone 取样通过。

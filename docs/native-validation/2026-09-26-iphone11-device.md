# iPhone 11 开发者模式与真机首轮验收

日期：2026-09-26。设备：Lingru's iPhone 11，型号 `iPhone12,1`，iOS `26.5`（系统构建 `23F77`）。UDID：`00008030-001015101ABA802E`。

## 已完成

- 设备已通过 USB 配对，状态为 `available (paired)`。
- 用户已在设备上打开开发者模式；`devicectl device info details` 报告 `Developer Mode Status: Enabled (1)`。
- 设备已解锁，开发者磁盘服务和应用安装、启动、截图、文件传输能力可用。
- 使用 Team ID `DD4V6SJ9XL` 和 `-allowProvisioningDeviceRegistration` 自动登记设备，Xcode 生成开发 provisioning profile。
- `LUTCalcIOS` Debug 真机签名构建通过。
- App 已安装到真机并成功启动，进程路径为：
  `/private/var/containers/Bundle/Application/A5EE83DF-D7D7-42F2-AA36-57E3376C4A22/LUTCalcIOS.app/LUTCalcIOS`。
- 结束进程后再次启动成功，证明安装后的基本启动生命周期可用。
- 首次启动截图：`/tmp/lutcalc-iphone11-launch.png`，SHA-256：`cda266593ccfeaddea9383e65cba7ed15e95062dad426795cd26773a5fa95477`。
- 重启后截图：`/tmp/lutcalc-iphone11-relaunch.png`，SHA-256：`72cd6a072cfff275230e0fef07e30cb34849e2ab462ab30648c720785d3df08a`。
- 签名后的主程序 SHA-256：`1da8007d900f3a6263bf5fcc4953bda4237f57e0e492935c2810d2ba18fed8b2`。

## 2026-09-27 真机 UI 与 CUBE 生成

- 仅使用 `xcodebuild` 的物理设备 destination `id=00008030-001015101ABA802E` 运行 `LUTCalcIOSUITests.testCreateDocumentAndGenerateCube`；未使用 iPhone 镜像，也未连接/操作 iPhone Air。
- 实际命令：

```text
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS \
  -configuration Debug \
  -destination 'id=00008030-001015101ABA802E' \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic \
  CODE_SIGNING_ALLOWED=YES \
  -only-testing:LUTCalcIOSUITests/LUTCalcIOSUITests/testCreateDocumentAndGenerateCube test
```

- 真机 UI 测试通过：启动 App、点击系统文稿界面的“创建文稿”、点击文稿导航栏的“生成 CUBE”，等待“LUT 已生成，可分享或保存。”，再确认“保存到文件…”入口出现。结果日志：`/tmp/lutcalc-iphone11-ui-test21.log`，SHA-256：`bf652488a6e45a7d5fc6a6a864539fda06380a88dc2d02bb0a27956223fbd91b`。
- 真机测试期间发现导出按钮曾被长表单滚动位置及文稿容器双层导航遮挡。iOS 文稿页现在复用 `DocumentGroup` 导航容器，另在导航栏提供固定可见的生成入口；macOS 仍使用独立 `NavigationStack`。测试按真实 iPhone 界面点按并等待导出状态，不通过测试专用计算旁路。
- 本次只验证 CUBE 生成成功状态与保存入口呈现，没有点击系统保存面板确认写入 Files，也没有验证 SPI3D、取消、项目保存重开、旋转、后台恢复或 iPad。它是阶段性真机 UI 证据，不代表 H01/H08/H09/H12/H13 全部完成。
- 当前界面实现源码 SHA-256：`Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift` `96e6c68b2940f1c828049ff5deec680835a6ec86eda83c7f6acd8f12a19969d9`；UI 测试源码 SHA-256：`Native/Tests/iOSUI/LUTCalcIOSUITests.swift` `ae0d6200e61ec4f5e475726f692c4108efe96c35ccc356c02d693e33338a6867`。

## 2026-09-27 导出类型契约修复与保存面板复验

- 修复 `GeneratedLUTExportDocument` 的导出类型契约：CUBE 和 SPI3D 现在分别使用 `com.lutcalc.cube`、`com.lutcalc.spi3d`，并在 macOS/iOS `Info.plist` 中声明扩展名和 `public.data` 继承关系；`contentType` 与 `writableContentTypes` 保持一致。此前系统将 `.cube` 动态识别为厂商类型并给出不匹配警告，已不再出现。
- 新增 2 项 Swift 契约测试，覆盖 CUBE/SPI3D 类型声明；实际执行 `swift test --package-path Native/Packages/LUTKit -c release`，全部通过。
- 重新生成 `Native/LUTCalc.xcodeproj` 后，仅使用物理 iPhone 11 重新执行同一 UI 测试。实际日志：`/tmp/lutcalc-iphone11-ui-save-panel4.log`，SHA-256：`db931dfcb9e215c9986bbbc8bd26db00ea18b6fd13d9012e77e9dcd28588de1b`；`TEST SUCCEEDED`，1 项、0 失败。测试打开系统保存面板并点击“取消”返回 App；日志无此前 `com.dji.ronin.lut` 或未声明 `com.lutcalc.spi3d` 警告。
- 本次仍未把“在 Files 中选择目录并实际写入”误记为已完成；保存面板打开/取消已证实，写入、SPI3D、取消生成、项目重开、后台恢复、旋转和 iPad 仍待单独验收。

## 2026-09-27 SPI3D 真机导出与取消边界

- 新增并通过物理 iPhone 11 的 SPI3D UI 路径：创建文稿、在真实导出格式 Picker 选择 SPI3D、生成成功、打开系统“保存到文件”面板并点击“取消”。实际日志：`/tmp/lutcalc-iphone11-spi3d4.log`，SHA-256：`f5184188001fca73361fb94b4e53bb7d9b3f95e5f92bd584d5c7601ba8867a9a`，1 项、0 失败。
- 为项目尺寸和导出格式补充稳定 accessibility 标识；导航栏在生成进行时显示固定“取消生成”入口。取消逻辑本身已有 Swift 生命周期契约测试。
- 取消生成真机 UI 证据暂未取得：在 iPhone 11 上 17³/65³ 默认任务都在 UI 自动化能观察到取消按钮前完成，测试日志分别为 `/tmp/lutcalc-iphone11-cancel.log`、`cancel2` 至 `cancel6`；这说明当前任务过快，不能证明用户按取消时的真实交互。未放宽算法或测试阈值，也未把失败伪装成通过。

## 2026-09-27 取消生成真机交互

- 为 Debug UI 测试增加显式启动参数 `-LUTCalcTestSlowExport`，只在测试启动的 Debug 进程中增加可取消等待；Release 构建和正常用户启动不包含该分支，不改变生成算法、网格、插值或精度门槛。
- 物理 iPhone 11 真机测试 `testCancelLUTGenerationOnDevice` 通过：选择 65³、点击生成、点击导航栏“取消生成”、确认“生成已取消。”且未出现成功状态。日志：`/tmp/lutcalc-iphone11-cancel9.log`，SHA-256：`4772d3a9e35f9cb7821b2b71961fa9bb04043022368348c9418e0c3aad0c0cf1`，1 项、0 失败。
- Swift Release 回归继续通过，日志 `/tmp/lutcalc-swift-release-after-cancel9.log`，SHA-256：`cd2fb656f9d262a9cc5ae756cbabcc3d7357e5764e7a2a7bff5d2a46d3bdd0e1`。

## 2026-09-27 前后台恢复与旋转

- 物理 iPhone 11 真机 UI 测试通过 `testDocumentViewSurvivesBackgroundAndForegroundOnDevice`：创建文稿后按 Home 进入后台，等待，再激活 App；导航栏生成按钮重新出现且可操作。
- 同一轮通过 `testDocumentViewSurvivesRotationOnDevice`：创建文稿后切换到横屏，再恢复竖屏；导航栏生成按钮持续存在且可操作。日志：`/tmp/lutcalc-iphone11-lifecycle2.log`，SHA-256：`0d8c4c8803f803f685f1ccea94f7e9a23f0a2f1eaef7dd20880580e68ef389b8`，2 项、0 失败。
- 这两项证明的是当前文稿视图生命周期和设备方向切换；不等同项目包已经写入 Files，也不覆盖进程被系统终止后的文稿重开。

## 2026-09-27 文稿关闭与系统存储边界

- 物理 iPhone 11 真机测试 `testCloseDocumentShowsSystemSaveBoundaryOnDevice` 通过：创建文稿后点击系统文稿导航栏“返回”，回到 DocumentGroup 的“最近项目”浏览器；当前未保存的新文稿不会出现在最近项目中。日志：`/tmp/lutcalc-iphone11-document-close.log`，SHA-256：`c34791a8d0f7374ef26473707add04757a261a062b3bc5d7dba693e6c0080530`，1 项、0 失败。
- 真机文稿菜单只提供“重新命名”，没有暴露项目包保存动作；因此这台设备上的自动化证据明确到达系统存储边界，但尚未证明选择 Files 目录、写入 `.lutcalc` 包并从最近项目重开。该项继续保持未完成。

## 2026-09-27 应用容器传输尝试

- 使用 `xcrun devicectl device copy to` 将 Swift 契约生成的 `docs/native-validation/artifacts/2026-09-24-mac-roundtrip.lutcalc` 复制到 iPhone 11 的 `appDataContainer`（bundle `org.lutcalc.native.dev.ios`）下的 `Documents/2026-09-24-mac-roundtrip.lutcalc`，命令返回设备目录可读写；随后用 `copy from` 成功取回 Documents 容器。
- 启动 App 后 DocumentGroup 最近项目浏览器没有显示该包；UI 测试 `/tmp/lutcalc-iphone11-project-reopen.log` 退出码 65，SHA-256：`2eb1d64948f53f81eca7a5192d3ee28a39a7894ea15e8d20553fa6a2ceee8d00`。因此应用容器传输不等同 Files/File Provider 文稿登记，未将其计入项目重开通过证据。
- 边界尝试后的回归：Swift Release `/tmp/lutcalc-swift-release-after-storage-boundary.log`（SHA-256 `347408b361481fc0821e86c58488ec3b9600ebd8d0a1a2b604d01bd48102297c`）和 iOS generic Debug 构建 `/tmp/lutcalc-ios-after-storage-boundary.log`（SHA-256 `7df184524a7e87b21d15c31547fe9bac126c49cec1d14e0850fbca2cd62fc35f`）均退出码 0；Node 回归 `/tmp/lutcalc-node-after-storage-boundary.log`（SHA-256 `ee8bdb036739322c37002ca4d7d87024401a77e531d7975cbf7e1453e765c216`）11 项通过。

## 2026-09-27 iOS 文稿方向与发布资源审计

- 修复 iOS `Info.plist` 与 XcodeGen 配置：声明 iPhone Portrait/LandscapeLeft/LandscapeRight、iPad 四方向及系统 `UILaunchScreen`。此前 `verify-native-document-types.py` 因方向声明不完整退出 1。
- 实际执行 `python3 tools/native-validation/verify-native-document-types.py`：通过；iOS generic Debug 构建日志 `/tmp/lutcalc-ios-plist-fix.log`，SHA-256：`84c2c112d8a0e182e74bc535c5166f872304dcdd62687143fd3988b250023551`，退出码 0。
- 对当前 macOS/iOS Debug App 包执行 `audit-native-bundles.py`：2 个 App 包资源审计通过，无所列 LUT/脚本文件或 WebKit/JavaScriptCore 直接链接。
- plist 修复后的物理 iPhone 11 旋转复验通过：日志 `/tmp/lutcalc-iphone11-rotation-plist-fix.log`，SHA-256：`63158f2e1ecbf0f4024c98ffa3d8ad5c53e1ba7caf8026b4eb53cb6aba8a5230`，1 项、0 失败。

## 2026-09-27 iPad 目标构建检查

- XcodeBuildMCP 和 `xcrun simctl list devices available` 当前没有可用模拟器设备；尝试创建 iPad 设备时 CoreSimulator 返回 `NSPOSIXErrorDomain code=22`，设备停留在 creation state，无法进行 iPad UI 运行验证。
- 仍完成了 iPad 目标的编译检查：`xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`，退出码 0；日志 `/tmp/lutcalc-ipad-simulator-generic.log`，SHA-256：`06ee1f69783584e03ed1d7eee1668eb503a8f8e08248fb0e3403d7bbb203eb88`。
- 该结果证明 iPad 架构可编译，不证明 iPad 真机/模拟器 UI、多窗口或旋转；缺少设备是外部工具链阻塞，未伪造通过。
- 已重启 CoreSimulator 服务并再次尝试创建 iPad Pro 模拟器，仍返回同一 `NSPOSIXErrorDomain code=22` creation state 错误；磁盘可用空间约 33 GiB，未发现可由工程代码修复的原因。

## 本轮回归验证

- 实际执行 `node tools/native-validation/inspect-legacy-risks.js`：六类旧实现风险仍可复现，作为迁移风险证据，不要求新实现复制这些错误。
- 实际执行 `node tools/native-validation/verify-contract-fixtures.js`：14 项插值、2 项矩阵夹具及冻结哈希通过；该夹具仍不等同 Swift 实现数值验收。
- 实际执行 `node --test tests/*.test.js`：11 项通过，0 失败。
- 实际执行 `swift test --package-path Native/Packages/LUTKit -c release`：全包测试通过；既有 CUBE 其他资产五探针最大绝对误差 `0.0`。未将其解释为全功能精度证明。
- 实际执行 `xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`：`BUILD SUCCEEDED`。
- 以上分别记录源码检查、夹具检查、测试、macOS 构建及单台 iPhone 11 UI 验证；没有执行全量发布入口，也没有把当前结果标成完整迁移或发行就绪。

## 实际命令

```text
xcrun devicectl device info details --device 00008030-001015101ABA802E
xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS \
  -configuration Debug \
  -destination 'id=00008030-001015101ABA802E' \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic \
  CODE_SIGNING_ALLOWED=YES build
xcrun devicectl device install app --device 00008030-001015101ABA802E <LUTCalcIOS.app>
xcrun devicectl device process launch --device 00008030-001015101ABA802E org.lutcalc.native.dev.ios
xcrun devicectl device capture screenshot --device 00008030-001015101ABA802E --destination <screenshot.png>
```

构建日志：`/tmp/lutcalc-iphone11-signed-build5.log`，SHA-256：`a14255ceb96a31a4f5a686c8e194fd5297ec097c107daa4632f7fe0572836238`。

## 尚未完成及原因

- 2026-09-27 已通过 Xcode UI Testing 真机验证创建项目、CUBE 生成状态及保存入口呈现；SPI3D 导出、取消、Files 实际写入和项目重开仍未验证。
- 后续真机验证继续只使用 `devicectl` 与面向 iPhone 11 UDID 的 `xcodebuild`。不使用 iPhone 镜像，不连接或操作 iPhone Air。
- 旋转接口在该设备上返回 `portrait`，未取得 landscape 真机交互证据。
- iPad、多窗口、macOS Finder、HDR/EDR 屏幕、第三方软件导入和完整 ICC 显示色彩管理不能由这台 iPhone 11 单独完成。
- 因此本记录不勾选 H01/H08/H09/H12/H13 的完整真机交互项，也不创建 `full-scope-acceptance.json`。

## 2026-09-27 直接开发者工具真机复验

- 本轮只使用实体 iPhone 11（UDID `00008030-001015101ABA802E`）和 `xcodebuild`/`devicectl`；未使用 iPhone Air、iPhone 镜像或模拟器。
- 使用 Team ID `DD4V6SJ9XL`、Automatic signing 和设备开发配置文件构建，实际命令为：

  ```text
  xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS \
    -configuration Debug -destination 'id=00008030-001015101ABA802E' \
    -derivedDataPath /tmp/LUTCalcDeviceSignedDD \
    DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic \
    CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates build
  ```

- 真机 arm64 构建通过，日志 `/tmp/lutcalc-iphone11-device-signed-build.log`，SHA-256：`8d1a9575f68f444b931a55128d8c551b003e25461e419702a1bbf3c5f2e46da5`。
- 通过 `xcrun devicectl device install app` 安装成功并通过 `device process launch --console` 直接启动；安装日志 SHA-256：`39a204679ebc048b4836347df9f040bb910ec2bb9f04020ac0eef089a436c906`，启动日志 SHA-256：`0ad5e8307d90f22a50f28f6b9f54a62e5f6022ad77d6568a49010cd8157aa8cc`。
- 在同一实体设备上运行 6 项 Xcode UI 测试，实际命令为：

  ```text
  xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS \
    -configuration Debug -destination 'id=00008030-001015101ABA802E' \
    -derivedDataPath /tmp/LUTCalcDeviceUITestDD \
    DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic \
    CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates test \
    -only-testing:LUTCalcIOSUITests
  ```

- 结果为 `TEST SUCCEEDED`，6 项、0 失败、耗时 126.565 秒。覆盖创建文稿并生成 CUBE、生成 SPI3D、取消生成、关闭文稿边界、前后台恢复和横竖屏切换。完整日志 `/tmp/lutcalc-iphone11-device-uitest.log`，SHA-256：`c4090a2b7692ca515a2a671ac48199a86e97894dbd1ddabd851d3f6bb680cb0b`。
- 这些结果只扩大了 iPhone 11 的直接真机证据；Files 实际写入、项目包重开、iPad UI、多窗口、Finder/File Provider、完整 H01-H14/FULL-01 至 FULL-08 和发布签名仍未完成，因此不创建或填写全量验收清单。

## 2026-09-27 Files 保存写入边界复验

- 在实体 iPhone 11 上通过真实系统保存面板完成了：生成 CUBE、打开保存面板、填写 `DOCPicker.filenameTextField`、点击系统“保存”。系统随后弹出“允许 LUTCalcIOS 使用无线数据？”提示；自动化选择“不允许”后回到文件浏览器。
- 保存面板的 iCloud Drive 根目录能够打开并显示文件列表，但按本次唯一文件名搜索未找到对应条目。测试日志 `/tmp/lutcalc-iphone11-files-save2.log`，结果为失败（`Files 中未找到刚保存的 LUT`）。
- 该结果不能证明应用写入成功，也不能证明写入失败的唯一原因是网络权限；当前环境的系统网络提示和 iCloud 状态使 Files 回查无法形成可接受的正证据。临时失败 UI 测试已从工程移除，未把它计入通过项。
- 因此 Files 实际写入、项目包重开和 File Provider 登记继续保持未完成；此前“打开/取消保存面板”的通过证据仍有效。

## 2026-09-27 直接开发者工具 UI 回归复验（最新）

- 严格只使用实体 iPhone 11（UDID `00008030-001015101ABA802E`）；未连接或操作 iPhone Air，未使用 iPhone 镜像或模拟器。
- 使用独立派生数据目录和当前有效开发团队重新签名测试 Runner，实际命令：

  ```text
  xcodebuild -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS \
    -configuration Debug -destination 'id=00008030-001015101ABA802E' \
    -derivedDataPath /tmp/LUTCalcDeviceUITestDD2 \
    DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic \
    CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration test -only-testing:LUTCalcIOSUITests
  ```

- `TEST SUCCEEDED`：6 项、0 失败、耗时约 128 秒。覆盖 CUBE、SPI3D、取消生成、关闭文稿、前后台恢复和横竖屏切换。日志：`/tmp/lutcalc-iphone11-direct-uitest-final.log`，SHA-256：`acec02b13cb8de488df52b44c78ad98719b09a6ced50456638ae0e37d141bde7`；结果包：`/tmp/LUTCalcDeviceUITestDD2/Logs/Test/Test-LUTCalcIOS-2026.09.27_02-08-40-+0800.xcresult`。
- 该结果扩大了实体 iPhone 11 的直接 UI 证据，但仍不证明 Files 实际写入、项目包重开、File Provider 登记、iPad UI、多窗口、Finder 往返或完整发布验收；这些项目保持未完成。

## 2026-09-27 “我的 iPhone”本地 Files 路径尝试

- 仅在实体 iPhone 11 上临时运行一次 UI 验收：生成 CUBE、打开保存面板、填写文件名并切换到 Files 的浏览界面，尝试定位“我的 iPhone”。
- 系统保存面板实际返回的是无可点击的静态位置列表，UI 自动化无法得到“我的 iPhone”按钮；测试在保存提交前失败，未把它记为 Files 写入通过。临时测试代码已恢复删除。
- 实际日志：`/tmp/lutcalc-iphone11-files-local-temporary.log`，SHA-256：`03c9574cd9abad4a72ffa6b007d03ef9de0ae8481396bd44cc1bc5fd07773a5f`。该结果说明当前设备/系统的 Files 位置登记仍不能形成可回查证据；Files 写入、项目重开和 File Provider 继续未完成。

# H13 文档图像数值取样阶段验收

日期：2026-09-24。状态：图像导入到单像素 Double 取样的共享代码和功能草稿通过命令行契约；屏幕图像预览、ICC 匹配及双端运行未完成。

## 契约先行与实现

先增加 `LUTDocumentSampleChecks`，要求图像 A/B 乱序返回时只接收 B、关闭窗口拒绝晚返回、未经明确源解释确认不得求值、越界坐标拒绝、项目修订改变后重新用当前设置取样、含用户 LUT 的项目不得静默省略该资源。首次运行因 `PreviewImageLoading`/`ProjectSampleSession` 尚不存在而编译失败；随后实现并接入共享草稿页。

`NativePreviewImageLoader` 在非主线程使用 ImageIO 原始样本解码；系统文件 URL 的安全作用域在读取期间成对管理，父任务取消会转发给解码任务。`ProjectSampleSession` 用请求身份拒绝晚返回，并只对选定的一个像素创建 `PreviewRequest`，用 CPU Double 参考路径计算与原始码值、alpha 对应的计划输入和输出。导入新图像会清除前次图像与取样；项目修订变化时，界面清除取样并要求再次确认按当前项目输入解释。草稿页展示解码位深、色彩空间与 ICC 资料存在情况，但不把这些信息当作已经核对的源文件 ICC，也不执行隐式 ICC 转换。

本阶段只给出**数值取样**。结果是项目输出数值域中的 RGB，不作为屏幕色彩显示，尤其不能把线性 AP0 或 Log 输出当作 sRGB 图像显示。用户正式 UI 将另行设计。

## 修改文件与版本

| 文件 | 内容 | SHA-256 |
| --- | --- | --- |
| `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectSampleSession.swift` | 有身份的图像加载、显式源确认和单像素取样 | `52adf008e748009324fc59eba3c78e5b6b56888212225e83134a1116c5abd3b2` |
| `Native/Packages/LUTKit/Sources/LUTSharedUI/ProjectDocumentView.swift` | 文件导入、源解释确认、坐标及数值结果草稿 | `2100e0e76d19dca13bc1119658fe3b45879b3034547c9447764d1d66728ba324` |
| `Native/Packages/LUTKit/Sources/LUTDocumentSampleChecks/main.swift` | 强制乱序、关闭、源确认、RGB 精度与真实加载契约 | `2f0633bf010de0e34b7f67fc838179b39f7af17c85fbe7e2e7fc27530f7421ee` |
| `Native/Packages/LUTKit/Package.swift` | 注册取样可执行契约 | `8bcb563ed305c19ee1c93ddbf28dd55a004ec433aa993d12cbe8986ac297b8f4` |
| `tools/native-validation/verify-native-subset.sh` | 纳入日常验证入口 | `e883bdce06eca064ad4c987dd983c3ca1a1418c4b35a756a72ece7645c0c92f0` |
| `Native/README.md` | 更新草稿能力与剩余范围说明 | `365928c37e4d887ab0d6c3e292736d15677d045c29d277cbe48df557cf9e27c7` |

研发图像夹具由 `tools/native-validation/generate-preview-fixtures.py` 生成，源码 SHA-256 为 `848a943d1177c41c95e4f462f5bb51bd8dad60808cc691b4419632f67c16d923`；夹具未进入 App。

## 实际命令与误差

- 工具链：Apple Swift 6.2.1，arm64 macOS Command Line Tools。
- `python3 tools/native-validation/generate-preview-fixtures.py /tmp/lutcalc-h13-sample-fixtures-20260924`：退出码 0。
- `swift run -c release --package-path Native/Packages/LUTKit LUTDocumentSampleChecks /tmp/lutcalc-h13-sample-fixtures-20260924`：先因缺少会话接口而编译失败；实现后退出码 0。对独立生成的 RGB8 第二像素 `(254,253,252)`，逐通道源值精确等于码值除以 255；线性曝光 +1/+2 档相对独立代数参照的最大绝对误差为 `1.3322676295501878e-15`，门槛 `2e-12`。没有修改旧冻结预期、导出位宽、网格或门槛。
- `tools/native-validation/verify-native-subset.sh > /tmp/lutcalc-h13-document-sampling-final-20260924.log 2>&1`：退出码 0；静态边界覆盖 49 个 Swift 源文件，旧 Node 测试 9/9，通过 Release 包与所有当前原生契约，包括 H09 导出会话。macOS App 入口仅做源码类型检查。
- `tools/native-validation/verify-native-release.sh > /tmp/lutcalc-native-release-20260924.log 2>&1`：退出码 2；先跑完原生子集，再停在 `xcodebuild` 门槛。发布检查没有通过。
- `xcrun --sdk iphonesimulator --show-sdk-path`、`xcodebuild -version` 均退出码 1；缺完整 Xcode/iOS SDK，无法验证双端 `.app`、系统文件导入授权、模拟器、真机或显示色彩。

## 未覆盖范围

目前只有单像素数值取样；整图显示、ICC 源资料与 ImageIO 解码色彩空间的精确对应、工作与屏幕空间转换、Core Image 交互路径、HDR/EDR、其他像素布局和真实文件提供者仍未验收。异步 ImageIO 解码任务取消是协作式，晚返回由身份门控拒绝；实际内存峰值与后台切换需设备测量。H13、FLOW-05、UI-03 和发布检查均不能勾选。

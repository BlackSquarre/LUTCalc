# 项目本地来源身份与自动重发现非 UI 阶段验收

日期：2026-10-03

## 范围

本轮处理 H08/H12/FULL-08 的本地来源定位子集。项目包仍保存自包含资源字节；新增的 `ProjectAssetSourceIdentity` 只保存项目内资产路径、原始文件名和 SHA-256，用于在调用方已经授权的本地目录中重新定位用户主动导入的来源文件。实现不保存安全书签、iCloud token 或 File Provider token。

`ProjectAssetDiscovery.rediscover` 递归枚举已授权目录中的 regular file，跳过符号链接，按 SHA-256 匹配；相同字节候选仅使用原始文件名消歧，无法唯一确定时返回 `.ambiguous`，缺失、非法根目录、重复资产路径和非法身份均显式失败。

## 契约与实现

先添加 `ProjectAssetDiscoveryContractsTests`，红灯阶段因 `ProjectAssetSourceIdentity` 和 `ProjectAssetDiscovery` 尚不存在而失败，日志保存在 artifact 目录。实现后契约覆盖：

- 文件改名后按 SHA-256 重发现；
- 相同字节文件按原始文件名消歧；
- 相同哈希且无法消歧返回 `.ambiguous`；
- 缺失来源和非目录根目录显式失败；
- 符号链接根目录、符号链接候选拒绝；
- 重复 `assetPath` 和非法身份拒绝。

## 实际验证

工具链：Xcode 27、Swift 6（swift-driver 1.168.6）、macOS 27 SDK、Apple Silicon arm64。完整命令与结果文件见 [artifact 目录](artifacts/2026-10-03-project-asset-discovery/)。

```text
swift test --package-path Native/Packages/LUTKit --filter ProjectAssetDiscoveryContractsTests
swift test -c release --package-path Native/Packages/LUTKit --filter ProjectAssetDiscoveryContractsTests
swift test -c release --package-path Native/Packages/LUTKit
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalcAssetDiscoveryMacOct3DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalcAssetDiscoveryIOSOct3DD CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalcAssetDiscoverySimOct3DD CODE_SIGNING_ALLOWED=NO build
python3 tools/native-validation/audit-native-sources.py
python3 tools/native-validation/audit-native-bundles.py /tmp/LUTCalcAssetDiscoveryMacOct3DD/Build/Products/Release/LUTCalcMac.app /tmp/LUTCalcAssetDiscoveryIOSOct3DD/Build/Products/Release-iphoneos/LUTCalcIOS.app /tmp/LUTCalcAssetDiscoverySimOct3DD/Build/Products/Release-iphonesimulator/LUTCalcIOS.app
```

结果：

- Debug 定向 6 项、Release 定向 6 项，均为 0 失败；
- Release 全量 8 个测试包共执行 597 项，0 失败，LUTFormats 的既有 `.labin` 与 NCP 外部夹具共 2 项按既有契约跳过；
- macOS、iOS generic、iOS Simulator generic Release 构建命令退出码均为 0，分别生成 `/tmp/LUTCalcAssetDiscoveryMacOct3DD/Build/Products/Release/LUTCalcMac.app`、`/tmp/LUTCalcAssetDiscoveryIOSOct3DD/Build/Products/Release-iphoneos/LUTCalcIOS.app` 和 `/tmp/LUTCalcAssetDiscoverySimOct3DD/Build/Products/Release-iphonesimulator/LUTCalcIOS.app`；
- 源码审计通过：146 个 Swift 源文件，无所列脚本、C/C++ 源、内置 LUT 或 WebKit/JavaScriptCore 符号；
- 三个 App 包审计通过，无所列 LUT/脚本文件且未直接链接 WebKit/JavaScriptCore；
- 构建期间 xcodebuild 记录了 CoreSimulator 服务无法初始化的环境警告，但 generic simulator 构建仍完成并生成 App，不能把该日志当作 iPad 交互验收证据。

日志 SHA-256：

```text
契约红灯       57e353cba55864e54369b31594cc865194ce75d1b1efd0a938029782bcebd87b
Debug 定向      a002d857e41e4c8e90794aaeda2408052300e83cbd2b2a351bdcc034d967df8e
Release 定向    6e9c4bd2180f84b86ac718e67bd4bb05a82b848f1bc03800b3db076c3119bb2a
Release 全量    7fd6f01b37634a2672fa02074a81d73ec717cf28bd5926c4a36b6ee77c05a403
macOS 构建      911d8352df80ae33251ab6cc964e3a6a09eb205d9bea38ce2908f3491ac174d8
iOS 构建        1e7d9258778cb69e6f03377dca159988fd8d55bde9518e8811ce35a630683484
模拟器构建      6d3812c6cd021c553fb7ecaa8cd1ffe304aeb4ded611a6ab9237b5888439e197
源码审计        d3be41b866152b5840b67fbe667a6371e677fa390a20ee58f96d4f1c07fe63e2
App 包审计      5cf8f49359d02d2b03d3b23d7fcc0f25b68815ca27754ee29b15de8522a24d2f
```

## 未覆盖范围

本轮只证明调用方已授权的本地目录中的确定性来源重发现，不证明安全书签生成或失效恢复、真实 iCloud/File Provider 授权撤销、跨进程 provider 行为、目标替换竞争、磁盘故障、后台自动恢复或实体 iPhone 11 行为。项目包自包含资源语义和本地事务回收仍按已有记录执行。Finder、Files、iPad 多窗口、旋转、无障碍和其他 UI 验收按当前要求暂缓。

完整 ICC、HDR/EDR/OOTF、LUTAnalyst、全部格式及目标调色软件互操作、性能预算、签名发布和 `docs/native-validation/full-scope-acceptance.json` 仍未完成；Goal 保持 active。


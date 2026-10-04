# 2026-10-03 安全书签 stale 续期 API 非 UI 验收

## 范围

本阶段补齐本地 Foundation bookmark 生命周期中的一个缺口：已有 `ProjectAssetSecurityBookmark.resolve()` 能报告 `isStale`，但没有提供解析后重新生成书签的 API。新增 `renewedIfStale()`：fresh bookmark 保留原始字节，系统报告 stale 时从解析后的 regular file URL 重新生成书签；非法数据、目录和符号链接继续 fail closed。

本阶段只覆盖本地 Foundation bookmark 的 API 契约和编译验证，没有伪造真实 iCloud/File Provider stale、撤权、跨进程 provider、后台恢复或系统 Files 行为证据。

## 契约与实现

- `ProjectAssetBookmarkContractsTests` 先行扩展：fresh bookmark 的续期结果必须保持原始 bookmark 相等并可解析到同一文件；非法 bookmark 的续期必须返回 `.invalidBookmark`。
- `ProjectAssetSecurityBookmark.renewedIfStale()` 调用既有严格 `resolve()`，fresh 时直接返回自身，stale 时重新调用 `bookmarkData`。不会把 URL 解析成功解释成授权已持续有效。
- 代码继续使用 Swift、Foundation 和 Double；没有新增 LUT、采样表、WebView、JavaScriptCore 或 C/C++ 计算内核。

## 实际命令与结果

工具链：Xcode 27.0、Apple Swift 6.4、macOS arm64。

```sh
swift test --package-path Native/Packages/LUTKit --filter ProjectAssetBookmarkContractsTests
swift test -c release --package-path Native/Packages/LUTKit --filter ProjectAssetBookmarkContractsTests
swift test -c release --package-path Native/Packages/LUTKit
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/LUTCalc-bookmark-renewal-mac-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalc-bookmark-renewal-ios-20261003 CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LUTCalc-bookmark-renewal-sim-20261003 CODE_SIGNING_ALLOWED=NO build
python3 tools/native-validation/audit-native-sources.py
python3 tools/native-validation/audit-native-bundles.py /tmp/LUTCalc-bookmark-renewal-mac-20261003/Build/Products/Release/LUTCalcMac.app /tmp/LUTCalc-bookmark-renewal-sim-20261003/Build/Products/Release-iphonesimulator/LUTCalcIOS.app /tmp/LUTCalc-bookmark-renewal-ios-20261003/Build/Products/Release-iphoneos/LUTCalcIOS.app
```

- Debug 定向执行 3 项，0 失败。
- Release 定向执行 3 项，0 失败。
- 当前源码 Release 全量执行 602 项，0 失败；LUTFormats 的旧 `.labin` 与 NCP 外部夹具各 1 项按既有设计跳过。
- macOS、iOS generic、iOS Simulator 未签名 Release 构建均退出 0 并生成实际 App 包。构建日志包含当前主机 CoreSimulator 初始化内存警告；这不改变 generic 构建结果，也不构成模拟器交互证据。
- 原生源码边界审计通过：146 个 Swift 源文件；三个实际 App 包资源审计通过，没有所列 LUT/脚本文件或 WebKit/JavaScriptCore 直接链接。

日志与结果包位于 [artifacts/2026-10-03-project-asset-bookmark-renewal](artifacts/2026-10-03-project-asset-bookmark-renewal/)。

| 文件 | SHA-256 |
| --- | --- |
| `lutcalc-bookmark-renewal-debug-20261003.log` | `aac48d3510d438900dbc48c54ff583651ecffa8551031bf04cde8738a743d0aa` |
| `lutcalc-bookmark-renewal-release-20261003.log` | `3b6dad3a6aaab66cc559ca43cda77fceab6dccc6cf1f9e2fa83b1762e10e2f48` |
| `lutcalc-bookmark-renewal-full-release-20261003.log` | `d3d7ecb531cb08dcdc82d53b4eedb79de4a0c14b9859108ebc05a0484931ab27` |
| `lutcalc-bookmark-renewal-mac-build-20261003.log` | `01265ea5a94677b8c9ab526a23156c826b2428fd27c61fec35ee2ae3aa87ea4f` |
| `lutcalc-bookmark-renewal-ios-build-20261003.log` | `ea9b54565bc7a335587dc7ddab40df77fb314a00e54b60d5335650b097317b7d` |
| `lutcalc-bookmark-renewal-sim-build-20261003.log` | `bfab28be32915cd3fd4cea3346c70d52a5fb93095d80618298ec462e57ee8841` |
| `lutcalc-bookmark-renewal-source-audit-20261003.log` | `d3be41b866152b5840b67fbe667a6371e677fa390a20ee58f96d4f1c07fe63e2` |
| `lutcalc-bookmark-renewal-bundle-audit-20261003.log` | `5cf8f49359d02d2b03d3b23d7fcc0f25b68815ca27754ee29b15de8522a24d2f` |

## 未覆盖范围

本阶段不证明 stale 状态在真实 provider 上可复现，不证明撤销授权后能恢复访问，也不证明跨进程目标替换、离线、磁盘故障、后台终止恢复、实体 iPhone 11 性能或任何 UI／Finder／Files 交互。`docs/native-validation/full-scope-acceptance.json` 仍缺失，Goal 保持 active。

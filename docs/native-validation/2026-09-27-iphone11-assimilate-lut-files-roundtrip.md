# 2026-09-27 iPhone 11 Assimilate LUT 本地 Files 往返验收

## 范围

本轮只使用实体 iPhone 11（UDID `00008030-001015101ABA802E`，iOS 26.5），通过 Xcode 27、`xcodebuild` 和 XCTest 验证 Assimilate `.lut` 的原生 4096 点三通道 1D 生成、系统保存回调字节回读和独立 Files 本地列表发现。没有使用 iPhone Air、手机镜像或模拟器作为真机证据。

测试选择合法的 `dji.dlog2-to-dlog2-identity.v1` 预设，使 Assimilate `.lut` 的单位输入域、同色域和可表示码值约束可满足；没有修改 Double 生成路径、4096 点采样、量化或插值规则。

## 先行契约与构建

- `AssimilateExportContractsTests` 既有 sink 契约保持通过，覆盖负零单位域拒绝、4096 点三通道块顺序与 JavaScript half-tie 舍入、非单位域/目标已存在拒绝和不可表示码值取消清理。
- `xcodebuild ... build-for-testing` 退出码 `0`；日志 `/tmp/lutcalc-assimilate-build-for-testing.log`，SHA-256 `022c7437dbf92dd56095295c68c3b4aba352d382a52c8848f59fed37df839cbb`。
- 全包 `swift test --package-path Native/Packages/LUTKit -c release` 退出码 `0`；日志 `/tmp/lutcalc-assimilate-swift-release.log`，SHA-256 `1f5e7841699666da1a01424800e03e0399e2294f33a2d3fa81bbf75a85a07fe6`。
- macOS、generic iOS 和 iOS Simulator Release 构建均退出码 `0`；日志分别为 `/tmp/lutcalc-assimilate-mac-release.log`、`/tmp/lutcalc-assimilate-ios-release.log`、`/tmp/lutcalc-assimilate-sim-release.log`，三份均为空日志，SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。
- `git diff --check` 通过。

## 实体设备命令与结果

命令：

```text
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'id=00008030-001015101ABA802E' -derivedDataPath /tmp/LUTCalcAssimilateDeviceUITestDD DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates -only-testing:LUTCalcIOSUITests/LUTCalcIOSUITests/testSaveGeneratedAssimilateLUTAndReadBackOnDevice test
```

- 退出码 `0`；日志 `/tmp/lutcalc-iphone11-assimilate-files-roundtrip.log`，SHA-256 `8665bfcdf1a2f44e1e5a8b41a21438ea84b30d588ce98b13e50664ebebe78fb6`。
- 结果包：`/tmp/LUTCalcAssimilateDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_16-24-04-+0800.xcresult`。
- `xcresulttool` 摘要确认设备型号 `iPhone 11`、UDID 正确、iOS `26.5`，测试 `testSaveGeneratedAssimilateLUTAndReadBackOnDevice()` 为 `Passed`；摘要 JSON `/tmp/lutcalc-iphone11-assimilate-summary.json`，SHA-256 `6e9493116bcd4fe256eb96499d564f5fd0fa843a1e6264a9d548c32925f43a85`。
- XCTest 在 App 内确认系统保存回调 URL 的 Assimilate `.lut` 字节回读成功，状态文案为 `文件已保存并回读核对：<随机名>.lut`。
- 独立 `com.apple.DocumentsApp` 进入 `com.apple.FileProvider.LocalStorage` 的“我的iPhone”，`File View` 实际列出本次文件，例如 `LUTCalc-assimilate-48594CC5.lut`，约 58 KB。结果包附件导出目录：`/tmp/lutcalc-assimilate-xcresult-export-20260927`；Files 层级附件 SHA-256 `f93fed4b4ec80e1f740896ebd23be118e2989d414bf73b216ac79df8a60ebefb`。

## 未覆盖范围

本轮未从 Files 再次导入 Assimilate `.lut`，未在 Assimilate/Resolve 中导入验证，也未覆盖 iCloud/File Provider 授权失效、外部替换竞争、iPad 多窗口、macOS Finder 往返和完整发布清单。因此只增加 Assimilate `.lut` 本地保存/回读/独立列表证据，不勾选 FULL-06 全格式目标软件往返或 Goal 完成。

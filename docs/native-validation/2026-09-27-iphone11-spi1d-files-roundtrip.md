# 2026-09-27 iPhone 11 SPI1D 文件保存与独立 Files 列表验收

## 范围

本轮只使用实体 iPhone 11（UDID `00008030-001015101ABA802E`，iOS 26.5），通过 `xcodebuild`、XCTest 和独立 Files App 验证 SPI1D 的系统保存回调与本地文件列表发现；没有使用 iPhone Air、镜像或模拟器作为真机证据。

## 实际命令与结果

- 命令：`xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'id=00008030-001015101ABA802E' -derivedDataPath /tmp/LUTCalcDeviceUITestDD DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates -only-testing:LUTCalcIOSUITests/LUTCalcIOSUITests/testSaveGeneratedSPI1DAndReadBackOnDevice test`。
- 退出码 `0`；结果包 `/tmp/LUTCalcDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_05-51-32-+0800.xcresult` 报告 `passedTests=1`、`failedTests=0`，设备为 iPhone 11。
- 日志 `/tmp/lutcalc-spi1d-files-local-20260927.log`，SHA-256 `56b104f098e2b6373d521696f4877f28bfdcf5c6a8f8d1e4ebba7f72ceb86a9d`。

## 验收内容

- UI 选择 `SPI1D` 后，导航栏生成按钮标签确认包含 `SPI1D`；生成成功状态出现。
- 系统保存面板切换到“我的 iPhone”，写入唯一文件名 `LUTCalc-spi1d-<随机值>.spi1d`。
- App 收到保存回调后显示“文件已保存并回读核对”，由现有实现逐字节比较回调 URL 与生成文稿字节。
- 独立启动 Files App，确认进入 `com.apple.FileProvider.LocalStorage`，并在 `File View` 中发现本次 `.spi1d` 文件单元格。

## 未覆盖

本轮只证明本地“我的 iPhone”位置。iCloud/File Provider 授权失效与替换竞争、目标调色软件导入、SPI1D 项目资源重开、iPad 多窗口、macOS Finder 往返及全量发布清单仍未完成。


# 2026-09-27 macOS Finder 实际交互阻塞

## 现状

本轮尝试使用 CUA 检查已构建的 `LUTCalcMac.app` 并继续 Finder 文稿往返验证。构建本身成功：

`xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/LUTCalcMacDD CODE_SIGNING_ALLOWED=NO build`

退出码 `0`，App 位于 `/tmp/LUTCalcMacDD/Build/Products/Debug/LUTCalcMac.app`，日志 SHA-256 为 `612d7cf2a9fa7654dca3ee9b110a6c14a1fdf03707816ff7bd45d16737add333`。

CUA 返回主机锁屏且无法自动解锁，因此 Finder/应用实际点击、保存、重开本轮没有执行，也没有记录为通过。待主机解锁后才能继续该平台证据。

## 独立回归

新增 VLT 预设后完整 Swift Release：`swift test --package-path Native/Packages/LUTKit -c release` 退出码 `0`，日志 `/tmp/lutcalc-swift-release-after-vlt.log`；注册表、VLT 生成契约和其余测试均通过。


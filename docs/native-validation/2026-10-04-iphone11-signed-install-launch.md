# 2026-10-04 实体 iPhone 11 签名安装与原生进程启动验收

## 范围

本轮只验证当前源码的 iOS Release 签名构建、实体 iPhone 11 安装和原生进程启动边界。设备固定为 iPhone 11（UDID `00008030-001015101ABA802E`），未使用 iPhone Air、设备镜像或其他设备。没有执行 UI 自动化，也没有把进程启动解释为后台恢复、计算性能、文件往返或发布验收。

## 实际环境

- Xcode 27.0（27A266a）、Swift 6.4、iOS SDK 27.0。
- 设备系统 iOS 27.0（构建 `24A437`），`devicectl` 版本 `642.16`。
- 开发团队 `DD4V6SJ9XL`，签名身份 `Apple Development: Lingru Miao (555ZHJ6B72)`。
- App bundle ID：`org.lutcalc.native.dev.ios`。

## 命令与结果

1. 签名 Release 真机构建：

   ```sh
   xcodebuild -project Native/LUTCalc.xcodeproj \
     -scheme LUTCalcIOS -configuration Release -sdk iphoneos \
     -destination 'id=00008030-001015101ABA802E' \
     -derivedDataPath /tmp/lutcalc-iphone11-signed-20261004-v2 \
     DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic \
     CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates build
   ```

   退出码 `0`，产物为 `/tmp/lutcalc-iphone11-signed-20261004-v2/Build/Products/Release-iphoneos/LUTCalcIOS.app`。`codesign --display --verbose=4` 显示 Apple Development 签名、TeamIdentifier `DD4V6SJ9XL`、bundle identifier 正确；可执行文件 SHA-256 为 `59d382f76d90949e8c7696a8f7b0b94d46a902eb2fb95a70a71de76ec0c401a3`。

2. 安装当前构建到实体设备：

   ```sh
   xcrun devicectl device install app \
     --device 00008030-001015101ABA802E \
     /tmp/lutcalc-iphone11-signed-20261004-v2/Build/Products/Release-iphoneos/LUTCalcIOS.app
   ```

   退出码 `0`。设备返回安装容器：
   `file:///private/var/containers/Bundle/Application/2EF4E7D8-1812-4A4A-A297-BA67440853D0/LUTCalcIOS.app/`。

3. 通过 `devicectl` 启动安装后的 bundle，并查询进程：

   ```sh
   xcrun devicectl device process launch \
     --device 00008030-001015101ABA802E --terminate-existing --no-activate \
     org.lutcalc.native.dev.ios
   xcrun devicectl device info processes \
     --device 00008030-001015101ABA802E --search LUTCalc
   ```

   启动退出码 `0`，进程查询退出码 `0`；PID `920` 的可执行路径为上述新安装容器中的 `LUTCalcIOS.app/LUTCalcIOS`。

## 结果包

原始命令输出、JSON、签名信息和哈希保存在：
`docs/native-validation/artifacts/2026-10-04-iphone11-process-launch/`。

- `signed-build.log` / `signed-build.exit`
- `codesign-display-final.log` / `app-executable.sha256`
- `install-current-signed.json` / `install-current-signed.log`
- `launch-current-signed.json` / `launch-current-signed.log`
- `processes-current-signed.json` / `processes-current-signed.log`
- `device-details.json` / `device-details.log`

构建期间出现 CoreSimulator 内存初始化提示和 AppIntents 可选依赖警告；它们没有改变 iphoneos 构建、签名、安装或启动结果。签名构建先前未提供开发团队时的失败日志仍保留在 `2026-10-04-iphone11-backend-build.log`，不与本次成功结果混合。

## 未覆盖范围

- 没有证明 UI 字段、SwiftUI 无障碍、旋转或多窗口。
- 没有证明 iCloud/File Provider 授权失效、外部替换竞争、后台终止恢复或磁盘故障。
- 没有证明 iPhone 11 上的 LUT 计算数值、CPU/内存/取消延迟或完整格式 Files 往返。
- 该开发签名不等同于发布签名、公证、商店上传或最终发布入口通过。
- `docs/native-validation/full-scope-acceptance.json` 仍缺失，未创建或伪造。


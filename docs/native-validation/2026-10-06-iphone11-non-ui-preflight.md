# iPhone 11 非 UI 真机验收预检

## 设备与入口

本轮只使用实体 iPhone 11，UDID 为
`00008030-001015101ABA802E`。`xcrun devicectl list devices` 显示该设备为
`connected`、型号 `iPhone 11 (iPhone12,1)`。没有使用 iPhone Air、模拟器或
设备镜像替代。

现有 `Native/LUTCalc.xcodeproj` 的 `LUTCalcIOS` scheme 已绑定
`LUTCalcIOSUITests`。测试入口已经包含 CUBE、SPI1D、SPI3D、3DL、ILUT、OLUT、
Assimilate、VLT 的 Files 保存／回调字节回读／独立 Files 列表，以及前后台文稿
恢复和慢导出后台取消恢复用例。入口文件为
`Native/Tests/iOSUI/LUTCalcIOSUITests.swift`；本轮没有改 UI 或测试逻辑。

## 实际命令和结果

构建预检：

```sh
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS \
  -configuration Debug \
  -destination 'id=00008030-001015101ABA802E' \
  -derivedDataPath /tmp/lutcalc-iphone11-preflight-dd-20261006 \
  DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic \
  CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates build-for-testing
```

该命令生成了 `Debug-iphoneos/LUTCalcIOS.app`、测试 Runner 和
`LUTCalcIOS_iphoneos27.0-arm64.xctestrun`。日志中只有既有 XCTest actor
隔离 warning；同时记录了 CoreSimulator 初始化的内存错误和 Xcode 账户
凭据 warning，未使用模拟器。

随后用同一实体设备、同一构建目录运行前后台用例：

```sh
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS \
  -configuration Debug \
  -destination 'id=00008030-001015101ABA802E' \
  -derivedDataPath /tmp/lutcalc-iphone11-preflight-dd-20261006 \
  DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic \
  CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates \
  -only-testing:LUTCalcIOSUITests/LUTCalcIOSUITests/testDocumentViewSurvivesBackgroundAndForegroundOnDevice test
```

结果退出码 `65`：测试 Runner 在建立连接前以 code `74` 提前退出，未取得
新的真机通过证据。`devicectl diagnose` 也因同一环境问题失败并生成了部分
诊断包。结果日志：

- `build-for-testing.log` SHA-256 `950f3bb9ea064281dc9872062367f067839a223383a7181ef80baff394f24f98`
- `background-test.log` SHA-256 `4aa57901d88eefe29dcea4a566352b2b7d8129ff59ec7d6f02082b2e68b7fa14`

## 未覆盖与结论

本轮只完成入口和签名构建预检；没有把失败的 Runner 启动当作测试通过，未
新增 Files、后台恢复或导出格式验收记录。阻塞原因是当前 Xcode/CoreDevice
测试运行环境在启动 Runner 前失败；CoreSimulator 另报 `NSPOSIXErrorDomain
Code=12`，但没有用模拟器替代真机证据。Goal 保持 `active`。


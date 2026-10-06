# iPhone 11 前后台恢复复验

## 设备与命令

设备由 `xcrun devicectl list devices` 确认为实体 iPhone 11，UDID：
`00008030-001015101ABA802E`，状态 `connected`。使用当前 Xcode 27.0 和同一项目执行：

```sh
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS \
  -configuration Debug \
  -destination 'id=00008030-001015101ABA802E' \
  -derivedDataPath /tmp/lutcalc-iphone11-retry-dd-20261006 \
  DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic \
  CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates \
  -only-testing:LUTCalcIOSUITests/LUTCalcIOSUITests/testDocumentViewSurvivesBackgroundAndForegroundOnDevice test
```

## 结果

命令退出码 `65`。日志 SHA-256：
`d45643cce5f05b4664a9b89528577a626c3b3ffe545ffe9ce11380a66b0606e3`。

`LUTCalcIOSUITests-Runner` 在建立 XCTest 连接前以 code `74` 提前退出，测试没有执行完成，因此没有新增前后台恢复通过证据。日志还记录 CoreSimulator `NSPOSIXErrorDomain Code=12` 和 Xcode 凭据缺失；本轮没有使用模拟器冒充真机证据。

## 结论

该复验只确认指定实体设备仍可发现，并保留了当前测试运行环境阻塞。后台恢复、真实 File Provider/iCloud 和完整设备验收继续未完成，Goal 保持 `active`。

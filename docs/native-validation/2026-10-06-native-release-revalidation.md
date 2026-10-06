# 原生 Release 发布入口复验

## 命令与结果

```sh
Scripts/verify-native-release.sh
```

工具链为当前 Xcode 27 / SwiftPM Release。macOS、iOS Simulator、iOS device 三个 Release 构建均完成，原生验证与 App 包资源审计通过；3 个 App 包未发现所列 LUT/脚本文件或 WebKit/JavaScriptCore 直接链接。

脚本最终退出码为 `2`，唯一阻塞是缺少真实的 `docs/native-validation/full-scope-acceptance.json`。没有创建或伪造该清单。完整日志：`/tmp/native-release-current-20261006.log`，SHA-256：`b0d18b06bd032fe1e466e1dcc3be7f1eb0004a2c254d34864538743228449ed68`。

## 未覆盖

该复验不证明 Finder 直接双击重开、iPadOS 多窗口/旋转/无障碍、File Provider 授权失效与后台恢复、第三方软件往返、签名公证、完整 ICC/HDR/LUTAnalyst 或最终全量清单完成；Goal 保持 `active`。

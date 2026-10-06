# macOS Release 本地签名与包审计

## 范围

本轮只做非 UI 的 macOS Release 包证据，不创建或修改全量发布清单，也不进行公证提交。

## 构建与签名

Xcode 27.0（27A266a）先以 `CODE_SIGNING_ALLOWED=NO` 构建 `LUTCalcMac` Release，随后对生成的 App 使用本机已有 Developer ID Application 证书离线签名：

```text
xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath /tmp/LUTCalcUnsignedMacDD CODE_SIGNING_ALLOWED=NO build
codesign --force --deep --options runtime --timestamp=none \
  --sign 'Developer ID Application: Lingru Miao (DD4V6SJ9XL)' \
  /tmp/LUTCalcUnsignedMacDD/Build/Products/Release/LUTCalcMac.app
codesign --verify --deep --strict --verbose=4 \
  /tmp/LUTCalcUnsignedMacDD/Build/Products/Release/LUTCalcMac.app
spctl --assess --type execute --verbose=4 \
  /tmp/LUTCalcUnsignedMacDD/Build/Products/Release/LUTCalcMac.app
```

构建、签名和 `codesign --verify` 均通过。`spctl` 返回 `source=Unnotarized Developer ID`，
并显示 `override=security disabled`；这证明本地签名结构可验证，但不证明 notarization 或
Gatekeeper 默认放行。直接让 Xcode 对 SwiftPM 目标注入 Developer ID 会因自动签名设置冲突
而失败，未修改工程配置。

## 包审计

```text
python3 tools/native-validation/audit-native-bundles.py \
  /tmp/LUTCalcUnsignedMacDD/Build/Products/Release/LUTCalcMac.app
```

退出码 `0`：App 包未包含所列 LUT/脚本资源，也未直接链接 WebKit/JavaScriptCore。
该审计不替代等价采样数据人工审查。

日志 SHA-256：

- 构建：`28e53d2150ff0e209a0c460f02a6d2a6d71ed6b76856a3606fea81f5aea969b6`
- 签名：`6766adeaf45cba9081ab195d329a803241a258ed736672f2a0c54303a1a881b6`
- codesign 验证：`5ed52ea7e30ebac0ba33e35364af58bbb8ed1527c5ea265eb43de267441a9a26`
- spctl：`0c15ff3224a856dd0aa2836e364742aec6082810cf471d4f9a1502601b16dbca`
- 包审计：`4c11a8632167524ad0a665daf072c8aff412f3dae7866ee384c0871449d3f51a`

## 未完成

`xcrun notarytool history` 要求 App Store Connect 或钥匙串凭据，本轮没有凭据，未提交公证。
真实发布签名、公证、票据 stapling、默认 Gatekeeper 验收及全量清单仍未完成；
`docs/native-validation/full-scope-acceptance.json` 保持不存在，Goal 继续 `active`。

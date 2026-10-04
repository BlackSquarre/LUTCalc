# 2026-09-27 导出设置控件可验证性补充

## 修改

在 `ProjectDocumentView` 为输入曲线、输入范围、输出曲线和输出范围 Picker 增加稳定 accessibility identifier：`inputTransferPicker`、`inputRangePicker`、`outputTransferPicker`、`outputRangePicker`。这些标识只描述现有 SwiftUI 控件，不改变计算、格式约束或默认设置。

## 验证

使用 `xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalcGenericAfterVLT2 DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=NO build-for-testing`，退出码 `0`。

## 边界

标识使后续真机 UI 测试可以定位具体设置，但不构成 VLT 真机生成通过证据。VLT 仍要求合法的单位域、17³ 和 0…1 输出；iPhone 11 上尚未取得满足这些设置的系统保存往返结果。


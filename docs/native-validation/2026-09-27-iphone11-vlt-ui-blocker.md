# 2026-09-27 iPhone 11 VLT 文件界面验证阻塞

## 结果

本轮尝试在实体 iPhone 11（`00008030-001015101ABA802E`）上通过 UI 测试选择 `VLT Varicam 17³` 并保存。测试未形成正证据：VLT 生成完成状态没有出现，后续“保存到文件…”按钮不存在。

首次尝试还发现 iOS 26.5 将 VLT 选项暴露为静态文本而非按钮；测试查询已改为同时支持按钮和静态文本，但这只修正了自动化查询，不能改变格式约束。

## 具体命令与失败证据

命令使用与其他 iPhone 11 UI 验收相同的 `xcodebuild` 参数，结果包为：

`/tmp/LUTCalcDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_06-01-12-+0800.xcresult`

结果为 `failedTests=1`。失败位置是生成成功状态断言；随后一次尝试先切换目标空间、尝试把输出曲线改为 D-Log2 并将曝光改为 0，但曝光输入在滚动后的界面不可点击，仍未形成有效项目设置。该次结果包为 `/tmp/LUTCalcDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_06-07-17-+0800.xcresult`。没有把这些尝试计入 VLT 真机通过项，也没有保留临时失败测试。

## 边界

Swift VLT 格式解析/写出契约和命令行验证仍有效；本记录只说明当前 iPhone 11 默认项目设置尚未取得 VLT 系统保存面板往返证据。需要后续提供满足 VLT 单位域、17³ 和 0…1 输出约束的可验证项目设置后再重试。第三方软件导入、File Provider、iPad 多窗口和 macOS Finder 仍未覆盖。

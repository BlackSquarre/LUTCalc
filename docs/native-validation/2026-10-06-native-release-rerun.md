# 原生发布入口复跑

## 命令

```sh
bash Scripts/verify-native-release.sh
```

工具链为 Xcode `27.0`、Build `27A266a`，使用当前工作区的 Swift Package 和 `Native/LUTCalc.xcodeproj`。

## 结果

入口中的 Python、Node、Swift 数值与契约检查通过；macOS Release、iOS Simulator Release、iOS generic Release 构建均显示 `BUILD SUCCEEDED`。三个 App 包的资源审计通过，未发现所列 LUT、脚本文件或 WebKit/JavaScriptCore 直接链接。

最终发布证据检查退出 `2`，唯一报告原因是缺少真实的 `docs/native-validation/full-scope-acceptance.json`。本轮没有创建或伪造该文件，也没有把阶段性构建结果计为完整发布验收。

## 未覆盖范围

真实全量 H01-H14/FULL-01 至 FULL-08 清单、公证与票据 stapling、Finder/iPadOS/实体 iPhone 11 交互、File Provider/iCloud、第三方软件往返、`.labin` 与直接查表替代仍未完成。Goal 保持 `active`。

# LUTCalc 原生预览版使用说明

## 当前范围

本版本是 macOS、iOS 和 iPadOS 共用 Swift 数值内核的原生预览版。界面使用 SwiftUI，生成路径使用 `Double`，项目文件使用原生 `.lutcalc` 目录包。

当前已验证的主要流程：

- 创建原生项目文稿并编辑输入/输出曲线、色域、范围、曝光和网格尺寸。
- 生成 CUBE、SPI1D、SPI3D 及已接入的其他严格格式子集。
- 在生成过程中取消任务；取消不会提交不完整文件。
- 导入用户 LUT 并进行直接取样、单调性和有限范围分析。
- 导入图像，保留 alpha、方向和源 ICC provenance，生成 CPU Double 参考预览。
- 保存和重开 macOS 项目包；iPhone 11 已验证创建文稿、生成 CUBE/SPI3D、取消、前后台恢复和旋转。

## 使用边界

- 内置转换由 Swift 公式、矩阵和参数重建，不依赖厂商 LUT、旧 `.labin` 或测试夹具。
- 用户导入的单位域一维 LUT 可作为生成计划末端的逐通道阶段；三维 LUT、带 shaper 或非单位域仍只用于取样/分析，应用不会猜测其逆变换或色域语义。
- 任意 3D LUT 反求、资料不足的厂商风格曲线和未冻结的完整 ACES 输出变换会明确报告不支持或研究阻塞。
- iOS 保存面板是否能实际写入 Files，取决于设备上的 Files 提供方和系统权限；当前仍需独立验收。

## 验证入口

在工程根目录执行：

```sh
Scripts/verify-native-fast.sh
Scripts/verify-native-numerics.sh
Scripts/verify-native-release.sh
```

最后一个入口要求真实全量验收清单；清单缺失时会失败，不应手工绕过。

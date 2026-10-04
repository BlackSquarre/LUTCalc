# 导出格式动态文案阶段验收

日期：2026-09-27。

## 修复

项目导航栏原先固定显示“生成 CUBE”，即使用户在表单中选择了 SPI3D、SPI1D 或其他已接入格式。现改为读取 `exportFormat` 动态显示，并保留稳定的 `toolbarGenerateLUTButton` accessibility identifier。VoiceOver 标签同步使用当前格式。

## 实际验证

- Swift Release 测试通过，日志 `/tmp/lutcalc-dynamic-export-label-swift.log`，SHA-256：`9f8fd2f0edb5972e106e62448ce952db42c9b1c7a251a2ac29ac521cce4d8c76`。
- generic iOS Debug 构建通过，日志 `/tmp/lutcalc-dynamic-label-fix-build.log`，SHA-256：`1eb95d5663b94b501e0b2d200bedf3372e34b34824131ca567c2d27186c27a48`。
- 实体 iPhone 11（`00008030-001015101ABA802E`）6 项 UI 测试通过，覆盖 CUBE、SPI3D、取消、关闭文稿、前后台恢复和旋转。日志 `/tmp/lutcalc-iphone11-dynamic-label-fix-ui.log`，SHA-256：`f20402066e85ffc1aa7031df61b11707cd02d6d340d3aeea457c8a055476ef3b`。
- 将 SPI3D 动态文案固定为 UI 契约：测试在点击生成前读取 `toolbarGenerateLUTButton` 的运行时标签，并断言包含 `SPI3D`。实体 iPhone 11 单项测试通过，实际标签为“生成 SPI3D LUT”。日志 `/tmp/lutcalc-iphone11-spi3d-label-contract.log`，SHA-256：`f4595b3de37ea697c3be291b59277ea7de7219f75f06d8ae7819df8c8b7a0fb4`。
- 加入该断言后重新运行实体 iPhone 11 全部 6 项 UI 回归，6 项、0 失败。日志 `/tmp/lutcalc-iphone11-dynamic-label-full-ui.log`，SHA-256：`7afeee7c07673de8764638ef3e11f5febc37df06538e98962b41bc48f25c95ae`；结果包：`/tmp/LUTCalcDeviceDynamicLabelFullDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_03-12-20-+0800.xcresult`。

## 相关格式类型补齐

- 为 SPI1D、3DL、ILUT、OLUT、Assimilate `.lut` 和 VLT 增加独立 `UTType`、双端 plist 声明及 `GeneratedLUTExportDocument` 映射；避免生成文件在系统保存面板中退化成泛用 `public.data`。
- 新增 Swift 契约覆盖 8 种生成扩展名的稳定类型标识；`GeneratedLUTExportDocumentContractsTests` 4 项通过。双端 `verify-native-document-types.py` 和 plist 语法校验通过。
- macOS/iOS Debug generic 构建通过。日志 `/tmp/lutcalc-export-types-mac.log`（SHA-256 `e84fccd4a4cf9ae9d07a013f831a8c5287bc7b3ca5c0a057ab6aad59e07561a8`）和 `/tmp/lutcalc-export-types-ios.log`（SHA-256 `a10bb7e80a034f851d440e53b720e06845c25bb6795dffbbf08c385a893b5077`）。Swift Release 全包测试通过，日志 `/tmp/lutcalc-export-types-swift-release.log`，SHA-256 `3aa01ffc333561cdd7fed72291611797d24907fd6e78a4db6b9c1faaeea56a7c`。
- 仅使用实体 iPhone 11（`00008030-001015101ABA802E`）验证 SPI1D：先选择同色域 DJI D-Log2/D-Gamut2，再生成、打开系统保存面板并取消，1 项、0 失败。日志 `/tmp/lutcalc-iphone11-spi1d-export-type2.log`，SHA-256 `136a1d2117e03feeee1eb0e424108de043d4cba1d8e81f9876992b7883001cc6`；结果包位于 `/tmp/LUTCalcDeviceSPI1DTypeDD/Logs/Test/`。
- SPI1D 跨色域拒绝仍是设计契约；第一次默认 AP0 测试因该前提失败，未修改实现或放宽约束。此阶段只完成系统类型语义和同色域 SPI1D 真机链路，不代表所有格式的 Files 实际写入或完整目标软件兼容。

未改变计算路径、Double 精度、网格尺寸、文件格式或测试阈值。

# `.3dl` Flame/Assimilate 整数子集阶段验收

日期：2026-09-24。范围：FULL-06 的一个格式子集；不代表 FULL-06 或原生迁移完成。

## 来源与边界

- 旧源码 `js/lut-3dl.js`：`threedlLUT.build` 的 flavor 1，文件行循环为 R 外层、G 中层、B 内层；内部数组索引为 `r+N*(g+N*b)`。shaper 使用 `ceil(j*(2^inBits-1)/(N-1))`，输出对正数使用 `Math.round(value*(2^outBits-1))`，非正数写 0。`js/lutformats.js` 的 Assimilate/Flame 预设均映射 `threedl1`，分别列出 16/32/64 与 17/33/65 的尺寸。
- Swift 当前仅提供显式 `flavor: .flame` 的基础整数 3D 子集。要求 `NUMBER OF NODES`、`INPUT RANGE`、`OUTPUT RANGE` 元数据，首个非注释行为线性 shaper，后续恰好 N³ 个三通道整数码值；保留可选 TITLE。输入位宽和输出位宽限 1...24，内部按 unit 域 Double 保存。
- 旧解析器会猜位宽、猜尺寸、接受非线性 shaper 与某些格式不完整数据。本子集不做推断；非线性 shaper、`3DMESH/Mesh` 的 Lustre、Kodak 特有约束、无元数据文件及目标软件导入兼容仍待后续分项。
- 旧 writer 对负数写零，对超白可能写出超过声明位宽的码值。新 writer 对负数和超白返回 `lossyRepresentation`；这是刻意收紧的文件边界，不将旧有静默损失当作正确数值。

## 契约与结果

- 先加入 `ThreeDLContractsTests.swift`，运行定向测试因 `ThreeDLParser`/`ThreeDLWriter` 尚不存在而编译失败；之后实现 `ThreeDL.swift` 并修正文件顺序与内部轴序的独立断言。
- 已测非对称 2³ 节点映射、0.5 × 15 的 half-up 码值 8、写出再读回、缺行/多行、非有限值、非法输出码值、错误行数元数据、非线性 shaper、Lustre 头部和负数写出拒绝。未对第三方应用执行导入回读。
- 实际命令 `swift test --package-path Native/Packages/LUTKit --filter ThreeDLContractsTests`：4 项通过。`swift test --package-path Native/Packages/LUTKit`：全部包测试通过，退出码 0。工具链 Apple Swift 6.4 / Xcode 27.0，主机 arm64 macOS。
- 文件 SHA-256：`ThreeDL.swift` `9340ef368cab2a1e99d458b5854e1fbc205c03319e9953c264b0ddd0ef61ab89`；`ThreeDLContractsTests.swift` `86329102a53e718cbca58a5d962660d19d69066e7f00b69d9021c5476319dbb7`。

## 待续

本包未接入 App 格式注册或流式任务导出，未做 17³/33³/65³ 性能和目标软件实测。Lustre、Kodak、非线性 shaper、缺元数据的可判定文件需分别建立夹具和验收门槛。源码/测试夹具未打入 App 资源；发布状态仍依赖完整范围验收。

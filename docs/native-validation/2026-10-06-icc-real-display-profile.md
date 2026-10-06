# 2026-10-06 ICC 真实显示器 profile 结构验收

使用 macOS `/Library/ColorSync/Profiles/Displays/XBH-6C4F598C-E1DA-4CA4-82C7-618A66227F93.icc` 做结构验证。该 profile 带有非零 profile ID；独立 Python MD5 检查确认只清零 header 的 16 字节 ID 字段即可得到相同摘要，flags 和 device attributes 本身为零。

新增 `PreviewContractsTests.testRealSystemDisplayProfilePassesStructuralValidation`，验证 `RGB `/`XYZ ` 头字段、tag 目录、非空摘要和 profile ID 校验。

同一真实 profile 也通过 Matrix/TRC 执行路径：以输入 `(0.21, 0.58, 0.87)` 运行 RGB -> XYZ -> RGB，XYZ 三通道均为有限 `Double`，回读最大绝对误差不超过 `3e-4`。这只证明该显示器 profile 的实际矩阵／TRC 编解码路径可执行；没有把 ColorSync、第三方逐码参照、BPC 或 gamut mapping 视为已完成。

实际 profile 路径：

```text
/Library/ColorSync/Profiles/Displays/XBH-6C4F598C-E1DA-4CA4-82C7-618A66227F93.icc
```

实际命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter PreviewContractsTests
```

结果：PreviewContractsTests 与 UserLUTPostStagePreviewContractsTests 合计 45 项通过。该项只证明真实显示器 profile 的结构验证，不代表 ColorSync 逐码转换、BPC、gamut mapping 或完整 ICC 已完成。

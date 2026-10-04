# 2026-10-03 `.3dl` Lustre/Kodak 纯 Swift 子集验收

## 范围

本阶段只补齐旧实现中可追溯的 `.3dl` Lustre/Kodak 文件语法子集。实现位于 `LUTFormats/ThreeDL.swift`，继续使用 Swift `Double` 解析后的 `CubeLUT`，没有打包厂商 LUT、`.labin` 或采样表。没有执行目标调色软件导入、设备文件流程、UI 或发布签名验收。

## 实现

- `ThreeDLFlavor` 新增 `.lustre` 和 `.kodak`。
- Lustre 严格要求 `3DMESH`、`Mesh 3/4/5/6/7 <outputBits>` 对应 9/17/33/65/129 节点、线性 shaper、完整三维整数行以及 `LUT8`/`gamma 1.0` 尾部；不猜测尺寸、位宽或非线性 shaper。
- Kodak 使用与 Flame 相同的纯整数行布局，但明确拒绝 Lustre mesh/尾部标记。无厂商标记时两种布局在字节层不可区分，因此自动导入只在发现显式 `3DMESH` 时选择 Lustre，否则使用 Flame 行解析，不伪造 Kodak 识别。
- `ThreeDLParser.parseAuto` 已接入 `NativeUserLUTLoader` 的 `.3dl` 用户主动导入路径。导出任务保持原 Flame 格式，Lustre/Kodak 导出尚未接入格式选择和流式 sink，避免未经目标软件证据扩大写出承诺。

## 契约与结果

定向命令：

```sh
swift test --package-path Native/Packages/LUTKit --filter 'ThreeDLContractsTests|UserLUTImportContractsTests'
```

结果：`ThreeDLContractsTests` 8 项通过；`UserLUTImportContractsTests` 10 项通过，其中新增 Lustre 用户导入 1 项；0 失败。日志：`/tmp/lutcalc-3dl-flavors-import-final-20261003.log`，命令退出码 `0`。

覆盖内容：Lustre mesh 头/尾写出与解析、9 节点量化读回、2 节点拒绝、Kodak 纯行解析与 Lustre 标记拒绝、自动识别、真实用户导入以及既有 Flame 行为回归。

## 未完成

本阶段不证明 Lustre/Kodak 目标软件兼容、第三方往返、非线性 shaper、无元数据文件、其他厂商方言、完整格式矩阵、真机 Files/File Provider 或 FULL-06 完成。Lustre/Kodak 的流式导出尚未接入 `FileCubeSink`；NCP 写出继续明确拒绝。Goal 保持 active。

修复后的完整命令 `swift test --package-path Native/Packages/LUTKit` 于 2026-10-03 实际通过：8 个测试包共执行 538 项、0 失败；旧 `.labin` 与 NCP 外部夹具各 1 项跳过。日志 `/tmp/lutcalc-3dl-lustre-kodak-full-20261003.log`，SHA-256 `47ec221a60b3c45dcf79eb6b92aa5838aed96d66ec1e1fe8ea31486095e733c5`，外层退出码 `0`。

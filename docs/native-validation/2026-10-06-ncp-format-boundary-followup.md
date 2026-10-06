# NCP 与剩余 LUT 格式边界复核

日期：2026-10-06。

## 复核范围

本轮复核 NCP 0100、ILUT、OLUT、3DL、VLT 和 Assimilate LUT 的当前 Swift 解析器、写出器及契约测试。复核只依据仓库源码、公开 NCP 0100 结构记录和已存在的独立整数参照，不把旧 JavaScript 自回归当作厂商兼容证据。

## 实测命令与结果

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'LUTFormatsTests\\.(NCP0100ContractsTests|ILUTContractsTests|OLUTContractsTests|AssimilateLUTContractsTests|ThreeDLContractsTests|VLTContractsTests)'
```

结果：LUTFormats 测试包执行 37 项，失败 0 项；NCP 公开实样测试因未设置 `LUTCALC_NCP0100_SPECIMEN` 跳过 1 项。ILUT 6 项、OLUT 6 项、Assimilate 7 项、3DL 10 项、VLT 4 项以及 NCP 其余 3 项均通过。构建为 SwiftPM Release，退出码 0。

## 结论

- NCP 0100 继续只读：解析器限制 638 字节、`NCP\\0`、big-endian `0100` 两段布局、已观察基础风格代码、ASCII 名称、控制点和 256 个 15-bit LUT 码；未知布局、风格、版本和范围明确拒绝。
- `NCP0100Writer` 继续抛出 `.writeUnsupported`，并保持已有目标字节不变。公开社区样本和独立解析器只能证明观察到的记录布局，不能证明标题编码、调整字段、控制点压缩、设备型号／固件语义或 Nikon 软件／相机导入行为。
- ILUT、OLUT 的固定整数格式已有独立 half-up 参照；3DL、VLT 和 Assimilate 的当前方言子集已有有限值、行数、轴序、量化和可表示性拒绝契约。没有发现无需引入新方言或厂商私有规则即可安全扩大范围的缺口。

## 未覆盖与解锁条件

NCP 写出仍需带机型、固件、基础 Picture Control、生成工具版本的受控样本，多样本字段比较，Picture Control Utility 2 或 NX Studio 独立读回，以及相机实际导入。其他格式仍缺少目标软件互操作、全部私有方言和真实 Files/Finder 往返。FULL-06 不勾选，Goal 保持 active。

# LUT 格式解析器结构边界审计

日期：2026-10-06。

## 审计结论

本轮检查 CUBE、SPI1D、SPI3D、VLT、ILUT、OLUT、3DL、Assimilate LUT 与 NCP 0100 现有 Swift 解析器的公开结构边界。解析器已经对版本／签名、维度、节点数溢出、行数、重复或越界索引、有限数值、编码、代码范围和资源上限执行显式拒绝；没有发现可在不扩大格式方言或厂商兼容承诺的情况下安全新增的最小结构修复。

NCP 0100 继续保持只读观察模型。由于缺少公开厂商写出规范和独立软件往返证据，不新增 writer，也不把观察布局推断为完整 Nikon 兼容格式。

## 实际命令与结果

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'CubeContractsTests|SPI1DContractsTests|SPI3DContractsTests|VLTContractsTests|ILUTContractsTests|OLUTContractsTests|ThreeDLContractsTests|AssimilateLUTContractsTests|NCP0100ContractsTests'
```

SwiftPM Release 定向组合结果：各匹配测试包共执行 51 项，跳过 1 项需外部 NCP 实样的可选测试，失败 0 项，退出码 `0`。原始日志和 SHA-256 位于 `artifacts/2026-10-06-parser-boundary-audit/`。

## 未覆盖范围

本审计不证明目标调色软件互操作、厂商私有方言完整覆盖、所有格式的真实 Files/Finder 往返、NCP 写出、任意 3D LUT 反求、`.labin` 或直接查表替代。UI、设备、性能、完整 ICC/HDR/OOTF 与发布验收仍未完成，Goal 保持 `active`。

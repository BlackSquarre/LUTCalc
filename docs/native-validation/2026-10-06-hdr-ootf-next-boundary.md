# HDR/OOTF 下一轮边界复核

日期：2026-10-06。

## 本轮目的

本轮只复核已经具备公开公式的 HDR 传递路径，寻找可以在不引入设备假设的条件下继续闭合的最小算法项。没有新增生产算法，也没有把历史 PQ OOTF 接入标准目录。

## 先行契约与结果

工具链为当前主机 Apple Swift 6 工具链，SwiftPM Release。实际命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'BT2100HLGReference|HLGOOTFContractsTests|LegacyPQOOTFContractsTests|BT1886TransferTests|NumericContractsTests/testBT1886ReferenceDisplayEOTFContract|RegistryContractsTests/testRec2100PQReferenceRemainsSeparateFromLegacyOOTF|PreviewContractsTests' \
  | tee /tmp/lutkit-hdr-ootf-next-20261006.log
```

结果：退出码 `0`。LUTCore 选定测试 36 项、目录隔离测试 1 项、预览契约 36 项，均为 0 失败。日志 SHA-256：

`c2ae04188d84f2bbc85632059652a686d7e8321da5c5297716f3e10e00305ac7`

独立 Decimal 参照仍满足：HLG reference OOTF 标量最大尺度误差 `1.1102230246251565e-16`，RGB 最大尺度误差 `1.3342336993997586e-16`，extended gamma 最大尺度误差 `4.974256639474225e-16`，extended EOTF 最大尺度误差 `7.771561172376096e-16`。

## 审计结论

- BT.1886 显示 EOTF、PQ 绝对亮度编码、HLG reference OOTF/EOTF 以及历史 HLG 兼容核均已有公开公式、明确单位和定向契约；本轮没有发现可安全新增且不扩大范围的算法缺口。
- 标准 PQ scene-to-display OOTF 仍不能由 ST 2084 的绝对亮度编码单独确定。缺失参数包括场景单位、参考白、系统 gamma、黑位、显示峰值和裁切策略。
- EDR 峰值、自动峰值和设备色彩管理属于设备语义，当前没有可引用的逐码独立参照；不能用默认值、插值或厂商采样表代替。
- `LegacyPQOOTF` 继续保持兼容隔离，历史 knee 跳变不平滑；`rec2100.pq-reference.v1` 不携带 OOTF 设置。

因此，本轮只新增验证证据，不关闭完整 PQ OOTF、自动峰值、HDR/EDR 设备语义或完整发布验收。研究阻塞保持原状，Goal 继续保持 `active`。

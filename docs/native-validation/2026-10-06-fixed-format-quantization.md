# ILUT 与 OLUT 固定整数编码验收

日期：2026-10-06。

## 范围

本轮只核对已有 ILUT（14-bit、16,384 行）和 OLUT（12-bit、4,096 行）格式的编码边界。没有新增厂商格式方言、采样数据或 UI 接线。

独立参照为整数域公式：对 unit-domain 的 `Double` 值 `v`，编码值为 `roundHalfUp(v * codeMax)`，其中 ILUT 的 `codeMax = 16383`，OLUT 的 `codeMax = 4095`；解码值为 `code / codeMax`。端点、半码附近整数值和 CRLF 输入均直接按该公式核对。

## 契约与结果

新增四项契约：

- ILUT writer 的 0、1、2、中点及两端整数值与独立 half-up 参考逐行一致；
- ILUT parser 对 CRLF 保持相同端点与中点值；
- OLUT writer 的对应 12-bit 整数值及六列重复编码逐行一致；
- OLUT parser 忽略注释和 CRLF，且端点与中点值保持一致。

实际命令：

```sh
swift test --package-path Native/Packages/LUTKit -c release \
  --filter 'ILUTContractsTests|OLUTContractsTests'
```

结果：LUTFormats 定向执行 `12` 项，失败 `0`，退出码 `0`。日志：`artifacts/2026-10-06-fixed-format-quantization/release.log`，SHA-256：`84d58e8dce68e01bb82e1f80dbfd032cf181ff9ef744c55db561b2ae83c40bcb`。

## 未覆盖范围

该验收不代表 ILUT/OLUT 的目标调色软件互操作、设备或 Files 往返，也不关闭 `.labin`、直接查表、NCP 写出或全部格式批量覆盖。现有 writer 对非 unit domain、负零和无法无损量化的输入继续拒绝；NCP 仍只读，厂商写出资料不足保持阻塞。

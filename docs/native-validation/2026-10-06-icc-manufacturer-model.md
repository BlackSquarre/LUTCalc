# ICC manufacturer/model 头字段边界验收

## 范围

本项只验证 ICC profile header 的 device manufacturer（offset 48）和
device model（offset 52）四字节字段。字段可以全零表示未知；非零值必须
是合法 ASCII 四字符签名。实现只保留结构元数据，不把厂商或型号推断为
色彩算法，也不引入任何厂商 LUT 或查表资源。

## 契约与实现

- 先加入非零非法字节的失败契约，分别确认 `invalidManufacturerSignature`
  和 `invalidModelSignature`。
- 加入合法 `APPL`/`LUTC` fixture，确认字段原样暴露；默认全零仍为 `nil`。
- `ICCProfileValidation` 新增 `manufacturerSignature` 与 `modelSignature`。
- `ICCProfileValidator` 在验证 profile class/平台/creator 的同一结构路径上
  验证两字段，并拒绝非四字符可打印 ASCII 签名。

## 实际命令与结果

工具链：SwiftPM、当前工作区 Swift 工具链，LUTKit。

```text
swift test --package-path Native/Packages/LUTKit -c debug --filter PreviewContractsTests
swift test --package-path Native/Packages/LUTKit -c release --filter PreviewContractsTests
```

两条命令均退出码 0；`PreviewContractsTests` 每次执行 41 个测试，包含新增
manufacturer/model 合法与非法边界，0 失败。构建期间仅有既有的未修改变量和
冗余 try 警告，不影响结果。

## 未覆盖范围

本项不声称完成 ICC 完整 profile 语义、manufacturer/model 注册表、ColorSync、
第三方逐码参照、BPC、gamut mapping 或任何 UI/平台验收。Goal 继续保持 active。

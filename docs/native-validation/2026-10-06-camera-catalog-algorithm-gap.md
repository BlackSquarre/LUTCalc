# 相机目录算法缺口审计

## 范围

本次只审计 `CameraCatalog.profiles` 的 66 个相机身份在
`camera.published-available-defaults.v1` 下是否能由已有公开 Swift
transfer 与色域矩阵组成精确默认计划。相机 ISO、曝光状态和 UI 不在本次范围。

## 契约先行

新增 `CameraCatalogAlgorithmGapContractsTests`，先冻结当前未闭合身份集合，再运行
解析器。测试要求每个未闭合 profile 必须返回
`CameraExposureError.unsupportedDefaults`，不能静默选用名称相近的 transfer、矩阵或
Passthrough。契约集合为 25 项：

- Sony Venice 与 Venice High Base（Venice 专属 S-Gamut3.cine）；
- RED Epic DRAGON（DRAGONColor2）；
- Canon C300、C500（C-Log/C-Log2 的当前公开计划与目录身份不相同）；
- Blackmagic Pocket Cinema 4K/6K 四个 ISO 变体（BMD Pocket Film）；
- Fujifilm F-Log（非 F-Log2）；
- GoPro Protune；
- DJI 4D、Zenmuse X9、Mavic 2、Mini 2、Zenmuse X7/X5S/X3 的 D-Log/D-Log-M/Mini
  变体；
- Nikon D800 Neutral。

## 实际命令与结果

工具链：Xcode 27.0（27A266a），Apple Swift 6.4，arm64 macOS。

```text
swift test --package-path Native/Packages/LUTKit -c release \
  --filter CameraCatalogAlgorithmGapContractsTests/testPublishedDefaultsKeepUnresolvedCameraAlgorithmsBlocked
```

结果：退出码 `0`，定向测试 `1/1`，失败 `0`。同一轮既有相机默认枚举显示
published policy `41` 项可用、`25` 项阻塞；阻塞集合与新增契约完全相等。

## 算法结论

本轮没有可安全新增的最小算法子集。已有 `TransferID` 或矩阵仅能闭合已通过的
profile；例如 `REDLogFilm` 没有 `DRAGONColor2` 色域，`S-Log3` 不能替代 Venice
专属 gamut，`DJI D-Gamut`、Protune Native、Nikon Neutral 和 Pocket Film 也没有
对应的公开连续公式与色域定义。把这些身份映射到相近色域、Passthrough 或旧
LUTCalc legacy 采样会改变算法身份，违反禁止搬表和不得猜公式的约束。

因此没有生产实现、矩阵、网格或阈值改动，也没有独立 Decimal 数值参照可新增；
现有 ISO/曝光 Decimal 参照仍由相机状态契约覆盖。25 项继续明确拒绝，直到取得
公开公式、色域定义和独立逐码参照。

本记录不代表 66 个相机全部转换完成，不关闭 `.labin`、直接查表、完整 ICC/HDR
或 Goal；Goal 保持 `active`。

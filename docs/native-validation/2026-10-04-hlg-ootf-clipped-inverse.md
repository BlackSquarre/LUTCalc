# 2026-10-04 HLG OOTF 峰值裁切逆向边界验收

## 范围

本项只处理现有 `HLGOOTF` RGB 逆函数的定义域边界。正向 OOTF 仍按既有 Double 公式和峰值裁切计算；当任一显示通道已经等于峰值时，输出对应多个场景值，RGB 逆函数无法给出唯一结果，因此必须拒绝该输入。

## 契约先行

先新增 `HLGOOTFContractsTests.testDisplayRGBInverseRejectsPeakClippedNonUniqueValues`。实现前定向测试确认两类失败：单通道峰值裁切和三通道中性峰值均被旧逆函数接受，返回非唯一结果。

## 实现

`HLGOOTF.displayRGBToScene` 在黑位／峰值范围检查后增加严格条件：`r < peak && g < peak && b < peak`。正向 `sceneRGBToDisplay` 的峰值裁切保持不变；全黑显示端点仍按已有契约返回场景黑。没有改变系统 gamma、BBC 系数、网格、插值或任何 HDR/OOTF 参数语义。

## 验证

定向 Debug：

```sh
swift test --package-path Native/Packages/LUTKit \
  --filter HLGOOTFContractsTests/testDisplayRGBInverseRejectsPeakClippedNonUniqueValues
```

结果：退出码 `0`，目标测试通过；其他测试包因过滤器执行 `0` 项属于 SwiftPM 正常输出。

定向 Release：

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  --filter HLGOOTFContractsTests \
  2>&1 | tee /tmp/lutcalc-hlg-ootf-clipped-inverse-release-20261004.log
```

结果：`HLGOOTFContractsTests` 11 项通过、0 失败。日志 SHA-256：`e1a6dc105d3844b5119769be4bbe5ec66c67a8fdec70b7d27ebc79b73fc18542`。工具链为 Xcode 27.0（27A266a）、Swift 6.4。

全量 Release：

```sh
swift test -c release --package-path Native/Packages/LUTKit \
  2>&1 | tee /tmp/lutcalc-hlg-ootf-clipped-inverse-full-release-20261004.log
```

结果：8 个测试包均通过、0 失败；LUTFormats 两项既有外部夹具按原规则跳过。日志 SHA-256：`9a92c3562dcb0f94a1059d45c37190d47e444e84e5704598ecb4d47a4dd5b4a6`。其中 LUTCore 236 项、LUTAnalysis 47 项通过。

## 未覆盖范围

本项只关闭 HLG OOTF RGB 逆函数的峰值裁切非唯一输入边界，不代表完整 HDR/OOTF。自动峰值、参考白／黑位、四种 HDR 变体、PQ OOTF、HDR/EDR 屏幕、完整 ICC、查表替代、LUTAnalyst 全量、UI、真机性能、签名发布和完整清单仍未完成。Goal 保持 `active`。

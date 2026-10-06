# Fujifilm F-Log legacy 计划色域身份验收

## 范围

本次只补充 Fujifilm F-Log legacy 计划的方向和两端色域身份。legacy 公式、冻结 JavaScript 参照、相机路由、量化和 Double 路径未修改。

## 契约与实现

扩展 `FLogContractsTests`，覆盖编码/解码方向以及只改变输入色域时的身份变化；实现将 `analytic-flog-legacy-v1` 改为 `directionalAndSpaces`。

## 验证

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter FLogContractsTests
swift test --package-path Native/Packages/LUTKit -c release --quiet
git diff --check
```

工具链：Apple Swift 6.4、swift-driver 1.168.6、arm64 macOS 27.0.0。

定向 Release 结果：`FLogContractsTests` 5/5 通过，退出码 `0`。

整包 Release 结果：退出码 `0`，日志保存于 `/tmp/lutkit-full-20261006-flog.log`；日志末尾为 `All tests passed`，LUTAnalysis 93/93 通过且无失败项。既有数值报告保持：HLG extended gamma 最大尺度化误差 `4.974256639474225e-16`，HLG extended EOTF 最大尺度化误差 `7.771561172376096e-16`，PQ absolute nits 16-bit 往返最大编码误差 `2.708944180085382e-14`。

差异检查：`git diff --check` 退出码 `0`。

## 未覆盖

本项不代表完整 F-Log/F-Log2 相机范围、F-Log2C 设备语义、厂商 LUT 替代、完整 ICC/HDR、任意三维全根、平台或发布验收完成。

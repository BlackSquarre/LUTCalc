# 2026-10-04 相机默认路由可用性核对

## 范围

本轮只核对已有 66 个相机身份与当前已验收 `TransferID`／`ColorSpaceID` 的默认路由，不新增相机、曲线、色域或设备语义。测试只检查 Swift resolver 是否能构造完整 `TransformSettings`，不把旧元数据当作独立色彩模型。

## 命令与结果

```sh
LUTCALC_CAMERA_ARTIFACT_DIR=docs/native-validation/artifacts/2026-10-04-camera-default-availability \
swift test -c release --package-path Native/Packages/LUTKit \
  --filter 'CameraStateContractsTests/testFrozenLegacyHandlersAndEveryDefaultAvailabilityAndSettingsCopy'
```

工具链为 Xcode 27.0／Swift 6.4，退出码 `0`，定向测试执行 1 项、0 失败。日志 `/tmp/lutcalc-camera-default-availability-20261004.log`，SHA-256：

`afa97b68e4d14cc84830e93f80ff2a83b1b320715dc1320302490df8e8651e41`

实际结果 JSON：[`default-availability.json`](artifacts/2026-10-04-camera-default-availability/default-availability.json)，SHA-256：

`f57e887a751d83f03d39ded9c34c4f10b1e28cbb5e507dc5f8f284cabaaefb19`

| 输入策略 | 可用 | 阻塞 | 总数 |
| --- | ---: | ---: | ---: |
| `camera.legacy-available-defaults.v1` | 34 | 32 | 66 |
| `camera.published-available-defaults.v1` | 41 | 25 | 66 |

## 阻塞分类

- Sony Venice 两个身份使用专用 `Sony S-Gamut3.cine (Venice)`，现有 S-Gamut3.Cine 不能冒充该色域。
- RED Epic DRAGON 需要 DRAGONColor2；当前只有 REDWideGamutRGB 基础矩阵。
- Canon C300 的 CP IDT Daylight 仍依赖 `.labin`；C500 的 C-Log legacy／Cinema Gamut 已有独立证据，但 C-Log 官方路径仍不替换 CP IDT。
- Blackmagic Pocket 的 `Passthrough`、GoPro 的 `Protune Native`、Nikon Neutral 的 `Passthrough` 没有可追溯连续色域定义。
- DJI 4D/X9 的 D-Gamut 路由、DLog-M、Mini 2、X7/X5S/X3 的旧输入分别涉及未闭合色域、查表曲线或 Passthrough 语义。
- Fujifilm F-Log legacy、Canon C-Log legacy 等只在明确的 legacy 策略下可用；不能把兼容路径扩展成官方模型。

## 结论

当前 resolver 已覆盖所有能由已验收公式和色域安全构造的默认组合。本轮没有发现可在不新增来源、不拟合采样表、不猜设备语义的前提下继续接线的路由。上述阻塞继续保留在算法台账；Goal 保持 active。

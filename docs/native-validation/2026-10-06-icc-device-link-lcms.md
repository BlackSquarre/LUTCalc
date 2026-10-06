# LittleCMS device-link 真实参照验收

## 范围

本项使用系统安装的 LittleCMS 2.19 `linkicc` 生成真实 RGB/RGB device-link profile，复核 Swift `ICCDeviceLinkTransform` 对合法 `A2B0` 路由的解析与采样。该 profile 的 `A2B0` 为 LittleCMS 生成的 MPE 管线，不使用仓库内置 LUT、`.labin` 或等价采样表。

## 实际命令与结果

工具链：macOS、LittleCMS 2.19 (`/opt/homebrew/bin/linkicc`)、SwiftPM Release、Apple Swift/XCTest。

```sh
linkicc -o /tmp/lutcalc-link-20261006.icc '*sRGB' '*sRGB'
swift test --package-path Native/Packages/LUTKit -c release --filter ICCDeviceLinkContractsTests
git diff --check
```

生成文件由系统 `file` 识别为 ICC 4.3、RGB/RGB-link device profile，大小 844 字节。`ICCDeviceLinkContractsTests` Release 共 7 项通过、0 失败；其中真实 LittleCMS profile 测试读取 `/tmp/lutcalc-srgb-p3-link-20261005.icc` 时若该历史夹具存在会执行逐点参照，当前新增 profile 的结构复核与 Swift 路由解析同样通过。结果日志 SHA-256：

`3592d1a445d235532b76dfe8246dd4e270b1d26c7f89153df2b2c937b9bedc39`

## 未覆盖范围

本项只证明一个真实 RGB/RGB device-link 的 `A2B0` MPE 路由可以被当前 Swift 实现解析和执行，不代表完整 ICC profile/linking、BPC、gamut mapping、ColorSync 或全部 device-link 色彩空间已经完成。`.labin`、直接查表注册和 LUTAnalyst 全局 3D 反求仍未完成。

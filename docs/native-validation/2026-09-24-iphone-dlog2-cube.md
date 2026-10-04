# iPhone Air 原生 D-Log2 CUBE 阶段验收

日期：2026-09-24。状态：**真机原生界面生成 17³ CUBE、系统分享入口与导出文件全节点数值参照通过；“保存到文件”结果和项目持久化尚未确认。** 本记录只覆盖这一项 D-Log2 → 线性 ACES AP0、曝光 `1.0` 档的具体设置，不能外推为全部 H09/H11/H12 或发布通过。

## 实际设备与操作

工具链 Xcode 27.0（27A266a）、Swift 6.4；设备为 iPhone Air、iOS 27.2（24B5089g），通过已登录团队的开发描述文件签名安装。签名、安装、启动及锁屏首次失败与解锁后成功的详细命令和结果见[真机签名与启动记录](2026-09-24-device-signing.md)。iPhone 镜像中实际打开了本 App 的 `DocumentGroup` 功能草稿界面；曝光显示 `1.0`，输出“线性 ACES AP0”，3D 尺寸显示 `17³`。点击“生成 CUBE”后界面显示“CUBE 已生成，可分享或保存”、`4,913 个节点`；随后系统分享面板显示 CUBE 文件、约 279 KB。点击“保存到‘文件’”后进入文件选择视图，但镜像被手机使用打断，未看到保存确认；App 容器也未找到 `manifest.json`，所以本次不声称项目包或分享文件已持久保存。

生成文件仍位于**本 App 的临时容器**，通过以下只针对 `org.lutcalc.native.dev.ios` 的命令列出并取回，留存为[真机导出证据](artifacts/2026-09-24-iphone-dlog2-ap0-17-exposure1.cube)。该证据是 App 自身生成的测试输出，只存于验证目录，不作为内置 LUT 或应用资源输入。

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl device info files --device 00008150-0012709121D2401C --domain-type appDataContainer --domain-identifier org.lutcalc.native.dev.ios --subdirectory tmp --search .cube
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl device copy from --device 00008150-0012709121D2401C --domain-type appDataContainer --domain-identifier org.lutcalc.native.dev.ios --source tmp/LUTCalc-6CDEB350-4D9A-45F0-84E3-ABAC40734F8D-1A2C82FA-C367-4B3A-B2A0-8449F33265BE.cube --destination /tmp/lutcalc-device-17cube-20260924.cube
python3 tools/native-validation/verify-first-chain-cube.py docs/native-validation/artifacts/2026-09-24-iphone-dlog2-ap0-17-exposure1.cube --expected-size 17
```

## 独立数值结果

证据文件有 `LUT_3D_SIZE 17`、`TITLE "LUTCalc native minimal-dlog2-v1"`，4,913 个有限 RGB 样本。比较器在 App 外部读取导出文本，用研发冻结的 DJI D-Log2 分段式与独立色域矩阵逐节点重新计算（含 `2¹` 曝光）；没有读取 App 的 Swift 函数，也没有用旧引擎作预期。实际退出码 0，结果：最大缩放误差 `3.064215547965432e-14`，RMS `2.308979789801905e-15`，P99 `1.343135364070174e-14`，最差节点 1716、通道 2，固定门槛 `2e-12`。这与界面显示的设置一致，但本次未从已保存的 `.lutcalc` 清单回读设置。

版本 SHA-256：真机 CUBE `251bbd4b8c6eb3337f58547bb2dd9be7245d16dc50f50f6542e962c3f4e9fb5b`；冻结参考 `tests/fixtures/dlog2-reference.json` 为 `1f90b116bdd507f9142547dbb1fdf757fec1e3d2c9e22a77057e08a05eb5ab91`；比较脚本为 `ff54ddff54e876bc846310d3f620ecace5f2b6906242ce76eea3ace1dec23cc8`；界面 `ProjectDocumentView.swift` 为 `14fa4de69ae1b4314ac1db22d41341092456dd5a0ec7bde29b85da7b42a61859`。工程文件版本见签名记录。

未覆盖：真机项目保存/重开、Files 与第三方 File Provider 的文件事务、其他网格和预设、取消/覆盖、系统分享完成后读回、iPad 真机与性能测量。界面仅为用户将单独设计之前的功能草稿。

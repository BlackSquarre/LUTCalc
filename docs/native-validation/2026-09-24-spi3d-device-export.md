# SPI3D 17³ 真机导出验收

日期：2026-09-24。设备：iPhone Air，UDID `00008150-0012709121D2401C`。本记录验证本轮受控 iOS Debug 构建的真机安装、文稿界面生成、App 容器取回和独立数值比对；不代表 FULL-06 完成。

## 构建与界面

从工作区构建 iOS Debug App，派生数据目录为 `/tmp/lutcalc-spi3d-device-derived-20260924`，Xcode 27.0（27A266a），签名团队 `DD4V6SJ9XL`，Bundle ID `org.lutcalc.native.dev.ios`。已安装 App 可执行文件 SHA-256 为 `3bddb64f3b312550aa96f1101123b2689535b65a249099c14e911a5dc082d4de`。App 已在实体设备运行，进程 PID `9448`，界面由 iPhone 镜像实机观察。文稿界面输入为曲线 `dji.dlog2.v1`、色域 `dji.dgamut2.v1`，曝光 `1.0`；输出目标为线性 ACES AP0（当前曲线 `linear.scene.v1`、当前色域 `aces.ap0.v1`），尺寸 17³、格式 SPI3D，输入域为 Data（单位域）。因此逐节点比较使用 DJI D-Log2 解码和冻结 D-Gamut2 到 AP0 矩阵，和真机设置一致。

首次真机文稿生成得到 4,913 节点文件，并从 App 自身容器取回。之后在当前已打开文稿再次点击“生成 SPI3D”，界面显示“LUT 已生成，可分享或保存”，并显示“分享或保存 SPI3D”入口；系统分享面板实际打开，预览为约 315 KB 的 `.spi3d` 文件，可见“保存到‘文件’”动作。锁屏后重新连接镜像，进入“保存到‘文件’”的 Files 保存面板，确认文件名为 `LUTCalc-AED57880-11BA-4EC8-...`，目标位置选择“我的 iPhone”，点击右上角“保存”后返回 LUTCalc 文稿界面；文稿仍显示“LUT 已生成，可分享或保存”，形成保存提交后的应用状态证据。随后再次打开分享面板并进入 Files，在“我的 iPhone”目录加载期间镜像再次中断，未取得取消按钮返回或取消后的应用状态证据；不将目录打开或镜像中断记作取消通过。

## 容器文件与逐节点比较

原始文件从 App 容器 `tmp` 取回至 `/tmp/lutcalc-device-17spi3d-20260924.spi3d`，大小 314,850 字节，SHA-256：

`3be602340ee14790104bfeb3d85a84920d54906b293085908a523eeea64bef2c`

取回文件头为 `SPILUT 1.0`、`3 3`、`17 17 17`；比较器按文件中的显式 RGB 整数坐标建表，确认 4,913 个唯一坐标、无越界/重复/非有限样本。使用冻结 `tests/fixtures/dlog2-reference.json` 的 Double 矩阵及既有独立 DJI D-Log2 解码公式逐节点比较；比较脚本为 `tools/native-validation/verify-first-chain-spi3d.py`，SHA-256：`a130e13c7e33014781dc62a84e343e5abe438b1268061c04a83c1e6b80697d9f`。

关键命令：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl device copy from --device 00008150-0012709121D2401C --domain-type appDataContainer --domain-identifier org.lutcalc.native.dev.ios --source tmp/LUTCalc-0D6A5375-1E8E-4C44-96E0-0933C848D2E5-F7EE00FC-4E23-4A50-A79C-AFF1A63C9ECE.spi3d --destination /tmp/lutcalc-device-17spi3d-20260924.spi3d
python3 tools/native-validation/verify-first-chain-spi3d.py /tmp/lutcalc-device-17spi3d-20260924.spi3d --expected-size 17
```

```json
{"status":"passed","nodes":4913,"maxScaledError":3.064215547965432e-14,"worstCoordinate":[16,15,5],"worstChannel":2,"rmsScaledError":2.308979789801905e-15,"p99ScaledError":1.343135364070174e-14,"threshold":2e-12}
```

## 边界

这项结果只覆盖当前 iOS Debug 真机上一个 17³ D-Log2 到线性 ACES AP0 请求、容器导出文件和冻结参考链；另有一次 Files“保存到文件”提交后返回文稿的 UI 证据。取消后的应用状态、项目包往返、其他尺寸/曲线/色域/格式、外部软件导入及全部真机回归仍未由本记录证明；FULL-06 不勾选。

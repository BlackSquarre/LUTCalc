# H11 F-Log2 C / F-Gamut C 阶段验收

日期：2026-09-26  
范围：富士 F-Log2 C 的官方 F-Gamut C 原色、Double 矩阵推导、目录身份、同色域曝光计划和 CUBE 读回。

## 实现

- `ColorSpaceID.fujifilmFGamutC` 与 `ColorPrimaries.fujifilmFGamutC` 使用富士 F-Log2 C 数据表 section 3 的 D65 原色：R `(0.73470, 0.26530)`、G `(0.02630, 0.97370)`、B `(0.11730, -0.02240)`、White `(0.31270, 0.32900)`。
- 由现有 `ColorPrimaries.rgbToXYZ()` 以 `Double` 解算 RGB→XYZ 矩阵；没有保存采样表或厂商 LUT。独立高精度参照矩阵为：

```text
[ 0.7892749677891813,  0.02004022987995402,  0.14114072938253645 ]
[ 0.28500700824073743, 0.7419456971144954, -0.026952705355232877 ]
[ 0.0,                 0.0,                  1.0890577507598784 ]
```

- F-Log2 C 复用已独立验收的 F-Log2 解析式，但使用独立 F-Gamut C 色域身份；没有把 F-Gamut C、普通 F-Gamut 或 Rec.2020 合并。
- 新增目录预设 `fujifilm.flog2c-exposure-one.v1` 和 CLI 名称 `flog2c-exposure`。

来源：`https://dl.fujifilm-x.com/support/lut/F-Log2C_DataSheet_E_Ver.1.0.pdf`。研究资料同时保存在 `research/colour/2026-09-23/whitepapers/fuji-flog2c-v1.txt`，只用于研发参照，不进入 App 资源。

## 实际测试

```text
swift test --package-path Native/Packages/LUTKit -c release
```

退出码 `0`；最终日志 `/tmp/lutcalc-flog2c-swift-test.log`，SHA-256：`95290442b59ecfc0570fa8a8e3878489c91c4d1eed52133656001ff6ca81a32d`。新增 F-Log2 C 矩阵、跨色域计划和目录契约均通过。

```text
python3 -m unittest tests/native_batch_manifest_test.py
```

退出码 `0`；批量清单扩展为 27 个预设。

```text
swift build --package-path Native/Packages/LUTKit -c release --product LUTReferenceCLI
LUTReferenceCLI --size 33 --output .../flog2c.cube --preset flog2c-exposure
python3 tools/native-validation/verify-flog2-cube.py .../flog2c.cube --size 33
LUTReferenceCLI --size 65 --output .../flog2c65.cube --preset flog2c-exposure
python3 tools/native-validation/verify-flog2-cube.py .../flog2c65.cube --size 65
```

F-Log2 C 同色域曝光 CUBE 独立 80 位 Decimal 读回：

| 网格 | 节点 | 最大尺度化误差 | RMS | P99 | 门槛 |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 33³ | 35,937 | `2.0677889068274172e-16` | `5.0793702028671634e-17` | `2.0677889068274172e-16` | `2e-12` |
| 65³ | 274,625 | `2.0677889068274172e-16` | `4.469139027650494e-17` | `2.0677889068274172e-16` | `2e-12` |

更新后的全批量命令生成并独立读回 27 个预设 × 33³/65³，共 54 个对，全部通过；F-Log2 C 两个对的误差与上表一致。

目录检查实际输出：

```text
APP-03 注册表基础契约通过：44 曲线、14 色域、30 预设、稳定 ID/别名/来源、重复与悬空引用拒绝
```

```text
bash tools/native-validation/verify-native-release.sh
```

工具链：Xcode `27.0 (27A266a)`、Swift 6、macOS 27.0 SDK、iOS/iOS Simulator 27.0 SDK；macOS、iOS Simulator、iOS generic Release 构建均通过，3 个实际 App 包资源审计通过，没有所列 LUT/脚本文件或 WebKit/JavaScriptCore 直接链接。发布脚本最终退出码 `2`，唯一报告为缺少真实全量发布清单 `docs/native-validation/full-scope-acceptance.json`。完整日志 `/tmp/lutcalc-flog2c-native-release.log`，SHA-256：`03e8a7f8bad26719532407a20734c4007bca625b59fdc06b4b43088762e9db2c`。二进制无等价采样表的结论仍需人工复核，静态/资源扫描不构成该证明。

## 未覆盖范围

本阶段只增加 F-Gamut C 色域和 F-Log2 C 配对子集；相机/固件预设、F-Log2 C 的设备范围、完整旧调节链、HDR/EDR、真机运行、Files/File Provider、目标软件往返和完整发布清单仍未完成。F-Gamut C 阶段不代表完整 H11 或全量迁移，Goal 继续保持 active。

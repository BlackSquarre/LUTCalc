# Nikon N-Log 官方与旧兼容算法验收补正

日期：2026-10-04。范围仍是既有 N-Log 传递函数及 Z6/Z7 默认路由。

## 初次记录的补正

初次实现把旧 LUTCalc 的 `650.1864339`、`451.7887494/1023` 和额外 0.9 标度接到 `nikon.nlog.v1`，并把旧公式的 Python 同值结果解释为官方精度。这一解释不成立；本文件已实质性重写。初次 [`artifacts/2026-10-04-nikon-nlog/`](artifacts/2026-10-04-nikon-nlog/) 保留为修正前的历史证据，不能支持最终官方公式、最终代码构建或最终目录计数。

## 最终公式与身份

- `nikon.nlog.v1`：严格采用 Nikon《N-Log Specification Document Version 1.0.0》（2018-09-01）第 2 节。输入/输出线性量是反射率，灰为 0.18；cubic 系数为 650，解码分界为 `452/1023`。不施加额外 0.9 标度。
- `nikon.nlog.lutcalc-legacy.v1`：保留旧 JS 的连续性系数、分界和 legacy 灰 0.2 线性域；进入/离开 `TransformPlan` 时明确转换到场景灰 0.18，且只转换一次。
- Nikon 公开分段式在 0.328 附近本来就不是严格互逆：官方 encode 后 decode 的结果约为 0.32828876825888234。这是规范舍入造成的差异，已保存最小复现，不调整常数、不平滑分界，也不把它计为 Swift 精度误差。
- Z6/Z7 的公开与旧兼容默认分别使用对应身份和 Rec.2020；文档没有扩大到其他 Nikon 机型、显示曲线或 NCP。

原文 PDF：[`nikon-nlog-v1.pdf`](../../research/colour/2026-09-23/whitepapers/nikon-nlog-v1.pdf)，SHA-256 `037f4dbd8bce2e63b17e3400588131e4b3a17c12fe058320b30de17a907715b4`。固定版本 Colour Science 源码和来源清单位于 [`research/colour/2026-10-04/algorithm-sources/`](../../research/colour/2026-10-04/algorithm-sources/)。这些文件仅用于研发，不随 App 分发。

## 当前验收与未覆盖

最终四个相机传递身份的契约、90 位 Decimal、旧 JS 对照、完整三网格、项目磁盘往返、编译及审计集中记录在[相机传递算法验收](2026-10-04-camera-transfer-algorithms.md)，最终命令和结果位于 [`artifacts/2026-10-04-camera-transfer-contracts/`](artifacts/2026-10-04-camera-transfer-contracts/)。

只验收 N-Log 曲线、单位及默认接线；Nikon 显示曲线、NCP 写出、其他相机、真实机型色彩标定、完整 H/FULL 范围和发布仍未完成。Goal 保持 active。

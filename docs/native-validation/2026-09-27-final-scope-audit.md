# 2026-09-27 剩余范围审计

## 已取得的当前证据

- 实体 iPhone 11：CUBE、SPI1D、SPI3D、3DL、ILUT、OLUT、Assimilate `.lut`、VLT 本地“我的 iPhone”保存、App 回调字节回读和独立 Files 列表发现均有独立结果包；3DL、ILUT、OLUT、Assimilate `.lut` 与 VLT 使用 `dji.dlog2-to-dlog2-identity.v1` 合法预设。详见[3DL 本地 Files 往返验收](2026-09-27-iphone11-3dl-files-roundtrip.md)、[ILUT 本地 Files 往返验收](2026-09-27-iphone11-ilut-files-roundtrip.md)、[OLUT 本地 Files 往返验收](2026-09-27-iphone11-olut-files-roundtrip.md)和[Assimilate LUT 本地 Files 往返验收](2026-09-27-iphone11-assimilate-lut-files-roundtrip.md)。
- macOS：新建、编辑曝光 `0.5`、系统保存为 `/tmp/LUTCalc-mac-roundtrip-20260927.lutcalc`、关闭后系统打开面板列出项目包；清单为 schema v2、17³、曝光 `0.5`。Finder 直接双击重新打开本轮 CUA 双击超时，未将其计为新的重开证据；历史重开证据保持独立。
- macOS 复验：Finder 双击在排除并行 Release App 后仍未产生可归因的新文稿窗口；LaunchServices 直接传入同一路径成功恢复文稿并读回曝光 `0.5`、17³ 等字段，但该结果不扩大解释为 Finder 双击证据。详见[macOS 项目直接打开复验](2026-09-27-macos-finder-open-retry.md)。
- 原生 Release 入口 `/tmp/lutcalc-native-release-final-20260927.log`，SHA-256 `058c71d7c4728e3f6316f379b24e7a940d5b8b3dd7ca7b588b236b72e835763d`：Node/Python/Swift/三平台构建/App 资源审计通过，最终退出码 `2`。
- 文件提交协调阶段新增 `NSFileCoordinator` 写协调与跨格式设备/inode/哈希身份检查，本地竞态契约 5 项通过；完整发布入口重跑仍因真实全量清单缺失退出 `2`。该结果不替代 iCloud/File Provider 的真实授权失效、替换竞争或后台恢复验收，详见[文件提交协调与替换竞态阶段验收](2026-09-27-file-coordination-commit.md)。
- 后台恢复阶段已完成 Swift `scenePhase` 取消/恢复实现；后台生命周期契约 4 项通过，全包 Swift Release 测试退出 `0`，macOS、iOS Simulator、generic iOS Release 构建均退出 `0`。实体 iPhone 11 UI runner 两次在启用自动化阶段超时（退出码 `65`），测试方法未执行，因此没有把它计为真机后台恢复通过。详情见[后台恢复阶段验收](2026-09-27-background-recovery.md)。
- 格式 Files 证据阶段已覆盖当前八种可生成格式：CUBE、SPI1D、SPI3D、3DL、ILUT、OLUT、Assimilate `.lut`、VLT。每种格式均有实体 iPhone 11 本地保存、App 回调字节回读和独立 Files 列表发现结果包；全包 Swift Release 测试和三端 Release 构建再次通过。该汇总不替代第三方软件往返、Files 再导入、File Provider/iCloud 或完整发布验收。

## 仍未完成且不能伪造的项目

1. `docs/native-validation/full-scope-acceptance.json` 真实全量验收清单缺失；发布入口因此失败。
2. iPadOS 模拟器多窗口、旋转和键盘/VoiceOver 全项证据；已用 `xcrun simctl --set /tmp/LUTCalcCoreSimulatorDevices-20260927b` 创建并启动 iPad Air 11-inch M3（UDID `CD363B59-923B-471D-B47F-64792492CE9C`），取得原生首屏和 `accessibility-large` 截图，并通过 `simctl openurl` 冷启动打开两份不同项目身份、核对 D-Log2、D-Gamut2、曝光 `0.5`、Data、10 位字段；但 Xcode 27 destination 服务未发现独立设备集，无法产生旋转、多窗口和完整无障碍 UI Test 结果包。详情见[iPadOS 模拟器验收重试](2026-09-27-ipados-simulator-validation-retry.md)和[iPadOS 模拟器文稿 URL 打开验收](2026-09-27-ipados-document-open.md)。
3. iCloud/File Provider 授权失效、外部替换竞争、真实设备后台终止后恢复和磁盘故障场景；本地 `NSFileCoordinator` 与 Swift 生命周期契约不替代这些证据。
4. 各格式第三方调色软件导入及 Resolve/Panasonic 等目标软件往返。
5. 完整 ICC `mft/mAB/mBA`、HDR/EDR/OOTF、真实显示色彩管理；2026-09-27 已新增用户导入三通道 `mft1/mft2/mAB/mBA` 的 Swift `Double` CPU 子集，但不替代完整 ICC 验收。详见 `2026-09-27-icc-mab-mft-transform.md`。
6. 任意 3D LUT 反求和完整 LUTAnalyst；现有实现按研究边界明确拒绝推断。
7. 发布签名、性能预算和最终视觉设计验收。

这些项目需要相应真实设备、目标软件、公开资料或用户设计决定；当前没有证据支持把 Goal 标记完成。

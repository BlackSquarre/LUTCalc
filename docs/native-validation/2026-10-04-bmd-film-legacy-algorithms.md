# Blackmagic Film legacy 家族算法验收

日期：2026-10-04

## 范围

本包闭合旧 `js/gamma.js` 中三个已有 `LUTGammaLog` 注册项：`BMD Film`、`BMD Film4k`、`BMD Film4.6k`。每条曲线保存独立 `TransferID`、旧九参数和 legacy-grey `0.2` 域语义；没有把它们合并成 Gen5 或 Pocket Film，也没有为缺少公开色域资料的条目新增 Blackmagic 相机色域。

## 证据

- JavaScript 参照由 `tools/native-validation/generate-bmd-film-reference.js` 直接执行旧注册表，源码 SHA-256 为 `250017d8efe758f3555148ba9fcb923698add0ac7d9380fa290716eb98e0821e`。
- `BMDLegacyFilmContractsTests` 3 项通过，覆盖三条曲线逐点参照、分支边界、非有限值、计划一次性缩放、目录身份和 normalized data 分类。
- `LUTCatalogChecks` 通过：69 曲线、20 色域、65 预设、66 相机。
- Swift Release 全量实际执行 717 项，0 失败；LUTFormats 的 2 个既有外部夹具按原设计跳过。
- Release `LUTReferenceCLI` 生成三条曲线各 17³、33³、65³ CUBE。独立 90 位 Decimal 逐节点读回，阈值 `3e-15` 内全部通过：
  - BMD Film 最大 `1.4177274504367327e-16`；
  - BMD Film4k 最大 `2.2304358216004653e-16`；
  - BMD Film4.6k 最大 `1.3153340910382913e-16`。
- macOS、generic iOS、generic iOS Simulator Release 构建通过。162 个 Swift 源文件静态边界审计和三个实际 App 包资源审计通过。

命令、参照、CUBE、全量日志和审计结果保存在[结果包](artifacts/2026-10-04-bmd-film-legacy-contracts/)。

## 未覆盖

本包只关闭三条 BMD Film legacy 标量和同空间曝光预设；Blackmagic 真实色域、相机默认路由、Gen5/Pocket 完整设备语义、DJI 查表、其余查表注册项、`.labin`、HDR/OOTF、ICC、LUTAnalyst、格式互操作、真机性能和发布验收仍未完成。Goal 保持 active。

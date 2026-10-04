# 2026-09-27 macOS 系统文稿保存与关闭验收

## 实际操作

使用重新构建的 `/tmp/LUTCalcMacFinderDD/Build/Products/Debug/LUTCalcMac.app`，通过 macOS 系统文稿界面新建项目，将“曝光档数”从 `1.0` 改为 `0.5`，执行“应用曝光”，按 `⌘S` 打开系统保存面板，保存为 `/tmp/LUTCalc-mac-roundtrip-20260927.lutcalc`，随后按 `⌘W` 关闭文稿。

关闭后系统打开面板实际列出该项目包，类型显示为 `LUTCalc Project`。磁盘包包含 `manifest.json`，SHA-256 为 `d3d98f2f814179872fcf1efc35b185c1e2f64c637ed5b258959f3d4d8a29d8d4`；清单读取结果为 `schemaVersion=2`、`cubeSize=17`、`exposureStops=0.5`。

## 构建

命令：`xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcMac -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/LUTCalcMacFinderDD CODE_SIGNING_ALLOWED=NO build`，退出码 `0`。构建日志 SHA-256：`612d7cf2a9fa7654dca3ee9b110a6c14a1fdf03707816ff7bd45d16737add333`。

## 未覆盖

本轮证明 macOS 新建、编辑、系统保存、关闭及项目包列出；没有把“打开面板列出”扩大为本轮重新打开后界面字段读回。历史 macOS 重开证据另见 `2026-09-24-mac-project-ui-roundtrip.md`。Finder 直接双击路径、外部替换竞争、iCloud/File Provider 和多窗口仍未完成。

## 项目类型与清单复核补记

- `/tmp/LUTCalc-mac-roundtrip-20260927.lutcalc` 的 `manifest.json` SHA-256 仍为 `d3d98f2f814179872fcf1efc35b185c1e2f64c637ed5b258959f3d4d8a29d8d4`；读取到 `schemaVersion=2`、`cubeSize=17`、`exposureStops=0.5`、输入 `dji.dlog2.v1/dji.dgamut2.v1`、输出 `linear.scene.v1/aces.ap0.v1`。
- `mdls` 对项目包返回 `kMDItemContentType=org.lutcalc.project`、`kMDItemKind=LUTCalc Project`；Debug App 的 `CFBundleDocumentTypes` 声明 `org.lutcalc.project` 且 `LSTypeIsPackage=true`。
- 本补记只证明 UTI 和磁盘字段一致；Finder 直接双击后重新打开并核对界面字段仍没有新的正证据。

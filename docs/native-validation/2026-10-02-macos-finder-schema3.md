# 2026-10-02 macOS Finder 直接重开 schema 3 项目

## 验收契约与范围

本包接续 [10 月 1 日文稿关联复核](2026-10-01-macos-finder-association.md)。先前系统未设定默认打开应用，显式选择临时 Debug App 能打开，但不能算 Finder 直接双击通过。本轮契约为：用当前原生 Release App 的系统文稿界面新建项目，修改曝光与尺寸，系统保存，关闭文稿并退出进程；随后在 Finder 对保存的项目直接双击，核对实际启动路径、文稿 URL、界面字段和磁盘 manifest。

沿用已通过的 schema 3 文稿存储／重开契约和 368 项 Release 回归，见[用户 LUT 后置阶段验收](2026-10-02-user-lut-post-stage.md)。本轮没有源码修改，不重复把包内 FileWrapper 测试当成桌面证据，也没有新增 XCTest 结果包。

## 环境与安装

- macOS 27.0（26A428），arm64；Xcode 27.0（27A266a），Apple Swift 6.4。
- 当前已构建 Release：`/tmp/LUTCalcPostStageMacOct2DD/Build/Products/Release/LUTCalcMac.app`。构建命令和日志在前述后置阶段验收中，本轮未重新构建。
- 退出仅有系统打开面板的旧验证 Debug App 后，用以下实际命令独立复制当前原生包：

```sh
test ! -e /Users/lingru/Applications/LUTCalcNativeValidation-Oct2.app && ditto /tmp/LUTCalcPostStageMacOct2DD/Build/Products/Release/LUTCalcMac.app /Users/lingru/Applications/LUTCalcNativeValidation-Oct2.app
mkdir -p /tmp/LUTCalcFinderValidation-20261002 docs/native-validation/artifacts/2026-10-02-finder-schema3
```

命令退出 `0`。源包与复制包的 `Contents/MacOS/LUTCalcMac` SHA-256 同为 `d6fd1e5b9b3d27597f336669ff315560c77388f0f290430568c0df91a6b8acec`，bundle ID 为 `org.lutcalc.native.dev.mac`。没有覆盖 `/Applications/LUTCalc.app` 旧厂商 App，没有手动设置默认应用或执行“全部更改”。这里只证实此主机正常应用目录安装及启动后的实际关联行为，不推断全部干净系统的默认关联。

## 实际桌面操作

桌面操作全部通过 CUA 的真实原生界面。

1. 从复制包启动，系统打开面板点击“新建文稿”。默认 D-Log2／D-Gamut2→Linear scene／ACES AP0，曝光 `1.0`，17³。
2. 将曝光改为 `0.75` 并点击“应用曝光”，尺寸改为 `33³`。用系统保存面板保存至 `/tmp/LUTCalcFinderValidation-20261002/Finder-schema3-Oct2.lutcalc`。
3. 保存面板初次自动化点击与焦点未按预期落在文件名，曾把名称文本写入未提交的曝光草稿；立即恢复 `0.75` 并提交，再重新打开保存面板。紧凑面板曾显示保存禁用，展开后启用并完成保存。最终窗口、磁盘字段及重开值均核对通过；不把前面的尝试计为成功。
4. 保存后的窗口 URL 指向该项目包，曝光 `0.75`、尺寸 `33³`。关闭文稿并退出 App，`pgrep -fl '/Users/lingru/Applications/LUTCalcNativeValidation-Oct2'` 无匹配，确认冷启动前进程已不存在。
5. Finder 前往专用目录，在实际列表中对 `Finder-schema3-Oct2.lutcalc` 双击。首次因保存无障碍树后索引重置，点击返回无效索引，没有执行打开；刷新索引后对实际文件元素执行双击。
6. 双击后 `pgrep` 返回 PID `38837`，可执行路径为独立安装的原生包。读取该 App 时已经存在正确文稿窗口，窗口 URL 为上述项目包。没有使用 `open -a`、命令传入文稿路径或“选取应用程序”促成此次打开。
7. 保存重开截图与完整无障碍字段，随后关闭文稿并退出。准备第二次冷启动时，Finder 当前窗口已切换到其他内容，因此未完成第二次双击；只计本次已观察的一次冷启动通过。

## 字段与文件核对

| 字段 | 系统保存后／Finder 重开后 |
| --- | --- |
| 项目名／URL | `Finder-schema3-Oct2.lutcalc`，同一 `/private/tmp/LUTCalcFinderValidation-20261002/` 路径 |
| schema | 磁盘 `schemaVersion: 3` |
| 输入 | D-Log2、D-Gamut2、Data |
| 曝光 | `0.75` |
| 位深 | 10 位 |
| 输出 | Linear scene、ACES AP0、Data；目标“线性 ACES AP0” |
| 网格 | `33³`，磁盘 `cubeSize: 33` |
| 导出界面 | CUBE（界面会话选项；不声称项目持久化了格式） |
| 原始资源 | 本次无用户资源，`assetHashes`、`assetRoles` 均为空 |

项目 UUID 为 `F4A414D6-22AB-47F7-86A9-D7E5761AB3EC`。保存及关闭／重开后的 `manifest.json` SHA-256 均为 `be953319f8cef597ebc904f832b923281db74cc1fe386e4d14d0585a0a3d0902`；证据副本与实际文件逐字节相等。`mdls` 返回 `org.lutcalc.project`、`LUTCalc Project`。

## 证据与判定

[证据目录](artifacts/2026-10-02-finder-schema3/) 包含系统保存与 Finder 重开的截图、完整 App 无障碍树、Finder 双击前后树、本次实际系统保存项目包、环境命令输出、字段检查及 `sha256.txt`。

- `reopened-first.ax.txt` SHA-256：`2f99a661ef85381297c25198d68018378850c859f6053c961c852366869daed6`。
- `reopened-first.png` SHA-256：`b491f11cfda9ecc9227bbb7ce1ebac71f03c69d1f6d8c5264ae0b3ef2ff3004a`。

**本主机、当前独立安装 Release 包、此次系统保存项目的 Finder 直接双击冷启动与字段恢复通过。** 这补足 H12/FLOW-04 中该本地桌面操作的正证据，不能勾选完整 H12 或 FLOW-04。没有数值算法改动或新的误差测量；没有降低既有阈值。

仍未覆盖新系统安装、签名／公证／分发、登录或重启后的关联、第二次冷启动、多文稿竞争、用户资源后置配置的桌面重开、iCloud/File Provider 授权撤销及替换竞争、后台恢复、iPad 多窗口／旋转／无障碍，以及第三方调色软件往返。完整 ICC、HDR/EDR/OOTF、LUTAnalyst、旧功能、性能预算与完整发布逐项验收仍未完成。本轮没有创建 `full-scope-acceptance.json`，Goal 保持 **active**。

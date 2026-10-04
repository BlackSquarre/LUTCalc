# H07 用户 LUT 只读导入格式接线阶段验收

日期：2026-09-25。范围：在既有用户主动选取、后台 security scope、只读解析和 Double 取样会话上，批量接入已有纯 Swift 解析器的 Flame `.3dl`、Resolve `.ilut`、Panasonic `.vlt` 格式子集。

## 契约先行与实现

先在 `UserLUTImportContractsTests` 增加三种临时文件的真实 URL 读取、格式身份、1D/3D 维度、尺寸和固定端点取样契约。首次 Release 定向编译因 `UserLUTFormat` 缺少 `threeDL`、`ilut`、`vlt` 三项失败；随后在 `NativeUserLUTLoader` 按扩展名复用现有解析器，并在 `ProjectDocumentView` 的系统文件选择器列出三种扩展名。没有新增内置 LUT 或等价采样表，也没有改动插值、解析算法或导出路径。

契约输入：Flame 2³、ILUT 16,384 点、VLT 17³ 临时文件；固定端点 `(1,0,0)` 的只读取样结果均为 `(1,0,0)`。文件由测试运行时写入临时目录，不进入 App 包。三种格式此前各自的格式契约继续由原有测试覆盖；本段只证明用户导入接线。

## 验证结果

- 定向 Release `UserLUTImportContractsTests` 3 项通过；失败阶段日志 `/tmp/lutcalc-h07-expanded-import-red.log`，SHA-256 `7652d5e081b69d556b4d0793cc60d6f721ce25818e8ea5eef61fd9a94092716b`；通过阶段日志 `/tmp/lutcalc-h07-expanded-import-green.log`，SHA-256 `8db14e58c10056056db5a76264c793cb941a1a457ad5591a68e066a53373479d`。
- 完整 Release 入口：Swift XCTest 8 个目标合计 180 项、0 失败；6 个公式契约及 36 对 33³/65³ CUBE 批量生成、独立读回通过；macOS、iOS Simulator、iOS generic 三平台构建成功，3 个实际 App 包资源审计通过。
- 完整日志 `/tmp/lutcalc-h07-expanded-import-release.log`，SHA-256 `074bb6993264852d5306aef93aec722d6e76377fc2b777f651ba3e56dcc952c0`。发布入口最终退出码 2，原因仍为缺少真实 `docs/native-validation/full-scope-acceptance.json`，未伪造清单。

这仍是 H07/FULL-05 的格式接线子集。Files/File Provider 的实体 iPhone/iPadOS 选中、授权读取、取样结果，用户 LUT 项目资产持久化、完整 LUTAnalyst 和外部目标软件兼容尚未验收；按用户安排，连接不稳的真机流程最后集中完成。

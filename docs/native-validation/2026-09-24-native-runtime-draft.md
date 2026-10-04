# 双端原生功能草稿首次运行记录

日期：2026-09-24。工具链为 Xcode 27.0、iOS 27.0 模拟器及 macOS 主机。本记录只确认首次启动与当前草稿界面的可见行为，不宣称完整 H09、H13 或真机验收。

## iPhone 与 iPadOS 模拟器

使用 XcodeBuildMCP 的 `session_show_defaults`、`list_sims`、`session_set_defaults`、`build_run_sim`、`snapshot_ui`、`screenshot` 依次检查。工程为 `Native/LUTCalc.xcodeproj`、scheme `LUTCalcIOS`、Release，构建参数 `CODE_SIGNING_ALLOWED=NO`。

| 设备 | UDID | 实际结果 | 截图 |
| --- | --- | --- | --- |
| iPhone 17 Pro / iOS 27.0 | `74D92E05-FFB1-4EDA-8EBC-3C268F9A63EA` | 构建、安装、启动成功，进程 ID `15917`；AX 能读取“创建文稿”，截图显示系统文档浏览器与“无最近项目” | [iPhone 截图](evidence/2026-09-24-iphone17pro-document-browser.jpg)，SHA-256 `e2b0b149fac8706fe63d60e2e877a39b51826583aad3954815b31b5626ca85f0` |
| iPad Pro 13 英寸（M5）/ iPadOS 27.0 | `05B6D82F-0939-4F0F-BAA8-838F0B851579` | 构建、安装、启动成功，进程 ID `17892`；AX 能读取“创建文稿”，截图显示系统文档浏览器与“无最近项目” | [iPad 截图](evidence/2026-09-24-ipadpro13-document-browser.jpg)，SHA-256 `1a55e6f932fcf0306d0cb8fed24f895ac0d226aa3d3069f6e39ed6bdf6469ab0` |

两端都尝试通过 XcodeBuildMCP 的 `tap(elementRef: "e21")` 点击“创建文稿”，工具返回点击成功，但后续 `snapshot_ui` 仍显示同一浏览器界面；尚不能据此判断是按钮、系统文档浏览器还是自动化坐标映射问题。**创建、保存、重开及分享未通过实际 iOS/iPadOS 交互验收。** 运行日志未发现本应用抛出的异常；仅有模拟器运行时的系统类重复警告。模拟器安装/启动不等于真机验证。

## macOS 草稿

通过已构建的 `LUTCalcMac.app` 启动，系统首先显示“打开”面板；点击“新建文稿”后出现原生项目窗口。窗口实际显示 D-Log2 / D-Gamut2 输入、Data 范围、曝光 `1.0`、线性 ACES AP0 输出和 `17³` 网格。点击“生成 CUBE”后界面显示“CUBE 已生成，可分享或保存”与“4,913 个节点”；点击“分享或保存 CUBE”后出现系统分享面板。这里确认的是界面内生成及分享面板出现，**未从系统面板保存并读回文件**。相同 17³ 算法路径此前已有包级独立读回验收，不能代替本次未完成的 UI 文件事务。

## 状态边界

代码存在、Release 构建成功、模拟器启动、实际文档编辑/导出、真机验证和发布就绪分别判断。当前 UI 只作为功能草稿，视觉与完整交互由用户后续单独设计；尚未验证 iOS/iPadOS 文档创建、项目保存、Files/File Provider 授权、用户 LUT 导入、图像取样、整图预览或目标软件 CUBE 导入。保持 H09、FLOW-03/04/06 与 QA-02 未完成。

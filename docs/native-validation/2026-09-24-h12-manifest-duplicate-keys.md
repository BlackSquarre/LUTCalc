# H12 原生项目清单重复字段拒绝阶段验收

日期：2026-09-24。状态：**项目清单现拒绝 JSON 对象内的重复键；旧设置迁移仍未开放。** 本项保护新原生项目包读取，不改变清单 schema、Double 编码或旧文件。

## 契约与实现

先在 `ProjectContractsTests` 增加三种拒绝情形：顶层 `schemaVersion` 重复、以 Unicode 转义写出的 `cubeSize` 重复、`settings.exposureStops` 重复。首轮契约因 `ProjectError.duplicateKey` 尚不存在而编译失败，确认缺口暴露。

随后将 H12 旧设置检查器中的纯 Swift JSON 键扫描器改为模块内可复用。`ProjectCodec.decode` 在 `JSONSerialization` 及 `JSONDecoder` 解码前执行扫描，任何层级的重复字段都按解码后的键名识别；重复键映射为带字段路径的 `ProjectError.duplicateKey`，其他扫描失败映射为 `malformed`。Unicode 转义键与普通键同名时同样拒绝。

## 实际验证

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test -c release --package-path Native/Packages/LUTKit --filter ProjectContractsTests
  退出码 0；4 项通过，0 失败。重复键契约通过；Double 精确往返、符号零撤销/重做和 Bradford 保存契约仍通过。

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test -c release --package-path Native/Packages/LUTKit --filter LegacySettingsContractsTests
  退出码 0；2 项通过，0 失败。旧设置 JSON 的 Unicode 转义重复键拒绝和不同对象同名键仍通过。
```

源码及契约 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `Native/Packages/LUTKit/Sources/LUTProject/ProjectManifest.swift` | `b74021ea6afceff91fb09743b232fb6262034b820bf61ae6b1de8ffea63bc745` |
| `Native/Packages/LUTKit/Sources/LUTProject/LegacySettingsInspector.swift` | `a39274d63fbc7d43d6d66604a2385569e7166fbdef36e21c19cc4db66d353d5a` |
| `Native/Packages/LUTKit/Tests/LUTProjectTests/ProjectContractsTests.swift` | `203d48293861724056aa593dad7d64f6d0c9c1bb3f7d751ca3025f95965b8031` |

本项不涉及图像像素或色彩算法，没有新增数值误差结果。完整工作区 Release 入口本次曾与并行添加的 3DL 红灯契约相遇，编译期找不到尚在开发的 `ThreeDLParser`/`ThreeDLFailure`，因此该次入口未完成三平台构建和证据检查；这不是本项契约失败。待 3DL 契约对应实现稳定后重跑完整入口，记录最终退出码。实体 iPhone Air 的状态另行跟踪；此项无真机验收。

项目包解析的重复键缺口已补，H12/FULL-08 仍因旧设置字段映射、未知字段处置、版本迁移以及 Files/File Provider 交互未完成而不勾选。不得据此创建全量发布验收清单。

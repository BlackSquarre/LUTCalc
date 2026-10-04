# SPI3D 真机状态复核（续接）

日期：2026-09-24。范围：按照原生迁移交接顺序，复核当前物理 iPhone 是否可用于最新版 `.spi3d` 17³ 导出闭环。本记录只记录设备状态，不修改路线图、不修改源码、不清理已有文件。

## 规则与验收边界

已先读取根目录 `AGENTS.md`、根目录 `codex.md`（不存在）以及[原生迁移交接入口](../native-swift-handoff.md)、[原生迁移续接记录](2026-09-24-native-continuation-handoff.md)、[SPI3D 流式导出阶段验收](2026-09-24-spi3d-stream-export.md)。交接要求是：若 iPhone Air 恢复可用，构建并安装当前版本，在真机草稿中生成 17³ `.spi3d`，只从本 App 容器取回自身文件，按显式坐标和冻结 D-Log2 参照逐节点比较，并记录系统分享/取消结果；模拟器不能代替真机证据。

旧续接记录的 `ProjectDocumentView.swift` 基准 SHA-256 为 `41ac9ad343626cd5e0b8581535428147e00e03cc63831996388ca34ffd8f8c1c`；本次读取当前工作区所得 SHA-256 为 `16949a378345325ae237d0f850c5596f369aefb5765c4f32a97bdc3d6dd83ef2`。因此，旧记录中的源码版本不能直接视作当前工作区版本，本次未对当前源码执行新的构建或数值验证。

## 实际设备状态

执行：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl list devices
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcdevice list --timeout 10
```

`devicectl list devices` 退出码为 0，但三台物理设备均为 `unavailable`：

| 设备 | 标识 | 状态 | Reality |
| --- | --- | --- | --- |
| iPhone Air | `00008150-0012709121D2401C` | `unavailable` | `physical` |
| iPhone SE | `00008030-000E59A90223802E` | `unavailable` | `physical` |
| iPhone SE 3 | `00008110-000670A83482401E` | `unavailable` | `physical` |

`xcdevice` 对 iPhone Air 返回 `available: false`、错误码 `-27`，描述为正在通过局域网浏览设备，恢复建议为确保设备已解锁并通过线缆连接或与本机处于同一局域网；无线连接还要求设备开启开发者模式。两台备用物理 iPhone 也返回同样的 `-27` 不可用状态。

同名 iPhone Air 模拟器 `E371A154-E717-4E80-864D-6BD16E0BCA52` 为 `connected`/`simulated`，不计入真机验收。

## 本次未执行的真机步骤

由于目标设备不可用，没有执行当前 SPI3D 版本的真机构建、安装、启动交互、17³ 生成、App 容器取回、系统“保存到文件”/分享、取消路径或逐节点独立比较。没有产生可宣称为真机结果的 `.spi3d` 文件，也没有用模拟器或包级生成结果替代真机证据。

旧版本的包级 SPI3D 17³ 生成与读回、Swift 契约和三平台 Release 构建以[流式导出阶段验收](2026-09-24-spi3d-stream-export.md)中的对应源码证据为准；此前 iPhone Air 的 17³ D-Log2 CUBE 逐节点结果也只适用于旧版本 CUBE，不外推到当前工作区 SPI3D。

## 结论

截至本次复核，最新版 SPI3D 真机闭环仍为“未验证”，阻塞原因是物理设备连接状态，不是本次新增源码或签名诊断。待 iPhone Air 恢复为可用后，按交接记录优先完成构建/安装、容器取回和逐节点比较；在此之前不勾选真机相关验收项。

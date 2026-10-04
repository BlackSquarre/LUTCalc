# 物理设备状态复核

日期：2026-09-24。本轮在格式工作继续期间执行 `xcrun devicectl list devices`，退出码 0。物理 iPhone Air `00008150-0012709121D2401C` 状态为 `unavailable`；物理 iPhone SE 与 iPhone SE 3 也均为 `unavailable`。同名 iPhone Air 模拟器显示 `connected`，其 Reality 为 `simulated`，不能充当真机证据。

因此，最新版 SPI3D 的物理设备生成、从 App 容器取回及独立逐节点比较未执行；物理设备的 `.3dl`、`.ilut`、`.olut` 导出也未取得结果。此前 iPhone Air 的 CUBE 证据只适用于对应旧版本。待物理设备恢复后优先按续接记录完成 SPI3D 真机闭环。

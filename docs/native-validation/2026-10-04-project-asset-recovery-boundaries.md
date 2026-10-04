# 项目资产恢复授权根边界验收

## 范围

本工作包只处理项目外部用户资产的本地恢复边界，不涉及 UI、iCloud、File Provider 或真机后台恢复。恢复仍以用户主动授权的目录和已保存 SHA-256 为依据；本轮禁止通过目录符号链接把搜索范围带出授权根。

## 契约先行

先在 `ProjectAssetDiscoveryContractsTests.swift` 增加目录符号链接夹具，再用旧实现运行：`testAncestor...` 试验确认旧实现会沿授权根中的链接找到根外文件，退出码为 `1`。最终保留的契约覆盖：

- 根本身不是目录或是符号链接时返回 `invalidRoot`；
- 候选符号链接不作为 regular file；
- 授权根下的符号链接目录不会被遍历到根外；
- 仍保留按 SHA-256 重发现、原文件名消歧、重复路径、缺失和歧义错误。

旧实现先行失败日志见 `artifacts/2026-10-04-project-asset-recovery/contract-red.log`。

## 实现

`ProjectAssetDiscovery.rediscover` 在接受候选文件前，除了检查最终 URL 外，还检查候选相对于已验证授权根的每个路径组件；任一路径组件是符号链接时跳过该候选。根的校验仍只确认调用方传入的最终 URL 是目录且不是符号链接。这样不会把系统路径中常见的兼容性链接（例如 `/var`）误报为授权错误，同时阻止授权根内部的链接逃逸。

未引入 LUT、采样表、JavaScriptCore、WebView 或新的数值路径，也没有改变 Double、网格、位宽、插值和阈值。

## 实际验证

命令和逐项退出码保存在 `artifacts/2026-10-04-project-asset-recovery/commands.txt` 及同目录 `.exit` 文件。

- Debug 定向：7 项通过，0 失败；
- Release 定向：7 项通过，0 失败；
- Swift Release 全量：8 个测试包共 680 项，0 失败；LUTFormats 的既有外部夹具共跳过 2 项；
- macOS Release generic 构建：退出码 0；
- iOS Release generic 签名构建：退出码 0，使用本机 Apple Development 配置；
- 原生源码审计：153 个 Swift 源文件通过；
- 实际 macOS 与 iOS App 包审计：2 个包通过，无所列查找资产、脚本运行时或 WebKit/JavaScriptCore 直接链接。
- 发布证据结构检查仍退出码 2，原因只有缺少真实 `docs/native-validation/full-scope-acceptance.json`；本轮没有创建或伪造该清单。

结果日志、构建产物路径和审计输出见 `artifacts/2026-10-04-project-asset-recovery/`。

## 未覆盖范围

本轮不能证明祖先目录在授权后被协作替换时的身份保护、哈希读取到最终替换之间的非协作窗口、磁盘故障、真实 iCloud/File Provider 撤权和跨进程 provider 语义，也没有关闭 iPhone 11 后台终止恢复。实体 iPhone 11 本轮重试仍由 `devicectl` 报 `unavailable`，没有生成新的真机性能 JSON；没有使用 iPhone Air、镜像或模拟器替代证据。H/FULL 和 Goal 继续保持未完成。

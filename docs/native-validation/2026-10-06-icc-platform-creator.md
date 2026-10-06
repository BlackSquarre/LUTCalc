# ICC 头部 platform 与 creator 字段边界验收

## 范围

本项只审计 ICC profile header 的 platform（偏移 40，4 字节）与 creator（偏移 80，4 字节）字段。两者按 ICC 头部签名字段处理：全零表示未知并保持兼容；非零值必须是合法 ASCII 四字符签名。该项不推断厂商语义，也不参与颜色计算。

## 契约与实现

先加入失败契约：platform 或 creator 含不可接受字节时必须分别返回 `invalidPlatformSignature` 或 `invalidCreatorSignature`。随后在 `ICCProfileValidator` 中解析并返回可选 `platformSignature`、`creatorSignature`；合法签名保持原文，零值返回 `nil`。

## 实际命令与结果

- 工具链：Xcode SwiftPM，macOS arm64，Swift 6。
- Debug：`swift test --package-path Native/Packages/LUTKit -c debug --filter PreviewContractsTests.testICCProfile`，31 项通过，0 失败。
- Release：本轮构建受共享 SwiftPM 并发占用影响，未取得完整退出结果；主代理必须在无并发后重新执行同一 filter 并保存输出，才能补齐 Release 证据。
- `git diff --check`：通过。

## 未覆盖范围

本项不验证 platform/creator 的厂商枚举、manufacturer/model 字段、ColorSync 行为、真实第三方 profile 逐码参照或完整 ICC 语义。Goal 继续 `active`。

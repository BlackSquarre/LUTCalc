# ICC 可打印签名字节范围验收

## 范围

ICC signature 是固定四字节字段；其字符集合覆盖可打印 ASCII（`0x20...0x7E`），包括标点。旧校验仅接受空格、字母和数字，会误拒合法的私有或未来 tag signature。本项只修正 signature 字节域，不推断未知 tag 的语义，也不扩展颜色变换范围。

## 契约与修复

新增 `PreviewContractsTests.testICCProfileAcceptsPrintableASCIITagSignatures`，用 `!@#$` 作为目录 signature，并验证验证器保留原签名且照常验证其 `text` payload。暂时恢复旧谓词后，Debug 测试以 `.invalidTagTable` 失败，确认旧实现拒绝该合法四字节字段。随后 `validSignature` 改为恰好四个 UTF-8 字节且每个 Unicode scalar 位于可打印 ASCII 范围。

## 命令与结果

- 红灯：`swift test --package-path Native/Packages/LUTKit -c debug --filter PreviewContractsTests.testICCProfileAcceptsPrintableASCIITagSignatures`，1 项失败，错误为 `invalidTagTable`。
- 修复后 Debug：同一命令，1 项通过。
- 修复后 Release 单项：`swift test --package-path Native/Packages/LUTKit -c release --filter PreviewContractsTests.testICCProfileAcceptsPrintableASCIITagSignatures`，1 项通过。
- Release 回归：`swift test --package-path Native/Packages/LUTKit -c release --filter PreviewContractsTests`，`PreviewContractsTests` 43 项通过，LUTPreviewTests 共 44 项通过，0 失败。
- `git diff --check`：通过。

## 未覆盖范围

未知 tag 的完整 ICC 类型语义、真实第三方 profile 逐码参照、BPC、gamut mapping、ColorSync、HDR/EDR/OOTF 仍未完成。本项只关闭四字节 signature 的可打印 ASCII 字域边界；Goal 保持 `active`。

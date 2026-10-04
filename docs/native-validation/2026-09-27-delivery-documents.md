# 原生交付文档阶段验收

日期：2026-09-27。

## 新增文档

- `docs/native-swift-user-guide.md`：当前原生预览版的使用范围、验证入口和使用边界。
- `docs/native-swift-precision-report.md`：Double 生成路径、独立参照、误差门槛和限制。
- `docs/native-swift-coverage-report.md`：已实现子集、证据来源和未覆盖功能。
- `docs/native-swift-blockers.md`：研究阻塞、外部平台阻塞和处理原则。

## 真实性检查

文档只引用当前工作区已有的验收记录和实际验证入口，没有把阶段性子集标为完整迁移，也没有创建 `full-scope-acceptance.json`。`git diff --check` 通过。

文件 SHA-256：

```text
ce08dc83a389bb6beb2fbbc26b942eae8f0c03777245b820125cdd13b9661756  docs/native-swift-user-guide.md
d817808990c24b477df3c4ab07c0905e47295f8ee6bd52845e827d247446ba09  docs/native-swift-precision-report.md
67ee844ea65e1dd3be893520b01eb0f6ad0e2e29bf44539bf536337f2ac31d31  docs/native-swift-coverage-report.md
e8b2e183f7c5d457f84c619d11440bccdab56f4bdb2dde1702c7803df441c6e1  docs/native-swift-blockers.md
```

## 未完成

这些文档完成了交付说明的一部分，不等于 REL-03/REL-04 或全量发布验收完成；完整功能、平台、性能和签名证据仍需补齐。

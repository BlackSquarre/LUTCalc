# 仓库目录说明

LUTCalc 当前按实现形态和用途组织代码：

- `Native/`：Swift 原生应用、LUTKit 包及其测试。
- `legacy/web/`：历史浏览器版实现，包括 HTML、CSS、JavaScript、浏览器依赖、图像和旧 `.labin` 资源。
- `tools/`：验证、生成和研究辅助工具。Python、JavaScript 和 Shell 脚本按工具用途放在相应子目录中。
- `tests/`：Node 与 Python 契约测试及固定夹具。
- `research/`：研究资料、外部来源快照和迁移参考，不参与产品构建。
- `docs/`：项目文档与验证记录。

为保持旧部署和验证命令兼容，仓库根目录保留指向 `legacy/web/` 的符号链接。实际 Web 源码只维护 `legacy/web/` 中的副本。

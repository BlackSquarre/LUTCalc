# 项目约定

## 文档语言

**本项目所有文档一律使用中文撰写。** 自 2026-09-22 起生效，适用于此后新增或重写的任何 `.md` 文件（含 `README.md`、`CHANGELOG.md`、`NOTICE.md`、`docs/**`）。术语、标准名、函数名、文件路径、代码标识符保留原文（如 ACEScct、Rec.2020、`gammaList`、`js/gamma.js`）。

**既有英文文档不回译**，保持原样：`README.md`、`CHANGELOG.md`、`NOTICE.md`、`docs/dlog2.md`、`docs/cs-tf-coverage.md`。若日后实质性重写其中某一份，则改用中文。

代码内注释按原仓库风格保持英文，不在此规则范围内（除非另行说明）。

## 已验证的项目事实

- 无 npm / 无构建脚本。测试用 Node 18+ 内置 test runner：`node --test tests/*.test.js`，无需安装依赖。
- `index.html` 加载 `js/lutcalccombined.js`；`indexunminified.html` 加载散装的 `js/gamma.js` / `js/colourspace.js` 等。
- 三个 bundle 是**手工镜像**，不是生成产物，改动注册表必须同步：
  - `js/lutcalccombined.js`
  - `js/gammaworkerscombined.js`（经 `js/gammaworker.js:3` 的 `importScripts` 加载）
  - `js/colourspaceworkerscombined.js`（经 `js/colourspaceworker.js:3` 的 `importScripts` 加载）
- 色彩空间 / 伽马注册表位置见 `docs/cs-tf-coverage.md`。

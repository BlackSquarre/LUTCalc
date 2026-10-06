# Blackmagic Gen5 与 Canon C-Log2/C-Log3 计划色域身份验收

## 范围

本次只补充 Gen5、Canon C-Log2、Canon C-Log3 计划的方向和两端色域身份。公开 transfer 公式、Canon Cinema Gamut/Blackmagic Wide Gamut Gen5 矩阵、Double 路径和阈值未修改。

## 契约与实现

新增 Gen5、C-Log2、C-Log3 的输入/输出方向和输出色域变化契约，并更新 C-Log3 预设的完整身份断言。三个分支统一使用 `directionalAndSpaces`，保留已有固定 `gamut` 标识。

## 验证

```sh
swift test --package-path Native/Packages/LUTKit -c release --filter 'BMDGen5ContractsTests|CanonCLog2ContractsTests|CanonCLog3ContractsTests'
swift test --package-path Native/Packages/LUTKit -c release --quiet
git diff --check
```

工具链：Apple Swift 6.4、swift-driver 1.168.6、arm64 macOS 27.0.0。

定向 Release 17/17 通过。BMD Gen5 独立曲线 20,534 点最大尺度化误差 `1.4077780908170443e-14`，矩阵 576 项最大误差 `9.910082886630748e-16`。整包 Release 日志 `/tmp/lutkit-full-20261006-bmd-canon.log` 中所有测试套件通过，LUTAnalysis 93/93；`git diff --check` 退出码 `0`。

## 未覆盖

本项不代表完整相机策略、全机型范围、厂商 LUT 替代、完整 ICC/HDR、任意三维全根、平台或发布验收完成。

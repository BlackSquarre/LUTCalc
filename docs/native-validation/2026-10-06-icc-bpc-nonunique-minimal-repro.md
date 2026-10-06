# ICC BPC 非唯一性最小复现

## 目的

本记录把 BPC 阻塞具体化为不依赖厂商 profile 的数学复现。不新增生产实现，也不把任意压缩模型注册为 ICC 算法。

## 固定输入

设 source/target 归一化黑点为 `Bs = 0.02`、`Bt = 0.10`，白点均为 `1.0`，输入为 `x = 0.20`。对任意 `p > 0`，定义：

```text
f_p(x) = Bt + (1 - Bt) * ((x - Bs) / (1 - Bs))^p
```

该族保持 `f_p(Bs) = Bt` 和 `f_p(1) = 1`，但 `p` 不是 ICC 通用 profile 头部字段，也不是由 `bkpt`/`wtpt` 唯一推导的量。

## 实际复现命令与结果

```sh
node - <<'NODE'
const bs = 0.02, bt = 0.10, x = 0.20;
for (const p of [1, 0.8, 1.2]) {
  console.log(p, bt + (1 - bt) * Math.pow((x - bs) / (1 - bs), p));
}
NODE
```

输出：

```text
1 0.26530612244897966
0.8 0.3319955491316212
1.2 0.21778723437324976
```

三条路径使用相同的黑点、白点和输入，结果相差约 `0.1142083`。端点约束和 `bkpt`/`wtpt` 信息不足以确定 BPC 中间曲线。

## 结论

ICC rendering intent 只规定语义类别；BPC 还需要 CMM 约定的黑点来源、媒体相对/绝对单位和压缩模型。任意选择 `p`、线性平移、clip 或 chroma compression 都会改变用户 profile 意图，且没有独立逐码参照证明正确。当前 linking 路径保持明确拒绝 BPC；LUT 与 device-link 只执行用户 profile 已提供的变换。

完整 ICC、BPC、通用 gamut mapping 和 ColorSync 仍为研究阻塞，Goal 保持 `active`。

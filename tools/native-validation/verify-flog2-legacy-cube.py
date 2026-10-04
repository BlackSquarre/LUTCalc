"""按旧版 js/gamma.js 的九参数 F-Log2 兼容公式逐节点读回 CUBE。"""

import argparse
import json
import math
from decimal import Decimal, localcontext
from pathlib import Path


def reference(signal: float) -> float:
    with localcontext() as context:
        context.prec = 80
        value = Decimal.from_float(signal)
        if value < Decimal("0.100686685"):
            legacy = Decimal("0.12627036") * value - Decimal("0.011725971")
        else:
            legacy = (Decimal(10) ** ((value - Decimal("0.384316")) / Decimal("0.245281")
                      ) - Decimal("0.064829")) / Decimal("5.0000004")
        return float(Decimal("0.245281") *
                     (Decimal("5.0000004") * (legacy * 2) + Decimal("0.064829")).log10()
                     + Decimal("0.384316")) if legacy * 2 >= Decimal("0.000987778") else float(
                         ((legacy * 2) + Decimal("0.011725971")) / Decimal("0.12627036"))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("cube", type=Path)
    parser.add_argument("--size", type=int, required=True)
    args = parser.parse_args()
    size = None
    rows = []
    for number, line in enumerate(args.cube.read_text().splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#") or line.startswith(("TITLE", "DOMAIN_")):
            continue
        if line.startswith("LUT_3D_SIZE "):
            if size is not None:
                raise ValueError("duplicate size")
            size = int(line.split()[1])
            continue
        values = line.split()
        if len(values) != 3:
            raise ValueError(f"bad node at {number}")
        rgb = [float(value) for value in values]
        if not all(map(math.isfinite, rgb)):
            raise ValueError(f"nonfinite node at {number}")
        rows.append(rgb)
    if size != args.size or len(rows) != size ** 3:
        raise ValueError(f"shape: {size}, {len(rows)}")
    errors = []
    worst = (-1, -1, -1.0)
    references = [reference(index / (size - 1)) for index in range(size)]
    for index, actual in enumerate(rows):
        for channel in range(3):
            target = references[(index // size ** channel) % size]
            error = abs(actual[channel] - target) / max(1, abs(target))
            errors.append(error)
            if error > worst[2]:
                worst = (index, channel, error)
    errors.sort()
    result = {
        "nodes": len(rows), "maxScaled": worst[2], "worstIndex": worst[0],
        "worstChannel": worst[1],
        "rmsScaled": math.sqrt(math.fsum(value * value for value in errors) / len(errors)),
        "p99Scaled": errors[math.ceil(0.99 * len(errors)) - 1], "threshold": 2e-12,
    }
    print(json.dumps(result, ensure_ascii=False))
    if result["maxScaled"] > result["threshold"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

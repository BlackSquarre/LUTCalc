"""按 Xiaomi Mi-Log 白皮书公开三段公式独立读回线性输出 CUBE。"""

import argparse
import json
import math
from decimal import Decimal, localcontext
from pathlib import Path


def reference(signal: float) -> float:
    with localcontext() as context:
        context.prec = 80
        value = Decimal.from_float(signal)
        r0 = Decimal("-0.09023729")
        rt = Decimal("0.01974185")
        c = Decimal("18.10531998")
        gamma = Decimal("0.09271529")
        beta = Decimal("0.01384578")
        delta = Decimal("0.67291850")
        pt = c * (rt - r0) * (rt - r0)
        ln2 = Decimal(2).ln()
        if value < 0:
            scene = r0
        elif value < pt:
            scene = (value / c).sqrt() + r0
        else:
            scene = ((value - delta) / gamma * ln2).exp() - beta
        return float(scene * 2)


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
    references = [reference(index / (size - 1)) for index in range(size)]
    errors = []
    worst = (-1, -1, -1.0)
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

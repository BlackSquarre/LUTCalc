"""按 ACESproxy 10/12-bit公开码值公式独立读回同 AP1 曝光 CUBE。"""

import argparse
import json
import math
from decimal import Decimal, localcontext
from pathlib import Path


def reference(signal: float, bit_depth: int) -> float:
    with localcontext() as context:
        context.prec = 80
        value = Decimal.from_float(signal)
        maximum = Decimal(1023 if bit_depth == 10 else 4095)
        black = Decimal(64 if bit_depth == 10 else 256)
        multiplier = Decimal(50 if bit_depth == 10 else 200)
        offset = Decimal(425 if bit_depth == 10 else 1700)
        ln2 = Decimal(2).ln()
        low = (Decimal(2) ** Decimal("-9.72")) / Decimal("0.9")
        linear = (((value * maximum - offset) / multiplier - Decimal("2.5")) * ln2).exp() / Decimal("0.9")
        linear *= Decimal(2)
        if linear <= low:
            return float(black / maximum)
        return float((((linear * Decimal("0.9")).ln() / ln2 + Decimal("2.5")) * multiplier + offset) / maximum)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("cube", type=Path)
    parser.add_argument("--size", type=int, required=True)
    parser.add_argument("--bit-depth", type=int, choices=(10, 12), required=True)
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
    references = [reference(index / (size - 1), args.bit_depth) for index in range(size)]
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
        "bitDepth": args.bit_depth, "nodes": len(rows), "maxScaled": worst[2],
        "worstIndex": worst[0], "worstChannel": worst[1],
        "rmsScaled": math.sqrt(math.fsum(value * value for value in errors) / len(errors)),
        "p99Scaled": errors[math.ceil(0.99 * len(errors)) - 1], "threshold": 2e-12,
    }
    print(json.dumps(result, ensure_ascii=False))
    if result["maxScaled"] > result["threshold"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

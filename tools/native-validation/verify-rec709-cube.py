"""独立解析完整 CUBE，按旧 Rec.709 曲线语义逐节点比较曝光 +1。"""

import argparse
import json
import math
from pathlib import Path


def decode(signal: float) -> float:
    if signal >= 0.081:
        return ((signal + 0.099) / 1.099) ** (1 / 0.45)
    return signal / 4.5


def encode(linear: float) -> float:
    if linear >= 0.018:
        return 1.099 * linear ** 0.45 - 0.099
    return 4.5 * linear


def expected(signal: float) -> float:
    return encode(decode(signal) * 2)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("cube", type=Path)
    parser.add_argument("--size", type=int, required=True)
    args = parser.parse_args()
    size = None
    rows = []
    for line in args.cube.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or line.startswith("TITLE") or line.startswith("DOMAIN_"):
            continue
        if line.startswith("LUT_3D_SIZE "):
            if size is not None:
                raise ValueError("duplicate size")
            size = int(line.split()[1])
            continue
        values = line.split()
        if len(values) != 3:
            raise ValueError(f"bad row: {line}")
        parsed = [float(value) for value in values]
        if not all(math.isfinite(value) for value in parsed):
            raise ValueError(f"nonfinite row: {line}")
        rows.append(parsed)
    if size != args.size or len(rows) != size ** 3:
        raise ValueError(f"shape: size={size}, nodes={len(rows)}")
    errors = []
    worst = (-1, -1, -1.0)
    for index, actual in enumerate(rows):
        for channel in range(3):
            signal = ((index // size ** channel) % size) / (size - 1)
            target = expected(signal)
            error = abs(actual[channel] - target) / max(1, abs(target))
            errors.append(error)
            if error > worst[2]:
                worst = (index, channel, error)
    errors.sort()
    result = {
        "nodes": len(rows), "maxScaled": worst[2], "worstIndex": worst[0],
        "worstChannel": worst[1], "rmsScaled": math.sqrt(math.fsum(x * x for x in errors) / len(errors)),
        "p99Scaled": errors[math.ceil(0.99 * len(errors)) - 1], "threshold": 2e-12,
    }
    print(json.dumps(result, ensure_ascii=False))
    if result["maxScaled"] > result["threshold"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

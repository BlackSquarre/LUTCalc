"""按 ACES 解析曲线与独立 Decimal 矩阵逐节点验证 Apple Log 双版本 CUBE。"""

import argparse
import json
import math
from pathlib import Path


def decode(value):
    r0 = -0.05641088
    c = 47.28711236
    b = 0.00964052
    g = 0.08550479
    d = 0.69336945
    pt = c * (0.01 - r0) ** 2
    if value >= pt:
        return 2 ** ((value - d) / g) - b
    if value >= 0:
        return math.sqrt(value / c) + r0
    return r0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("cube", type=Path)
    parser.add_argument("fixture", type=Path)
    parser.add_argument("--size", type=int, required=True)
    parser.add_argument("--variant", choices=("original", "log2"), required=True)
    args = parser.parse_args()
    reference = json.loads(args.fixture.read_text())
    variant = reference["variants"][args.variant]
    expected_id = ("urn:ampas:aces:transformId:v2.0:CSC.Apple."
                   + ("AppleLog" if args.variant == "original" else "AppleLog2")
                   + "_to_ACES.a2.v1")
    matrix = variant["matrixToAP0Bradford"]
    if variant["sourceTransformID"] != expected_id or len(matrix) != 9 \
            or reference["scaledTolerance"] != 2e-12:
        raise ValueError("source, matrix or frozen threshold")
    rows = []
    size = None
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
    for index, actual in enumerate(rows):
        encoded = [((index // size ** channel) % size) / (size - 1)
                   for channel in range(3)]
        scene = [decode(value) * 2 for value in encoded]
        for channel in range(3):
            target = math.fsum(matrix[channel * 3 + source] * scene[source]
                               for source in range(3))
            error = abs(actual[channel] - target) / max(1, abs(target))
            errors.append(error)
            if error > worst[2]:
                worst = (index, channel, error)
    errors.sort()
    result = {
        "variant": args.variant, "nodes": len(rows),
        "maxScaled": worst[2], "worstIndex": worst[0], "worstChannel": worst[1],
        "rmsScaled": math.sqrt(math.fsum(value * value for value in errors) / len(errors)),
        "p99Scaled": errors[math.ceil(0.99 * len(errors)) - 1], "threshold": 2e-12,
    }
    print(json.dumps(result, ensure_ascii=False))
    if result["maxScaled"] > result["threshold"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

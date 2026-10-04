"""用 ARRI 公布矩阵及独立 Python 解码逐节点验证 LogC4→AP0 CUBE。"""

import argparse
import json
import math
from pathlib import Path


def decode(value):
    a = (2 ** 18 - 16) / 117.45
    b = (1023 - 95) / 1023
    c = 95 / 1023
    s = 7 * math.log(2) * 2 ** (7 - 14 * c / b) / (a * b)
    t = (2 ** (-14 * c / b + 6) - 64) / a
    if value < 0:
        return value * s + t
    return (2 ** (14 * (value - c) / b + 6) - 64) / a


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("cube", type=Path)
    parser.add_argument("fixture", type=Path)
    parser.add_argument("--size", type=int, required=True)
    args = parser.parse_args()
    reference = json.loads(args.fixture.read_text())
    if reference["sourceTransformID"] != "urn:ampas:aces:transformId:v2.0:CSC.Arri.LogC4_to_ACES.a2.v1":
        raise ValueError("source transform changed")
    matrix = reference["matrixAWG4ToAP0"]
    if len(matrix) != 9 or reference["scaledTolerance"] != 2e-12:
        raise ValueError("matrix or frozen threshold")
    rows = []
    size = None
    for line_number, line in enumerate(args.cube.read_text().splitlines(), 1):
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
            raise ValueError(f"bad node at {line_number}")
        rgb = [float(value) for value in values]
        if not all(map(math.isfinite, rgb)):
            raise ValueError(f"nonfinite node at {line_number}")
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

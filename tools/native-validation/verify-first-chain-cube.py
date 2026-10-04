"""独立读取 Swift 导出的 CUBE，并用 DJI CTL 公式及冻结矩阵逐节点比对。"""

import argparse
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REFERENCE = ROOT / "tests/fixtures/dlog2-reference.json"


def decode(value):
    a = 16.285770761945304
    h = 475 / (2**a - 1)
    k1 = 0.059439938321493
    b1 = 0.304985337243402
    k2 = 2.960935245492250
    b2 = 0.148314799066323
    cut = 0.028961695254132
    if value >= b1:
        return h * (2 ** (a * value) - 1)
    if value >= b2:
        return 2 ** ((value - b1) / k1 + math.log2(0.18))
    return (value - b2) / k2 + cut


def read_cube(path):
    size = None
    values = []
    for line_number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith("TITLE "):
            continue
        if line.startswith("LUT_3D_SIZE "):
            if size is not None:
                raise ValueError(f"duplicate size at line {line_number}")
            size = int(line.split()[1])
            continue
        fields = line.split()
        if len(fields) != 3:
            raise ValueError(f"wrong channel count at line {line_number}")
        values.append(tuple(float(value) for value in fields))
        if not all(math.isfinite(value) for value in values[-1]):
            raise ValueError(f"nonfinite channel at line {line_number}")
    if size is None or len(values) != size**3:
        raise ValueError(f"size or row count mismatch: {size}, {len(values)}")
    return size, values


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("cube", type=Path)
    parser.add_argument("--size", "--expected-size", dest="expected_size", type=int, required=True)
    args = parser.parse_args()
    size, values = read_cube(args.cube)
    if size != args.expected_size:
        raise ValueError(f"expected size {args.expected_size}, found {size}")
    matrix = json.loads(REFERENCE.read_text())["toAP0"]
    errors = []
    worst = (-1.0, -1, -1)
    for index, actual in enumerate(values):
        coordinate = (
            (index % size) / (size - 1),
            ((index // size) % size) / (size - 1),
            (index // (size * size)) / (size - 1),
        )
        scene = tuple(decode(value) for value in coordinate)
        for channel in range(3):
            expected = math.fsum(matrix[channel * 3 + k] * scene[k] * 2 for k in range(3))
            error = abs(actual[channel] - expected) / max(1, abs(expected))
            errors.append(error)
            if error > worst[0]:
                worst = (error, index, channel)
    errors.sort()
    result = {
        "status": "passed" if worst[0] <= 2e-12 else "failed",
        "nodes": len(values),
        "maxScaledError": worst[0],
        "worstNode": worst[1],
        "worstChannel": worst[2],
        "rmsScaledError": math.sqrt(math.fsum(error * error for error in errors) / len(errors)),
        "p99ScaledError": errors[math.ceil(0.99 * len(errors)) - 1],
        "threshold": 2e-12,
    }
    print(json.dumps(result, ensure_ascii=False))
    if result["status"] != "passed":
        raise SystemExit(1)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""用 Python Decimal 独立复核 Canon C-Log2/Cinema Gamut 的 Swift 输出。"""

from __future__ import annotations

import argparse
import hashlib
import json
from decimal import Decimal, getcontext
from pathlib import Path

getcontext().prec = 90
D = Decimal


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def mat_vec(a, v):
    return [sum(a[i][k] * v[k] for k in range(3)) for i in range(3)]


def mat_inv(a):
    aug = [list(a[i]) + [D(int(i == j)) for j in range(3)] for i in range(3)]
    for col in range(3):
        pivot = max(range(col, 3), key=lambda row: abs(aug[row][col]))
        if aug[pivot][col] == 0:
            raise ValueError("奇异矩阵")
        aug[col], aug[pivot] = aug[pivot], aug[col]
        scale = aug[col][col]
        aug[col] = [x / scale for x in aug[col]]
        for row in range(3):
            if row == col:
                continue
            factor = aug[row][col]
            aug[row] = [aug[row][j] - factor * aug[col][j] for j in range(6)]
    return [row[3:] for row in aug]


def xyz(x, y):
    return [x / y, D(1), (D(1) - x - y) / y]


def rgb_to_xyz(primaries):
    r, g, b, w = primaries
    p = [[r[0] / r[1], g[0] / g[1], b[0] / b[1]],
         [D(1), D(1), D(1)],
         [(D(1) - r[0] - r[1]) / r[1], (D(1) - g[0] - g[1]) / g[1],
          (D(1) - b[0] - b[1]) / b[1]]]
    scale = mat_vec(mat_inv(p), xyz(*w))
    return [[p[i][j] * scale[j] for j in range(3)] for i in range(3)]


def cat02(source_white, destination_white):
    a = [[D("0.7328"), D("0.4296"), D("-0.1624")],
         [D("-0.7036"), D("1.6975"), D("0.0061")],
         [D("0.0030"), D("0.0136"), D("0.9834")]]
    source = mat_vec(a, xyz(*source_white))
    destination = mat_vec(a, xyz(*destination_white))
    diagonal = [[destination[i] / source[i] if i == j else D(0) for j in range(3)] for i in range(3)]
    return mat_mul(mat_mul(mat_inv(a), diagonal), a)


CANON = ((D("0.7400"), D("0.2700")), (D("0.1700"), D("1.1400")),
         (D("0.0800"), D("-0.1000")), (D("0.3127"), D("0.3290")))
AP0 = ((D("0.73470"), D("0.26530")), (D("0.00000"), D("1.00000")),
       (D("0.00010"), D("-0.07700")), (D("0.32168"), D("0.33767")))


def conversion(source, destination):
    src = rgb_to_xyz(source)
    dst = rgb_to_xyz(destination)
    adaptation = cat02(source[3], destination[3])
    return mat_mul(mat_mul(mat_inv(dst), adaptation), src)


MATRIX = conversion(CANON, AP0)
SLOPE = D("0.24136077")
OFFSET = D("0.092864125")
PUBLISHED_CONSTANT = D("87.099375")
LEGACY_CONSTANT = D("87.09937546")
LEGACY_CUT = D("-0.006747091156")
LEGACY_SLOPE = D("0.045164984")


def power10(value):
    return D(10) ** value


def decode(value, legacy):
    if not legacy:
        linear = (-(power10((OFFSET - value) / SLOPE) - 1) / PUBLISHED_CONSTANT
                  if value < OFFSET else
                  (power10((value - OFFSET) / SLOPE) - 1) / PUBLISHED_CONSTANT)
        return D("0.9") * linear
    if value == 0:
        return D(0)
    linear = ((power10((value - OFFSET) / SLOPE) - 1) / LEGACY_CONSTANT
              if value >= 0 else LEGACY_SLOPE * value + LEGACY_CUT)
    return D("0.9") * linear


def expected(values, legacy):
    scene = [decode(v, legacy) for v in values]
    return mat_vec(MATRIX, scene)


def parse_cube(path):
    values = []
    size = None
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        if fields[0].upper() == "LUT_3D_SIZE":
            size = int(fields[1])
        elif fields[0][0].isdigit() or fields[0][0] in "+-.":
            if len(fields) == 3:
                values.append(tuple(D(x) for x in fields))
    if size is None or len(values) != size ** 3:
        raise ValueError(f"{path}: size={size}, samples={len(values)}")
    return size, values


def verify_cube(path, legacy):
    size, values = parse_cube(path)
    maximum = D(0)
    rms_sum = D(0)
    worst = None
    axis = [decode(D(i) / D(size - 1), legacy) for i in range(size)]
    for index, actual in enumerate(values):
        scene = (axis[index % size], axis[(index // size) % size], axis[index // (size * size)])
        expected_values = mat_vec(MATRIX, scene)
        for channel, (a, e) in enumerate(zip(actual, expected_values)):
            error = abs(a - e) / max(D(1), abs(e))
            rms_sum += error * error
            if error > maximum:
                maximum = error
                worst = {"index": index, "channel": channel, "actual": str(a), "expected": str(e)}
    count = D(3 * len(values))
    return {"fileSHA256": hashlib.sha256(path.read_bytes()).hexdigest(), "size": size, "channels": int(count), "maximumRelativeError": str(maximum),
            "rmsRelativeError": str((rms_sum / count).sqrt()), "worst": worst}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("artifact", type=Path)
    args = parser.parse_args()
    directory_file = args.artifact / "cube-directory.txt"
    cubes = Path(directory_file.read_text().strip()) if directory_file.exists() else args.artifact / "cubes"
    results = {"precision": 90, "matrix": [[str(x) for x in row] for row in MATRIX],
               "scalar": {"publishedDecode0": str(decode(D(0), False)),
                          "publishedDecode018": str(decode(D("0.39825469203794917"), False)),
                          "legacyDecode0": str(decode(D(0), True))}, "cubes": {}}
    for name, legacy in (("case-0-33.cube", False), ("case-0-65.cube", False),
                         ("case-1-33.cube", True), ("case-1-65.cube", True)):
        results["cubes"][name] = verify_cube(cubes / name, legacy)
    (args.artifact / "independent-decimal-results.json").write_text(
        json.dumps(results, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps(results, indent=2, ensure_ascii=False))
    if any(D(r["maximumRelativeError"]) > D("2e-12") for r in results["cubes"].values()):
        raise SystemExit(2)


if __name__ == "__main__":
    main()

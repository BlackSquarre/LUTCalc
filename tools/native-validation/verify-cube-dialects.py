"""独立逐行读取六份 Swift 写出的 1D/3D CUBE 方言样例。"""

import argparse
import math
from pathlib import Path


DOMAINS = {
    "general": ([0, 0, 0], [1, 1, 1]),
    "resolve": ([-0.1] * 3, [1.5] * 3),
    "domain": ([-0.1, 0, 0.2], [1.5, 1.2, 2]),
}


def check_file(directory, dialect, dimension):
    path = directory / f"{dialect}-{dimension}d.cube"
    lines = [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if lines[0] != 'TITLE "方言 Double"':
        raise ValueError(f"{path}: title")
    size = 3 if dimension == 1 else 2
    if lines[1] != f"LUT_{dimension}D_SIZE {size}":
        raise ValueError(f"{path}: size")
    position = 2
    minimum, maximum = DOMAINS[dialect]
    if dialect == "resolve":
        tokens = lines[position].split()
        if tokens[0] != f"LUT_{dimension}D_INPUT_RANGE" or len(tokens) != 3:
            raise ValueError(f"{path}: input range directive")
        if [float(x) for x in tokens[1:]] != [minimum[0], maximum[0]]:
            raise ValueError(f"{path}: input range values")
        position += 1
    elif dialect == "domain":
        for prefix, expected in [("DOMAIN_MIN", minimum), ("DOMAIN_MAX", maximum)]:
            tokens = lines[position].split()
            if tokens[0] != prefix or len(tokens) != 4 or [float(x) for x in tokens[1:]] != expected:
                raise ValueError(f"{path}: {prefix}")
            position += 1
    count = size if dimension == 1 else size ** 3
    if len(lines) - position != count:
        raise ValueError(f"{path}: row count")
    worst = 0.0
    for index, line in enumerate(lines[position:]):
        tokens = line.split()
        if len(tokens) != 3:
            raise ValueError(f"{path}: channel count")
        values = [float(x) for x in tokens]
        expected = [index / 7, index / 3 - 0.5, index / 11 + 1]
        for value, target in zip(values, expected):
            if not math.isfinite(value):
                raise ValueError(f"{path}: non-finite")
            error = abs(value - target) / max(1, abs(target))
            worst = max(worst, error)
            if error > 2e-12:
                raise ValueError(f"{path}: numeric error {error}")
    return worst


def check_combined(directory):
    path = directory / "resolve-shaper-3d.cube"
    lines = [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    expected_header = [
        'TITLE "shaper 组合"',
        "LUT_1D_SIZE 2",
        "LUT_1D_INPUT_RANGE -1.0 1.0",
        "LUT_3D_SIZE 2",
        "LUT_3D_INPUT_RANGE 0 2.0",
    ]
    if lines[:5] != expected_header or len(lines) != 15:
        raise ValueError(f"{path}: combined header or row count")
    expected = [[0, 0, 0], [2, 1, 0.5]]
    expected += [[index % 2, (index // 2) % 2, index // 4] for index in range(8)]
    worst = 0.0
    for row, target in zip(lines[5:], expected):
        values = [float(token) for token in row.split()]
        if len(values) != 3 or not all(math.isfinite(x) for x in values):
            raise ValueError(f"{path}: malformed or non-finite row")
        worst = max(worst, *(abs(x - y) for x, y in zip(values, target)))
    if worst != 0:
        raise ValueError(f"{path}: combined numeric error {worst}")
    return worst


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    worst = max(check_file(args.directory, dialect, dimension)
                for dialect in DOMAINS for dimension in [1, 3])
    combined_error = check_combined(args.directory)
    print(f"七份 CUBE 方言独立解析通过：1D/3D 各三类及 shaper+3D，最大尺度化误差 {worst}，组合误差 {combined_error}")


if __name__ == "__main__":
    main()

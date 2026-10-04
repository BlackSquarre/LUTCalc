#!/usr/bin/env python3
"""用独立 Decimal 公式核对原生 Rec.2020 10-bit CUBE 输出。"""
from decimal import Decimal, getcontext
from pathlib import Path
import sys

getcontext().prec = 90
A = Decimal("1.099")
B = Decimal("0.018")
S = Decimal("4.5")
EB = Decimal("0.081")
TOL = Decimal("2e-12")

def decode(v: Decimal) -> Decimal:
    return ((v + (A - 1)) / A) ** (Decimal(1) / Decimal("0.45")) if v >= EB else v / S

def encode(v: Decimal) -> Decimal:
    return A * (v ** Decimal("0.45")) - (A - 1) if v >= B else S * v

def read_cube(path: Path):
    samples = []
    size = None
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        if fields[0].upper() == "LUT_3D_SIZE":
            size = int(fields[1])
        elif len(fields) == 3:
            samples.append(tuple(Decimal(x) for x in fields))
    if size is None:
        raise SystemExit(f"missing LUT_3D_SIZE: {path}")
    return size, samples

def main() -> int:
    worst = Decimal(0)
    total = 0
    for name in sys.argv[1:]:
        size, samples = read_cube(Path(name))
        expected_count = size ** 3
        if len(samples) != expected_count:
            raise SystemExit(f"{name}: expected {expected_count} samples, got {len(samples)}")
        for index, actual in enumerate(samples):
            r_index = index % size
            g_index = (index // size) % size
            b_index = index // (size * size)
            coordinates = tuple(Decimal(i) / Decimal(size - 1) for i in (r_index, g_index, b_index))
            # The preset applies exposure +1 in scene-linear space.
            expected = tuple(encode(Decimal(2) * decode(value)) for value in coordinates)
            error = max(abs(value - want) for value, want in zip(actual, expected))
            worst = max(worst, error)
            total += 3
            if error > TOL:
                raise SystemExit(f"{name}: sample {index} error {error} > {TOL}")
    print(f"independent Decimal samples={total} maxAbsError={worst} tolerance={TOL}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

"""按旧 RED Log3G10 LUTGammaLogLog 的 log/log 与合法数据包装独立读回 CUBE。"""
import sys
from decimal import Decimal, getcontext

getcontext().prec = 90
SLOPE = Decimal("0.224282")
SCALE = Decimal("155.975327")
OFFSET = Decimal("0.01")
INPUT_SCALE = Decimal("0.9")
LEGAL_SCALE = Decimal("0.85630498533724")
LEGAL_OFFSET = Decimal("0.06256109481916")
TOL = Decimal("3e-15")

def decode(value: Decimal) -> Decimal:
    legal = (value - LEGAL_OFFSET) / LEGAL_SCALE
    magnitude = (Decimal(10) ** (abs(legal) / SLOPE))
    if legal < 0:
        return ((Decimal(1) - magnitude) / SCALE - OFFSET) / INPUT_SCALE
    return ((magnitude - Decimal(1)) / SCALE - OFFSET) / INPUT_SCALE

def encode(value: Decimal) -> Decimal:
    shifted = value * INPUT_SCALE + OFFSET
    if shifted < 0:
        raw = -SLOPE * (Decimal(1) - shifted * SCALE).log10()
    else:
        raw = SLOPE * (Decimal(1) + shifted * SCALE).log10()
    return raw * LEGAL_SCALE + LEGAL_OFFSET

def read_cube(path):
    rows = []
    size = None
    for line in open(path, encoding="utf-8"):
        fields = line.split()
        if not fields or fields[0].startswith("#"):
            continue
        if fields[0].upper() == "LUT_3D_SIZE":
            size = int(fields[1])
        elif len(fields) == 3:
            rows.append(tuple(Decimal(item) for item in fields))
    if size is None or len(rows) != size ** 3:
        raise SystemExit(f"invalid CUBE size={size} rows={len(rows)}")
    return size, rows

size, rows = read_cube(sys.argv[1])
worst = Decimal(0)
for index, output in enumerate(rows):
    coordinates = (
        Decimal(index % size) / Decimal(size - 1),
        Decimal((index // size) % size) / Decimal(size - 1),
        Decimal(index // (size * size)) / Decimal(size - 1),
    )
    for actual, coordinate in zip(output, coordinates):
        expected = encode(Decimal(2) * decode(coordinate))
        worst = max(worst, abs(actual - expected))
if worst > TOL:
    raise SystemExit(f"RED Log3G10 CUBE mismatch size={size} maxAbsError={worst} tolerance={TOL}")
print(f"RED Log3G10 independent Decimal CUBE passed size={size} samples={len(rows)*3} maxAbsError={worst} tolerance={TOL}")

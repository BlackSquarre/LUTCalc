"""独立 Decimal 读回旧 Null 恒等+一档曝光 CUBE。"""
import sys
from decimal import Decimal, getcontext

getcontext().prec = 80
scale = Decimal("0.85630498533724")
offset = Decimal("0.06256109481916")

def read(path):
    size = None
    rows = []
    for line in open(path, encoding="utf8"):
        fields = line.split()
        if not fields or fields[0].startswith("#"):
            continue
        if fields[0].upper() == "LUT_3D_SIZE":
            size = int(fields[1])
        elif len(fields) == 3:
            rows.append(tuple(Decimal(x) for x in fields))
    if size is None or len(rows) != size ** 3:
        raise SystemExit("invalid cube")
    return size, rows

size, rows = read(sys.argv[1])
maximum = Decimal(0)
for index, row in enumerate(rows):
    coordinates = (
        Decimal(index % size) / Decimal(size - 1),
        Decimal((index // size) % size) / Decimal(size - 1),
        Decimal(index // (size * size)) / Decimal(size - 1),
    )
    for actual, encoded in zip(row, coordinates):
        expected = Decimal(2) * encoded - offset
        maximum = max(maximum, abs(actual - expected))
threshold = Decimal("3e-15")
if maximum > threshold:
    raise SystemExit(f"mismatch {size} {maximum}")
print(f"Null independent Decimal CUBE passed size={size} samples={len(rows) * 3} maxAbsError={maximum} tolerance={threshold}")

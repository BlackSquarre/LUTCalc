"""独立读取完整 CUBE 并逐节点比较 D-Log2/D-Gamut2→sRGB 公式参照。"""

import argparse
import json
import math
import runpy
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
decode = runpy.run_path(str(ROOT / "tools/native-validation/generate-first-chain-reference.py"))["decode"]
reference = runpy.run_path(str(ROOT / "tools/native-validation/generate-srgb-plan-reference.py"))
MATRIX = [float(value) for value in reference["SRGB_INVERSE"]]
TO_XYZ = json.loads((ROOT / "tests/fixtures/dlog2-reference.json").read_text())["toXYZ"]


def expected(rgb):
    scene = [decode(value) * 2 for value in rgb]
    xyz = [math.fsum(TO_XYZ[row * 3 + col] * scene[col] for col in range(3)) for row in range(3)]
    linear = [math.fsum(MATRIX[row * 3 + col] * xyz[col] for col in range(3)) for row in range(3)]
    return [reference["encode"](value, False) for value in linear]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("cube", type=Path)
    parser.add_argument("--size", type=int, required=True)
    args = parser.parse_args()
    rows = []
    size = None
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
        rows.append([float(value) for value in values])
    if size != args.size or len(rows) != size ** 3:
        raise ValueError(f"shape: size={size}, nodes={len(rows)}")
    errors = []
    worst = (-1, -1, -1.0)
    for index, actual in enumerate(rows):
        signal = [((index // size ** channel) % size) / (size - 1) for channel in range(3)]
        target = expected(signal)
        for channel in range(3):
            error = abs(actual[channel] - target[channel]) / max(1, abs(target[channel]))
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

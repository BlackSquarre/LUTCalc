"""独立读取整份 CUBE，对 Sony S-Log3 及旧兼容曝光链逐节点比较。"""

import argparse
import json
import math
from pathlib import Path


def sony_decode(value: float) -> float:
    if value >= 171.2102946929 / 1023:
        return 10 ** ((value * 1023 - 420) / 261.5) * 0.19 - 0.01
    return (value * 1023 - 95) * 0.01125 / (171.2102946929 - 95)


def sony_encode(value: float) -> float:
    if value >= 0.01125:
        return (420 + math.log10((value + 0.01) / 0.19) * 261.5) / 1023
    return (value * (171.2102946929 - 95) / 0.01125 + 95) / 1023


def legacy_decode(value: float) -> float:
    if value >= 0.1673609920:
        return (10 ** ((value - 0.4105571850) / 0.2556207230) - 0.0526315790) / 4.7368421060
    return 0.1677922920 * value - 0.0155818840


def legacy_encode(value: float) -> float:
    if value >= 0.0125:
        return 0.2556207230 * math.log(value * 4.7368421060 + 0.0526315790) / math.log(10) + 0.4105571850
    return (value + 0.0155818840) / 0.1677922920


def read_cube(path: Path, expected_size: int) -> list[list[float]]:
    size = None
    rows = []
    for number, line in enumerate(path.read_text().splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#") or line.startswith(("TITLE", "DOMAIN_")):
            continue
        if line.startswith("LUT_3D_SIZE "):
            if size is not None:
                raise ValueError(f"duplicate size at line {number}")
            size = int(line.split()[1])
            continue
        parts = line.split()
        if len(parts) != 3:
            raise ValueError(f"bad node at line {number}")
        values = [float(part) for part in parts]
        if not all(map(math.isfinite, values)):
            raise ValueError(f"nonfinite node at line {number}")
        rows.append(values)
    if size != expected_size or len(rows) != expected_size ** 3:
        raise ValueError(f"shape: {size}, {len(rows)}")
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("cube", type=Path)
    parser.add_argument("--size", type=int, required=True)
    parser.add_argument("--variant", choices=("sony", "legacy"), required=True)
    args = parser.parse_args()
    rows = read_cube(args.cube, args.size)
    decode, encode = (sony_decode, sony_encode) if args.variant == "sony" else (legacy_decode, legacy_encode)
    errors = []
    worst = (-1, -1, -1.0)
    for index, actual in enumerate(rows):
        for channel in range(3):
            signal = ((index // args.size ** channel) % args.size) / (args.size - 1)
            target = encode(2 * decode(signal))
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

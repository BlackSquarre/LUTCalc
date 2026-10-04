"""复算旧 LUTCalc 兼容 N-Log 曝光 CUBE；官方算法改用 camera-transfer-reference.py。"""

import argparse
import json
import math
from pathlib import Path


SCENE_SCALE = 0.9
TOE_CUT = 0.328
TOE_OFFSET = 0.0075
TOE_SCALE = 650.1864339 / 1023.0
LOG_SCALE = 150.0
LOG_OFFSET = 619.0
LOG_CUT = 451.7887494 / 1023.0


def cbrt(value):
    return math.copysign(abs(value) ** (1.0 / 3.0), value)


def encode(scene):
    scaled = scene * SCENE_SCALE
    if scaled >= TOE_CUT:
        return (LOG_SCALE * math.log(scaled) + LOG_OFFSET) / 1023.0
    return cbrt(scaled + TOE_OFFSET) * TOE_SCALE


def decode(data):
    if data >= LOG_CUT:
        scaled = math.exp((data * 1023.0 - LOG_OFFSET) / LOG_SCALE)
    else:
        scaled = (data / TOE_SCALE) ** 3 - TOE_OFFSET
    return scaled / SCENE_SCALE


def read_cube(path, expected_size):
    rows = []
    size = None
    for line_number, line in enumerate(path.read_text().splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#") or line.startswith(("TITLE", "DOMAIN_")):
            continue
        if line.startswith("LUT_3D_SIZE "):
            if size is not None:
                raise ValueError("重复 LUT_3D_SIZE")
            size = int(line.split()[1])
            continue
        values = line.split()
        if len(values) != 3:
            raise ValueError(f"第 {line_number} 行节点不是三个通道")
        rgb = [float(value) for value in values]
        if not all(math.isfinite(value) for value in rgb):
            raise ValueError(f"第 {line_number} 行包含非有限数")
        rows.append(rgb)
    if size != expected_size or len(rows) != expected_size ** 3:
        raise ValueError(f"CUBE 形状错误：size={size}, nodes={len(rows)}")
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("cube", type=Path)
    parser.add_argument("--size", type=int, required=True)
    args = parser.parse_args()
    rows = read_cube(args.cube, args.size)
    errors = []
    worst = (-1, -1, -1.0)
    for index, actual in enumerate(rows):
        encoded = [(index // (args.size ** channel) % args.size) / (args.size - 1)
                   for channel in range(3)]
        expected = [encode(decode(value) * 2.0) for value in encoded]
        for channel in range(3):
            error = abs(actual[channel] - expected[channel]) / max(1.0, abs(expected[channel]))
            errors.append(error)
            if error > worst[2]:
                worst = (index, channel, error)
    errors.sort()
    result = {
        "nodes": len(rows),
        "maxScaled": worst[2],
        "worstIndex": worst[0],
        "worstChannel": worst[1],
        "rmsScaled": math.sqrt(math.fsum(value * value for value in errors) / len(errors)),
        "p99Scaled": errors[math.ceil(0.99 * len(errors)) - 1],
        "threshold": 2e-12,
        "reference": "js/gamma.js:LUTGammaNLog legacy coefficients; official Nikon uses separate identity",
    }
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    if result["maxScaled"] > result["threshold"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

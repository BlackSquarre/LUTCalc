#!/usr/bin/env python3
"""Independent verifier for the CIE L* same-space exposure preset."""

from __future__ import annotations

import argparse
import math
import pathlib

DATA_SCALE = 0.85630498533724
DATA_OFFSET = 0.06256109481916
LINEAR_CUT = 216.0 / 24389.0
ENCODED_CUT = 216.0 / 2700.0
LINEAR_SLOPE = 24389.0 / 2700.0


def decode(value: float) -> float:
    legal = (value - DATA_OFFSET) / DATA_SCALE
    return (((legal + 0.16) / 1.16) ** 3
            if legal >= ENCODED_CUT else legal / LINEAR_SLOPE)


def encode(value: float) -> float:
    legal = (1.16 * value ** (1.0 / 3.0) - 0.16
             if value >= LINEAR_CUT else LINEAR_SLOPE * value)
    return legal * DATA_SCALE + DATA_OFFSET


def parse_cube(path: pathlib.Path, size: int) -> list[tuple[float, float, float]]:
    samples: list[tuple[float, float, float]] = []
    declared = None
    for line_no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        if fields[0].upper() == "LUT_3D_SIZE":
            declared = int(fields[1])
            continue
        if fields[0].upper() in {"TITLE", "DOMAIN_MIN", "DOMAIN_MAX"}:
            continue
        if len(fields) != 3:
            raise ValueError(f"line {line_no}: expected RGB sample")
        samples.append(tuple(float(x) for x in fields))
    if declared != size or len(samples) != size ** 3:
        raise ValueError(f"size/sample mismatch: declared={declared}, samples={len(samples)}")
    return samples


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("cube", type=pathlib.Path)
    parser.add_argument("--size", type=int, required=True)
    args = parser.parse_args()
    samples = parse_cube(args.cube, args.size)
    maximum = 0.0
    worst = (0, 0)
    squared = 0.0
    errors: list[float] = []
    for index, sample in enumerate(samples):
        r = index % args.size
        g = (index // args.size) % args.size
        b = index // (args.size * args.size)
        inputs = (r / (args.size - 1), g / (args.size - 1), b / (args.size - 1))
        for channel, (actual, source) in enumerate(zip(sample, inputs)):
            reference = encode(decode(source) * 2.0)
            error = abs(actual - reference) / max(1.0, abs(reference))
            errors.append(error)
            squared += error * error
            if error > maximum:
                maximum, worst = error, (index, channel)
    errors.sort()
    p99 = errors[min(len(errors) - 1, int(math.ceil(0.99 * len(errors)) - 1))]
    rms = math.sqrt(squared / len(errors))
    threshold = 2e-12
    if maximum > threshold:
        raise ValueError(f"maxScaledError={maximum} > {threshold}")
    print({"variant": "cie-lstar", "nodes": len(samples), "maxScaledError": maximum,
           "worstNode": worst[0], "worstChannel": worst[1], "rmsScaledError": rms,
           "p99ScaledError": p99, "threshold": threshold})
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"verify-cie-lstar-cube.py: {exc}")
        raise SystemExit(1)

#!/usr/bin/env python3
"""Independent analytic verifier for the ProPhoto/BBC same-space exposure presets."""

from __future__ import annotations

import argparse
import math
import pathlib


DATA_SCALE = 0.85630498533724
DATA_OFFSET = 0.06256109481916


def decode_prophoto(value: float) -> float:
    linear = (value - DATA_OFFSET) / DATA_SCALE
    return linear / 16.0 if linear < 1.0 / 32.0 else linear ** 1.8


def encode_prophoto(value: float) -> float:
    legal = value * 16.0 if value < 1.0 / 512.0 else value ** (1.0 / 1.8)
    return legal * DATA_SCALE + DATA_OFFSET


def bbc_parameters(name: str) -> tuple[float, float, float]:
    return {
        "bbc": (0.4, -0.02262, 0.037703),
        "bbc04": (0.4, -0.02262, 0.037703),
        "bbc05": (0.5, -0.01011, 0.020202),
        "bbc06": (0.6, -0.00334, 0.008857),
    }[name]


def decode_bbc(value: float, name: str) -> float:
    exponent, offset, cut = bbc_parameters(name)
    legal = (value - DATA_OFFSET) / DATA_SCALE
    encoded_cut = ((cut + offset) / (1.0 + offset)) ** exponent
    return ((1.0 + offset) * legal ** (1.0 / exponent) - offset
            if legal >= encoded_cut else legal / 5.0)


def encode_bbc(value: float, name: str) -> float:
    exponent, offset, cut = bbc_parameters(name)
    legal = (((value + offset) / (1.0 + offset)) ** exponent
             if value > cut else value * 5.0)
    return legal * DATA_SCALE + DATA_OFFSET


def whp283_parameters(name: str) -> float:
    return {"bbc-whp283-400": 0.139401137752,
            "bbc-whp283-800": 0.097401889128}[name]


def decode_whp283(value: float, name: str) -> float:
    m = whp283_parameters(name)
    legal = (value - DATA_OFFSET) / DATA_SCALE
    root = math.sqrt(m)
    n = root / 2.0
    r = root * (1.0 - math.log(root))
    return math.exp((legal - r) / n) if legal > root else legal ** 2.0


def encode_whp283(value: float, name: str) -> float:
    m = whp283_parameters(name)
    root = math.sqrt(m)
    n = root / 2.0
    r = root * (1.0 - math.log(root))
    legal = (n * math.log(value) + r if value > m
             else math.sqrt(value) if value > 0 else 0.0)
    return legal * DATA_SCALE + DATA_OFFSET


def expected(value: float, name: str) -> float:
    if name == "prophoto":
        return encode_prophoto(decode_prophoto(value) * 2.0)
    if name.startswith("bbc-whp283"):
        return encode_whp283(decode_whp283(value, name) * 2.0, name)
    return encode_bbc(decode_bbc(value, name) * 2.0, name)


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
    parser.add_argument("--variant", choices=("prophoto", "bbc", "bbc04", "bbc05", "bbc06", "bbc-whp283-400", "bbc-whp283-800"), required=True)
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
            reference = expected(source, args.variant)
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
    print({"variant": args.variant, "nodes": len(samples), "maxScaledError": maximum,
           "worstNode": worst[0], "worstChannel": worst[1], "rmsScaledError": rms,
           "p99ScaledError": p99, "threshold": threshold})
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"verify-prophoto-bbc-cube.py: {exc}")
        raise SystemExit(1)

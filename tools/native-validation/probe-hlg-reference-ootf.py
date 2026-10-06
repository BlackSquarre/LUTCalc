#!/usr/bin/env python3
"""Independent 90-digit Decimal reference for BT.2100-3 HLG reference OOTF."""
from decimal import Decimal, getcontext
import json

getcontext().prec = 90
D = Decimal

PEAK = D("1000")
GAMMA = D("1.2") + D("0.42") * (PEAK / D("1000")).log10()
LUMA = (D("0.2627"), D("0.6780"), D("0.0593"))


def power(value, exponent):
    if value == 0:
        return D(0)
    return (exponent * value.ln()).exp()


def scalar(value):
    return PEAK * power(value, GAMMA)


def rgb(value):
    y = sum(LUMA[i] * value[i] for i in range(3))
    scale = PEAK * power(y, GAMMA - D(1))
    return tuple(scale * channel for channel in value)


def fmt(values):
    return [format(value, "f") for value in values]


def main():
    scalar_values = [D("0"), D("0.001"), D("0.018"), D("0.18"), D("0.5"), D("1")]
    rgb_values = [
        (D("0"), D("0"), D("0")),
        (D("0.18"), D("0.18"), D("0.18")),
        (D("0.8"), D("-0.1"), D("0.4")),
        (D("1"), D("0"), D("0")),
        (D("0.25"), D("0.5"), D("0.75")),
    ]
    print(json.dumps({
        "algorithm": "bt2100.hlg-reference-ootf.v1",
        "precision": 90,
        "peakLuminanceNits": format(PEAK, "f"),
        "systemGamma": format(GAMMA, "f"),
        "scalar": [{"input": [format(value, "f")], "output": [format(scalar(value), "f")]} for value in scalar_values],
        "rgb": [{"input": fmt(value), "output": fmt(rgb(value))} for value in rgb_values],
    }, indent=2))


if __name__ == "__main__":
    main()

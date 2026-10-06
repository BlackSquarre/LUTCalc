#!/usr/bin/env python3
"""Independent 90-digit Decimal reference for the BT.2100-3 HLG reference EOTF."""

from decimal import Decimal, getcontext
import json

getcontext().prec = 90
D = Decimal

A = D("0.17883277")
B = D("0.28466892")
C = D("0.5") - A * (D(4) * A).ln()
BREAKPOINT = D(1) / D(12)
PEAK = D("1000")
BLACK = D("10")
GAMMA = D("1.2") + D("0.42") * (PEAK / D("1000")).log10()
LUMA = (D("0.2627"), D("0.6780"), D("0.0593"))


def power(value, exponent):
    if value == 0:
        return D(0)
    return (exponent * value.ln()).exp()


def beta(black, peak=PEAK, gamma=GAMMA):
    return (D(3).sqrt() * power(black / peak, D(1) / gamma))


def decode(encoded):
    if encoded <= D("0.5"):
        return encoded * encoded / D(3)
    return (((encoded - C) / A).exp() + B) / D(12)


def encode(scene):
    if scene <= BREAKPOINT:
        return (D(3) * scene).sqrt()
    return A * (D(12) * scene - B).ln() + C


def eotf(encoded, black=BLACK, peak=PEAK, gamma=GAMMA):
    lifted = max(D(0), (D(1) - beta(black, peak, gamma)) * encoded + beta(black, peak, gamma))
    scene = decode(lifted)
    return peak * power(scene, gamma)


def inverse(display, black=BLACK, peak=PEAK, gamma=GAMMA):
    if display <= 0:
        raise ValueError("non-unique zero or negative display domain")
    scene = power(display / peak, D(1) / gamma)
    lifted = encode(scene)
    b = beta(black, peak, gamma)
    return (lifted - b) / (D(1) - b)


def rgb_eotf(encoded, black=BLACK, peak=PEAK, gamma=GAMMA):
    b = beta(black, peak, gamma)
    scenes = tuple(decode(max(D(0), (D(1) - b) * channel + b)) for channel in encoded)
    y = sum(LUMA[i] * scenes[i] for i in range(3))
    scale = peak * power(y, gamma - D(1))
    return tuple(scale * channel for channel in scenes)


def fmt(value):
    return format(value, "f")


def main():
    encoded_values = [D("-0.01"), D("0"), D("0.1"), D("0.5"), D("0.75"), D("1")]
    inverse_values = [eotf(D("-0.01")), eotf(D("0.1")), eotf(D("0.5")), eotf(D("0.75"))]
    rgb_values = (D("0.5"), D("0.75"), D("0.25"))
    values = {
        "algorithm": "bt2100.hlg-reference-eotf.v1",
        "source": "ITU-R BT.2100-3 (02/2025), Table 5, Note 5f and Note 5i",
        "precision": 90,
        "peakLuminanceNits": fmt(PEAK),
        "blackLuminanceNits": fmt(BLACK),
        "systemGamma": fmt(GAMMA),
        "beta": fmt(beta(BLACK)),
        "referenceBlackDisplayNits": fmt(BLACK * BLACK / PEAK),
        "encodedToDisplay": [
            {"encoded": fmt(value), "displayNits": fmt(eotf(value))}
            for value in encoded_values
        ],
        "displayToEncoded": [
            {"displayNits": fmt(value), "encoded": fmt(inverse(value))}
            for value in inverse_values
        ],
        "rgb": {
            "encoded": ["0.5", "0.75", "0.25"],
            "displayNits": [fmt(value) for value in rgb_eotf(rgb_values)],
        },
    }
    print(json.dumps(values, indent=2))


if __name__ == "__main__":
    main()

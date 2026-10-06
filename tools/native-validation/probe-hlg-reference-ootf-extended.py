#!/usr/bin/env python3
"""Independent 90-digit Decimal reference for BT.2100-3 Note 5f extended gamma."""

from decimal import Decimal, getcontext
import json

getcontext().prec = 90
D = Decimal
KAPPA = D("1.111")


def power(value, exponent):
    if value == 0:
        return D(0)
    return (exponent * value.ln()).exp()


def gamma(peak):
    return D("1.2") * power(KAPPA, (peak / D("1000")).ln() / D(2).ln())


def display(scene, peak, system_gamma):
    return peak * power(scene, system_gamma)


def scene(display_value, peak, system_gamma):
    return power(display_value / peak, D(1) / system_gamma)


HLG_A = D("0.17883277")
HLG_B = D("0.28466892")
HLG_C = D("0.5") - HLG_A * (D(4) * HLG_A).ln()


def hlg_decode(encoded):
    if encoded <= D("0.5"):
        return encoded * encoded / D(3)
    return (((encoded - HLG_C) / HLG_A).exp() + HLG_B) / D(12)


def hlg_encode(scene_value):
    if scene_value <= D(1) / D(12):
        return (D(3) * scene_value).sqrt()
    return HLG_A * (D(12) * scene_value - HLG_B).ln() + HLG_C


def beta(black, peak, system_gamma):
    return D(3).sqrt() * power(black / peak, D(1) / system_gamma)


def eotf(encoded, black, peak, system_gamma):
    lift = beta(black, peak, system_gamma)
    scene_value = hlg_decode(max(D(0), (D(1) - lift) * encoded + lift))
    return display(scene_value, peak, system_gamma)


def inverse_eotf(display_value, black, peak, system_gamma):
    lift = beta(black, peak, system_gamma)
    encoded_scene = hlg_encode(scene(display_value, peak, system_gamma))
    return (encoded_scene - lift) / (D(1) - lift)


def rgb_eotf(encoded, black, peak, system_gamma):
    lift = beta(black, peak, system_gamma)
    scenes = tuple(hlg_decode(max(D(0), (D(1) - lift) * channel + lift)) for channel in encoded)
    luminance = D("0.2627") * scenes[0] + D("0.6780") * scenes[1] + D("0.0593") * scenes[2]
    scale = peak * power(luminance, system_gamma - D(1))
    return tuple(scale * channel for channel in scenes)


def fmt(value):
    return format(value, "f")


def main():
    samples = []
    eotf_samples = []
    for peak in [D("100"), D("200"), D("3000"), D("10000")]:
        system_gamma = gamma(peak)
        scenes = [D("0"), D("0.001"), D("0.018"), D("0.18"), D("0.5"), D("1")]
        samples.append({
            "peakLuminanceNits": fmt(peak),
            "systemGamma": fmt(system_gamma),
            "scene": [fmt(value) for value in scenes],
            "display": [fmt(display(value, peak, system_gamma)) for value in scenes],
            "inverse": [fmt(scene(display(value, peak, system_gamma), peak, system_gamma)) for value in scenes],
        })
        black = peak / D("100")
        encoded_values = [D("-0.01"), D("0"), D("0.1"), D("0.5"), D("0.75"), D("1")]
        eotf_samples.append({
            "peakLuminanceNits": fmt(peak),
            "blackLuminanceNits": fmt(black),
            "systemGamma": fmt(system_gamma),
            "beta": fmt(beta(black, peak, system_gamma)),
            "encoded": [fmt(value) for value in encoded_values],
            "display": [fmt(eotf(value, black, peak, system_gamma)) for value in encoded_values],
            "inverse": [fmt(inverse_eotf(eotf(value, black, peak, system_gamma), black, peak, system_gamma))
                        for value in encoded_values if value != D("0")],
            "rgbDisplay": [fmt(value) for value in rgb_eotf(
                (D("0.5"), D("0.75"), D("0.25")), black, peak, system_gamma
            )],
        })
    print(json.dumps({
        "algorithm": "bt2100.hlg-reference-ootf-extended.v1",
        "source": "ITU-R BT.2100-3 (02/2025), Note 5f",
        "precision": 90,
        "kappa": fmt(KAPPA),
        "samples": samples,
        "eotfSamples": eotf_samples,
    }, indent=2))


if __name__ == "__main__":
    main()

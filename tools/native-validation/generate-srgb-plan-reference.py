"""用冻结的 DJI XYZ 矩阵及 W3C sRGB 有理数逆矩阵生成研发参照。"""

import json
import math
import runpy
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
decode = runpy.run_path(str(ROOT / "tools/native-validation/generate-first-chain-reference.py"))["decode"]
INPUT = ROOT / "tests/fixtures/dlog2-reference.json"
OUTPUT = ROOT / "tests/fixtures/native-contracts/srgb-plan-reference.json"
SRGB_INVERSE = [
    Fraction(12831, 3959), Fraction(-329, 214), Fraction(-1974, 3959),
    Fraction(-851781, 878810), Fraction(1648619, 878810), Fraction(36519, 878810),
    Fraction(705, 12673), Fraction(-2585, 12673), Fraction(705, 667),
]


def encode(value, legacy):
    if legacy:
        value /= 0.9
        return 12.92 * value if value < 0.0031308 else 1.055 * value ** (1 / 2.4) - 0.055
    magnitude = abs(value)
    if magnitude <= 0.0031308:
        return 12.92 * value
    return math.copysign(1.055 * magnitude ** (1 / 2.4) - 0.055, value)


def main():
    source = json.loads(INPUT.read_text())
    to_xyz = source["toXYZ"]
    inputs = [[0.1, 0.2, 0.3], [0, 1, 0.5], [-0.1, 0.5, 1.1],
              [0.304985337243402, 0.148314799066323, 0.06256109481915934]]
    cases = []
    for signal in inputs:
        scene = [decode(value) * 2 for value in signal]
        xyz = [math.fsum(to_xyz[row * 3 + col] * scene[col] for col in range(3)) for row in range(3)]
        linear = [math.fsum(float(SRGB_INVERSE[row * 3 + col]) * xyz[col] for col in range(3))
                  for row in range(3)]
        standard = [encode(value, False) for value in linear]
        legacy = [encode(value, True) for value in linear]
        cases.append({
            "input": signal,
            "linearSRGB": linear,
            "standardData": standard,
            "legacyData": legacy,
            "standardVideo10": [(value * 1023 - 64) / 876 for value in standard],
            "standardVideo12": [(value * 4095 - 256) / 3504 for value in standard],
        })
    OUTPUT.write_text(json.dumps({
        "source": "DJI CTL/NumPy frozen XYZ plus W3C CSS Color 4 rational XYZ-to-linear-sRGB matrix",
        "sourceFixture": str(INPUT.relative_to(ROOT)),
        "w3cURL": "https://www.w3.org/TR/2026/CRD-css-color-4-20260913/#predefined-sRGB",
        "scaledThreshold": 2e-12,
        "cases": cases,
    }, indent=2) + "\n")


if __name__ == "__main__":
    main()

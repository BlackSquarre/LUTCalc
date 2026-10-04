"""以 Decimal 80/120 位核验 sRGB 扩展曲线的独立测试点。"""

import json
import math
from decimal import Decimal, localcontext
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "tests/fixtures/native-contracts/srgb-reference.json"
SOURCE = "https://www.w3.org/TR/2026/CRD-css-color-4-20260913/#predefined-sRGB"


def evaluate(value, direction, precision):
    with localcontext() as context:
        context.prec = precision
        x = Decimal.from_float(value)
        absolute = abs(x)
        sign = Decimal(-1) if x < 0 else Decimal(1)
        if direction == "encode":
            if absolute > Decimal("0.0031308"):
                output = sign * (Decimal("1.055") * absolute ** (Decimal(1) / Decimal("2.4")) - Decimal("0.055"))
            else:
                output = Decimal("12.92") * x
        else:
            if absolute <= Decimal("0.04045"):
                output = x / Decimal("12.92")
            else:
                output = sign * ((absolute + Decimal("0.055")) / Decimal("1.055")) ** Decimal("2.4")
        return float(output)


def cases(direction, values):
    result = []
    for value in values:
        lower = evaluate(value, direction, 80)
        higher = evaluate(value, direction, 120)
        if lower != higher:
            raise ValueError(f"precision unstable: {direction} {value}")
        result.append({"input": value, "expected": higher})
    return result


def main():
    linearJoin = 0.0031308
    codeJoin = 0.04045
    linear = [-1, -0.1, -0.01, 0, 0.001, math.nextafter(linearJoin, -math.inf), linearJoin,
              math.nextafter(linearJoin, math.inf), 0.18, 1, 4]
    encoded = [-1, -0.1, -0.04045, 0, 0.02, 0.04015966, 0.0403,
               math.nextafter(codeJoin, -math.inf), codeJoin, math.nextafter(codeJoin, math.inf), 1, 4]
    OUTPUT.write_text(json.dumps({
        "source": SOURCE,
        "algorithmVersion": "srgb.w3c-extended.v1",
        "scaledThreshold": 2e-12,
        "roundingBudget": 5e-15,
        "encode": cases("encode", linear),
        "decode": cases("decode", encoded),
    }, indent=2) + "\n")


if __name__ == "__main__":
    main()

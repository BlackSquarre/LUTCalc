#!/usr/bin/env python3
"""独立高精度 Rec.709-6 前向参照；仅用于研发验证。"""

import json
import math
from decimal import Decimal, localcontext
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "tests/fixtures/native-contracts/rec709-itu-reference.json"


def reference(value: float, precision: int) -> float:
    with localcontext() as context:
        context.prec = precision
        linear = Decimal.from_float(value)
        # Select the branch using the same Double boundary representation as the
        # source value, then evaluate the selected formula at high precision.
        if value >= 0.018:
            encoded = Decimal("1.099") * linear ** Decimal("0.45") - Decimal("0.099")
        else:
            encoded = Decimal("4.5") * linear
        return float(encoded)


def legacy_plan(value: float, precision: int) -> float:
    with localcontext() as context:
        context.prec = precision
        encoded = Decimal.from_float(value)
        if value >= 0.081:
            linear = ((encoded + Decimal("0.099")) / Decimal("1.099")) ** (Decimal(1) / Decimal("0.45"))
        else:
            linear = encoded / Decimal("4.5")
        linear *= 2  # Exposure +1; legacy-to-scene and scene-to-legacy scales cancel.
        if linear >= Decimal("0.018"):
            result = Decimal("1.099") * linear ** Decimal("0.45") - Decimal("0.099")
        else:
            result = Decimal("4.5") * linear
        return float(result)


def main() -> None:
    knee = 0.018
    values = [
        0.0, math.nextafter(0.0, 1.0), 0.001, 0.01,
        math.nextafter(knee, 0.0), knee, math.nextafter(knee, 1.0),
        0.05, 0.18, 0.5, 1.0,
    ]
    cases = []
    for value in values:
        high = reference(value, 120)
        if reference(value, 80) != high:
            raise RuntimeError(f"precision instability at {value!r}")
        cases.append({"input": value, "expected": high})
    plan_cases = []
    for value in [-0.1, 0.0, 0.05, 0.08112, 0.18, 0.5, 0.9, 1.0]:
        high = legacy_plan(value, 120)
        if legacy_plan(value, 80) != high:
            raise RuntimeError(f"plan precision instability at {value!r}")
        plan_cases.append({"input": value, "expected": high})
    OUTPUT.write_text(json.dumps({
        "source": "ITU-R BT.709-6 item 1.2, domain 0 <= L <= 1",
        "algorithmVersion": "rec709.itu-oetf-2015",
        "precision": "Decimal.from_float, 80 and 120 digits agreed after Double rounding",
        "encode": cases,
        "legacySameSpaceExposurePlusOne": plan_cases,
    }, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

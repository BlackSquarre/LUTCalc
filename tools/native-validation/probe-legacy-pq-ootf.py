#!/usr/bin/env python3
"""独立 Decimal 参照：重算旧 PQ OOTF 的分段和单位包装。"""

from decimal import Decimal, getcontext
import json

getcontext().prec = 80

HUNDRED = Decimal("100")
KNEE = Decimal("0.0003024")
TOE_SLOPE = Decimal("267.84")
LOG_SCALE = Decimal("59.5208")
LOG_GAIN = Decimal("1.099")
LOG_OFFSET = Decimal("0.099")
POWER = Decimal("2.4")


def power(value: Decimal, exponent: Decimal) -> Decimal:
    return (value.ln() * exponent).exp()


def forward(value: Decimal, peak: Decimal, scale: Decimal) -> Decimal:
    if value < 0:
        return Decimal(0)
    normalized = value / HUNDRED
    if normalized > KNEE:
        encoded = LOG_GAIN * power(LOG_SCALE * normalized, Decimal("0.45")) - LOG_OFFSET
    else:
        encoded = TOE_SLOPE * max(normalized, Decimal(0))
    return min(peak / HUNDRED, power(encoded, POWER)) * scale


def main() -> None:
    peak = Decimal("1000")
    nits = [forward(Decimal("0.18"), peak, Decimal("100")),
            forward(Decimal("100"), peak, Decimal("100"))]
    normalized = [forward(Decimal("0.18"), peak, Decimal("0.01")),
                  forward(Decimal("100"), peak, Decimal("0.01"))]
    threshold = [
        forward(HUNDRED * KNEE.next_minus(), peak, Decimal("100")),
        forward(HUNDRED * KNEE, peak, Decimal("100")),
        forward(HUNDRED * KNEE.next_plus(), peak, Decimal("100")),
    ]
    print(json.dumps({
        "precision": getcontext().prec,
        "nits": [format(value, "f") for value in nits],
        "normalized": [format(value, "f") for value in normalized],
        "threshold": [format(value, "f") for value in threshold],
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

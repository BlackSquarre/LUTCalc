#!/usr/bin/env python3
"""独立 80 位 Decimal 参照：GoPro GP-Log2 base-600 标量。"""

from decimal import Decimal, getcontext
import json

getcontext().prec = 80
BASE = Decimal("600")
DENOMINATOR = BASE - Decimal(1)


def power(value: Decimal, exponent: Decimal) -> Decimal:
    return (value.ln() * exponent).exp()


def encode(value: Decimal) -> Decimal:
    return ((DENOMINATOR * value + Decimal(1)).ln() / BASE.ln())


def decode(value: Decimal) -> Decimal:
    return (power(BASE, value) - Decimal(1)) / DENOMINATOR


def main() -> None:
    values = [Decimal("0"), Decimal("0.18"), Decimal("0.5"), Decimal("1")]
    encoded = [encode(value) for value in values]
    decoded = [decode(value) for value in encoded]
    print(json.dumps({
        "precision": getcontext().prec,
        "encoded": [format(value, ".50f") for value in encoded],
        "decoded": [format(value, ".50f") for value in decoded],
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

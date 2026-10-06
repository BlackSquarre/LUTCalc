#!/usr/bin/env python3
"""独立 Decimal 参照：CIE 1976 Delta E*ab 欧氏距离。"""

from decimal import Decimal, getcontext
import json

getcontext().prec = 80


def main() -> None:
    first = (Decimal("0.42"), Decimal("12"), Decimal("-8"))
    second = (Decimal("0.57"), Decimal("3"), Decimal("4"))
    deltas = [a - b for a, b in zip(first, second)]
    scaled_deltas = [deltas[0] * Decimal("100"), deltas[1], deltas[2]]
    distance = sum(value * value for value in scaled_deltas).sqrt()
    print(json.dumps({
        "precision": getcontext().prec,
        "metric": "CIE 1976 Delta E*ab",
        "normalizedDelta": [format(value, "f") for value in deltas],
        "standardDelta": [format(value, "f") for value in scaled_deltas],
        "distance": format(distance, "f"),
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

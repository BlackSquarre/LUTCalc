#!/usr/bin/env python3
"""独立 Decimal 复核 ST 2084 绝对 PQ 与历史 PQ OOTF 的单位边界。"""

from decimal import Decimal, getcontext
import json

getcontext().prec = 80

D = Decimal
M1 = D(2610) / D(16384)
M2 = D(2523) / D(32)
C1 = D(3424) / D(4096)
C2 = D(2413) / D(128)
C3 = D(2392) / D(128)


def pq_encode_absolute(nits: D) -> D:
    luminance = nits / D(10000)
    powered = luminance ** M1
    return ((C1 + C2 * powered) / (D(1) + C3 * powered)) ** M2


def legacy_forward(value: D, peak: D = D(1000)) -> D:
    x = value / D(100)
    knee = D("0.0003024")
    if x > knee:
        encoded = D("1.099") * (D("59.5208") * x) ** D("0.45") - D("0.099")
    else:
        encoded = D("267.84") * max(x, D(0))
    return min(peak / D(100), encoded ** D("2.4")) * D(100)


def main() -> None:
    input_value = D("0.18")
    lower = legacy_forward(D(100) * D("0.0003024").next_minus())
    upper = legacy_forward(D(100) * D("0.0003024").next_plus())
    result = {
        "precision": 80,
        "input": str(input_value),
        "pqAbsoluteNits": "1800",
        "pqCode": str(pq_encode_absolute(D(1800))),
        "legacyNits": str(legacy_forward(input_value)),
        "legacyKneeLowerNits": str(lower),
        "legacyKneeUpperNits": str(upper),
        "legacyKneeJumpNits": str(upper - lower),
    }
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()

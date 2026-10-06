#!/usr/bin/env python3
"""独立 Decimal 参照：计算旧 CAT 模型的 D65→D50 锥响应适应样本。"""

from decimal import Decimal, getcontext
import json

getcontext().prec = 90
D = Decimal

MODELS = {
    "cieCAT02": [
        "0.7328", "0.4296", "-0.1624", "-0.7036", "1.6975", "0.0061",
        "0.0030", "0.0136", "0.9834",
    ],
    "bradford": [
        "0.8951", "0.2664", "-0.1614", "-0.7502", "1.7135", "0.0367",
        "0.0389", "-0.0685", "1.0296",
    ],
    "cieCAT97s": [
        "0.8562", "0.3372", "-0.1934", "-0.8360", "1.8327", "0.0033",
        "0.0357", "-0.0469", "1.0112",
    ],
    "vonKries": [
        "0.40024", "0.7076", "-0.08081", "-0.2263", "1.16532", "0.0457",
        "0", "0", "0.91822",
    ],
    "sharp": [
        "1.2694", "-0.0988", "-0.1706", "-0.8364", "1.8006", "0.0357",
        "0.0297", "-0.0315", "1.0018",
    ],
    "cmccat2000": [
        "0.7982", "0.3389", "-0.1371", "-0.5918", "1.5512", "0.0406",
        "0.0008", "0.0239", "0.9753",
    ],
    "biancoBS": [
        "0.8752", "0.2787", "-0.1539", "-0.8904", "1.8709", "0.0195",
        "-0.0061", "0.0162", "0.9899",
    ],
    "biancoBSPC": [
        "0.6489", "0.3915", "-0.0404", "-0.3775", "1.3055", "0.0720",
        "-0.0271", "0.0888", "0.9383",
    ],
    "xyzScaling": ["1", "0", "0", "0", "1", "0", "0", "0", "1"],
}


def mul(a, b):
    return [
        sum(a[row * 3 + k] * b[k * 3 + col] for k in range(3))
        for row in range(3) for col in range(3)
    ]


def inv(a):
    aug = [a[row * 3 : row * 3 + 3] + [D(int(row == col)) for col in range(3)] for row in range(3)]
    for col in range(3):
        pivot = max(range(col, 3), key=lambda row: abs(aug[row][col]))
        aug[col], aug[pivot] = aug[pivot], aug[col]
        divisor = aug[col][col]
        for j in range(6):
            aug[col][j] /= divisor
        for row in range(3):
            if row == col:
                continue
            factor = aug[row][col]
            for j in range(6):
                aug[row][j] -= factor * aug[col][j]
    return [aug[row][3 + col] for row in range(3) for col in range(3)]


def apply(a, v):
    return [sum(a[row * 3 + col] * v[col] for col in range(3)) for row in range(3)]


def xyz(x, y):
    return [x / y, D(1), (D(1) - x - y) / y]


def main():
    source = xyz(D("0.3127"), D("0.3290"))
    destination = xyz(D("0.3457"), D("0.3585"))
    sample = [D("0.25"), D("0.4"), D("0.1")]
    result = {}
    for name, raw in MODELS.items():
        cone = [D(value) for value in raw]
        src = apply(cone, source)
        dst = apply(cone, destination)
        diagonal = [
            dst[0] / src[0], D(0), D(0),
            D(0), dst[1] / src[1], D(0),
            D(0), D(0), dst[2] / src[2],
        ]
        adaptation = mul(mul(inv(cone), diagonal), cone)
        result[name] = {
            "matrix": [str(value) for value in adaptation],
            "sample": [str(value) for value in apply(adaptation, sample)],
        }
    print(json.dumps(result, indent=2, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()

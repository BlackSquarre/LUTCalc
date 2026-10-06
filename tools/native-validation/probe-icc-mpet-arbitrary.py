#!/usr/bin/env python3
"""ICC mpet 任意设备通道维度的独立 Decimal 参照。"""

from decimal import Decimal, getcontext
import hashlib
import json
from pathlib import Path

getcontext().prec = 90


def matrix(values, vector, input_channels, output_channels):
    result = []
    for row in range(output_channels):
        start = row * (input_channels + 1)
        result.append(
            sum(values[start + column] * vector[column] for column in range(input_channels))
            + values[start + input_channels]
        )
    return result


def clut4_identity(vector):
    """2^4 grid, first input channel fastest, output is channels 0..2."""
    result = [Decimal(0), Decimal(0), Decimal(0)]
    positions = vector
    low = [int(value) for value in positions]
    fraction = [value - Decimal(index) for value, index in zip(positions, low)]
    for mask in range(16):
        index = 0
        stride = 1
        weight = Decimal(1)
        for axis in range(4):
            upper = bool(mask & (1 << axis))
            coordinate = 1 if upper else low[axis]
            index += coordinate * stride
            stride *= 2
            weight *= fraction[axis] if upper else (Decimal(1) - fraction[axis])
        # The synthetic grid stores the first three binary axes as outputs.
        for channel in range(3):
            result[channel] += Decimal((index >> channel) & 1) * weight
    return result


def main():
    device = [Decimal("0.1"), Decimal("0.2"), Decimal("0.3"), Decimal("0.4")]
    d2b_values = [
        Decimal("1"), Decimal("2"), Decimal("3"), Decimal("4"), Decimal("0"),
        Decimal("0"), Decimal("1"), Decimal("0"), Decimal("0"), Decimal("0.5"),
        Decimal("0"), Decimal("0"), Decimal("1"), Decimal("0"), Decimal("-0.25"),
    ]
    b2d_values = [
        Decimal("1"), Decimal("0"), Decimal("0"), Decimal("0"),
        Decimal("0"), Decimal("1"), Decimal("0"), Decimal("0"),
        Decimal("0"), Decimal("0"), Decimal("1"), Decimal("0"),
        Decimal("1"), Decimal("1"), Decimal("1"), Decimal("0"),
    ]
    d2b = matrix(d2b_values, device, 4, 3)
    b2d_input = [Decimal("0.1"), Decimal("0.2"), Decimal("0.3")]
    b2d = matrix(b2d_values, b2d_input, 3, 4)
    clut = clut4_identity([Decimal("0.25"), Decimal("0.5"), Decimal("0.75"), Decimal("1")])
    result = {
        "reference": "ICC.1:2022-05 §10.16.2.1-§10.16.2.4, Table 62/63",
        "precision": "Decimal(90), synthetic 4-channel CMYK dimensions",
        "d2b_device": [str(value) for value in device],
        "d2b_matrix_xyz": [str(value) for value in d2b],
        "d2b_clut_xyz": [str(value) for value in clut],
        "b2d_xyz": [str(value) for value in b2d_input],
        "b2d_device": [str(value) for value in b2d],
    }
    output = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    artifact = Path("docs/native-validation/artifacts/2026-10-05-icc-mpet-arbitrary")
    artifact.mkdir(parents=True, exist_ok=True)
    path = artifact / "decimal-reference.json"
    path.write_text(output, encoding="utf-8")
    print(output, end="")
    print(f"sha256={hashlib.sha256(output.encode()).hexdigest()}")


if __name__ == "__main__":
    main()

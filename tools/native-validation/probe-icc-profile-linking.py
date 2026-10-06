#!/usr/bin/env python3
"""ICC MPE profile linking arbitrary-device-channel Decimal(90) reference."""

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


def main():
    xyz_source = [Decimal("0.2"), Decimal("0.3"), Decimal("0.4")]
    xyz_d2b = [
        Decimal("1"), Decimal("0"), Decimal("0"), Decimal("0"),
        Decimal("0"), Decimal("1"), Decimal("0"), Decimal("0"),
        Decimal("0"), Decimal("0"), Decimal("1"), Decimal("0"),
    ]
    xyz_b2d = [
        Decimal("1"), Decimal("0"), Decimal("0"), Decimal("0"),
        Decimal("0"), Decimal("1"), Decimal("0"), Decimal("0"),
        Decimal("0"), Decimal("0"), Decimal("1"), Decimal("0"),
        Decimal("0.25"), Decimal("0.5"), Decimal("0.75"), Decimal("0"),
    ]

    lab_source = [Decimal("0.5"), Decimal("0.4"), Decimal("0.6"), Decimal("0.25")]
    lab_d2b = [
        Decimal("100"), Decimal("0"), Decimal("0"), Decimal("0"), Decimal("0"),
        Decimal("0"), Decimal("255"), Decimal("0"), Decimal("0"), Decimal("-128"),
        Decimal("0"), Decimal("0"), Decimal("255"), Decimal("0"), Decimal("-128"),
    ]
    lab_b2d = [
        Decimal("0.01"), Decimal("0"), Decimal("0"), Decimal("0"),
        Decimal("0"), Decimal(1) / Decimal(255), Decimal("0"), Decimal(128) / Decimal(255),
        Decimal("0"), Decimal("0"), Decimal(1) / Decimal(255), Decimal(128) / Decimal(255),
    ]
    lab_pcs = matrix(lab_d2b, lab_source, 4, 3)
    lab_target = matrix(lab_b2d, lab_pcs, 3, 3)

    result = {
        "reference": "ICC.1:2022-05 §6.3.4, §10.16; D2B3/B2D3 device-channel route",
        "precision": "Decimal(90), synthetic XYZ and Lab profile pairs",
        "xyz_source_device": [str(value) for value in xyz_source],
        "xyz_pcs": [str(value) for value in matrix(xyz_d2b, xyz_source, 3, 3)],
        "xyz_target_device": [
            str(value) for value in matrix(xyz_b2d, matrix(xyz_d2b, xyz_source, 3, 3), 3, 4)
        ],
        "lab_source_device": [str(value) for value in lab_source],
        "lab_pcs_float_values": [str(value) for value in lab_pcs],
        "lab_target_device": [str(value) for value in lab_target],
    }
    output = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    artifact = Path("docs/native-validation/artifacts/2026-10-05-icc-profile-linking")
    artifact.mkdir(parents=True, exist_ok=True)
    path = artifact / "decimal-reference.json"
    path.write_text(output, encoding="utf-8")
    print(output, end="")
    print(f"sha256={hashlib.sha256(output.encode()).hexdigest()}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""ICC float32 PCS Lab MPE 的独立 Decimal 参照。"""

from decimal import Decimal, getcontext
import hashlib
import json
from pathlib import Path
import struct

getcontext().prec = 90


def f32(value: str) -> Decimal:
    bits = struct.pack(">f", float(value))
    return Decimal(str(struct.unpack(">f", bits)[0]))


def mat(values, vector):
    return [
        sum(Decimal(str(values[row * 4 + col])) * vector[col] for col in range(3))
        + Decimal(str(values[row * 4 + 3]))
        for row in range(3)
    ]


def main() -> None:
    d2b_matrix = [Decimal("100"), Decimal("0"), Decimal("0"), Decimal("0"),
                  Decimal("0"), Decimal("255"), Decimal("0"), Decimal("-128"),
                  Decimal("0"), Decimal("0"), Decimal("255"), Decimal("-128")]
    device = [Decimal("0.5"), Decimal("0.4"), Decimal("0.6")]
    pcs_lab = mat(d2b_matrix, device)
    decoded = [pcs_lab[0] / Decimal("100"), pcs_lab[1], pcs_lab[2]]

    b2d_matrix = [f32("0.01"), Decimal("0"), Decimal("0"), Decimal("0"),
                  Decimal("0"), f32(str(1 / 255)), Decimal("0"), f32(str(128 / 255)),
                  Decimal("0"), Decimal("0"), f32(str(1 / 255)), f32(str(128 / 255))]
    lab = [Decimal("0.25") * Decimal("100"), Decimal("12"), Decimal("-20")]
    encoded_device = mat(b2d_matrix, lab)

    # The link case runs D2B followed by B2D with direct float32 Lab values.
    linked = mat(b2d_matrix, pcs_lab)
    expected = linked
    result = {
        "reference": "ICC.1:2022-05 §6.3.4.2, §10.16 Table 60/61",
        "precision": "Decimal(90), float32 parameter quantization mirrored with IEEE-754",
        "d2b_device": [str(v) for v in device],
        "d2b_pcs_lab": [str(v) for v in pcs_lab],
        "d2b_decoded_lab": [str(v) for v in decoded],
        "b2d_lab_input": [str(v) for v in lab],
        "b2d_device_output": [str(v) for v in encoded_device],
        "linked_device_output": [str(v) for v in expected],
    }
    output = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    artifact = Path("docs/native-validation/artifacts/2026-10-05-icc-mpet-lab")
    artifact.mkdir(parents=True, exist_ok=True)
    path = artifact / "decimal-reference.json"
    path.write_text(output, encoding="utf-8")
    print(output, end="")
    print(f"sha256={hashlib.sha256(output.encode()).hexdigest()}")


if __name__ == "__main__":
    main()

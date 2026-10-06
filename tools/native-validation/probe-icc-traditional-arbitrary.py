#!/usr/bin/env python3
"""传统 ICC mft/mAB/mBA 任意设备通道的 Decimal(90) 参照。"""

from decimal import Decimal, getcontext
import hashlib
import json
from pathlib import Path

getcontext().prec = 90


def clut_identity(device, output_count):
    """Identity CLUT: first input axes feed matching output channels."""
    result = []
    for channel in range(output_count):
        result.append(device[channel] if channel < len(device) else Decimal("0"))
    return result


def link(source):
    return clut_identity(clut_identity(source, 3), 4)


def main():
    source = [Decimal("0.2"), Decimal("0.4"), Decimal("0.6"), Decimal("0.8")]
    target = link(source)
    result = {
        "reference": "ICC.1:2022-05 §10.10, §10.11, §10.12, §10.13",
        "precision": "Decimal(90)",
        "route": "traditional mft1/mft2/mAB/mBA arbitrary device arrays",
        "source_device_cmyk": [str(value) for value in source],
        "pcs_xyz_normalized": [str(value) for value in clut_identity(source, 3)],
        "target_device_cmyk": [str(value) for value in target],
        "pcs_lab_normalized": [str(value) for value in clut_identity(source, 3)],
        "mft_and_mab_expected": [str(value) for value in target],
        "mft1_xyz_status": "rejected: ICC defines no 8-bit PCSXYZ encoding",
        "matrix_status": "identity required for non-PCS device dimensions",
    }
    output = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    artifact = Path("docs/native-validation/artifacts/2026-10-05-icc-traditional-arbitrary")
    artifact.mkdir(parents=True, exist_ok=True)
    path = artifact / "decimal-reference.json"
    path.write_text(output, encoding="utf-8")
    print(output, end="")
    print(f"sha256={hashlib.sha256(output.encode()).hexdigest()}")


if __name__ == "__main__":
    main()

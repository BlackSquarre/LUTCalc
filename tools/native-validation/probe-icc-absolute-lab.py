#!/usr/bin/env python3
"""ICC 传统 Lab PCS absolute linking 的独立 Decimal 参照。"""

from decimal import Decimal, getcontext
import hashlib
import json
from pathlib import Path

getcontext().prec = 90
D = Decimal

WHITE = [D("0.964212"), D("1"), D("0.825188")]
SLOPE = D(24389) / D(2700)
LINEAR_CUT = D(216) / D(24389)
F_CUT = D(6) / D(29)


def inverse_f(value: D) -> D:
    return value ** D(3) if value >= F_CUT else (D("1.16") * value - D("0.16")) / SLOPE


def forward_f(value: D) -> D:
    return value ** (D(1) / D(3)) if value >= LINEAR_CUT else (SLOPE * value + D("0.16")) / D("1.16")


def lab_to_xyz(encoded) -> list[D]:
    l_star, a_star, b_star = encoded[0], encoded[1] * D(255) - D(128), encoded[2] * D(255) - D(128)
    fy = (l_star + D("0.16")) / D("1.16")
    fx = fy + a_star / D(5)
    fz = fy - b_star / D(2)
    return [inverse_f(fx) * WHITE[0], inverse_f(fy) * WHITE[1], inverse_f(fz) * WHITE[2]]


def xyz_to_lab(xyz) -> list[D]:
    fx, fy, fz = [forward_f(value / white) for value, white in zip(xyz, WHITE)]
    return [D("1.16") * fy - D("0.16"), (D(5) * (fx - fy) + D(128)) / D(255),
            (D(2) * (fy - fz) + D(128)) / D(255)]


def main() -> None:
    device = [D("0.5"), D("0.5"), D("0.5")]
    source_white = [D("0.8"), D("1.1"), D("0.9")]
    target_white = [D("1.2"), D("0.9"), D("1.5")]
    relative_xyz = lab_to_xyz(device)
    absolute_xyz = [value * source / target for value, source, target in
                    zip(relative_xyz, source_white, target_white)]
    expected = xyz_to_lab(absolute_xyz)
    result = {
        "reference": "ICC.1:2022-05 §6.3.2.2 公式 (1)–(6)、§6.3.2.3 公式 (7)–(9)",
        "precision": "Python Decimal 90 位；PCS Lab 使用当前原生 D50 常量",
        "device_input": [str(value) for value in device],
        "source_media_white": [str(value) for value in source_white],
        "target_media_white": [str(value) for value in target_white],
        "relative_pcs_xyz": [str(value) for value in relative_xyz],
        "absolute_pcs_xyz": [str(value) for value in absolute_xyz],
        "expected_target_lab_encoded": [str(value) for value in expected],
    }
    output = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    artifact = Path("docs/native-validation/artifacts/2026-10-05-icc-absolute-lab")
    artifact.mkdir(parents=True, exist_ok=True)
    path = artifact / "decimal-reference.json"
    path.write_text(output, encoding="utf-8")
    print(output, end="")
    print(f"sha256={hashlib.sha256(output.encode()).hexdigest()}")


if __name__ == "__main__":
    main()

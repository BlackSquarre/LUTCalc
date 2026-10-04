#!/usr/bin/env python3
"""Independent Decimal reference check for the native CIELAB pre-contract."""
from __future__ import annotations

import json
import math
import subprocess
import sys
import tempfile
from decimal import Decimal, getcontext
from pathlib import Path

getcontext().prec = 50


def cube_root(value: Decimal) -> Decimal:
    if value == 0:
        return Decimal(0)
    sign = Decimal(-1) if value < 0 else Decimal(1)
    return sign * (abs(value) ** (Decimal(1) / Decimal(3)))


def reference(xyz: tuple[Decimal, Decimal, Decimal], white: tuple[Decimal, Decimal, Decimal]) -> list[float]:
    cut = Decimal(216) / Decimal(24389)
    slope = Decimal(24389) / Decimal(2700)
    def f(value: Decimal) -> Decimal:
        return cube_root(value) if value >= cut else (slope * value + Decimal("0.16")) / Decimal("1.16")
    fx, fy, fz = (f(value / w) for value, w in zip(xyz, white))
    return [float(Decimal("1.16") * fy - Decimal("0.16")), float(Decimal(5) * (fx - fy)), float(Decimal(2) * (fy - fz))]


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    package = root / "Native/Packages/LUTKit"
    binary = package / ".build/release/LUTCIELABChecks"
    subprocess.run(["swift", "build", "--package-path", str(package), "--configuration", "release", "--product", "LUTCIELABChecks"], check=True)
    for name, white in (("d50", (Decimal("0.964212"), Decimal(1), Decimal("0.825188"))), ("d65", (Decimal("0.950489"), Decimal(1), Decimal("1.088840")))):
        samples = []
        for n in (33, 65):
            for i in range(n):
                x = Decimal("-0.1") + Decimal("1.6") * Decimal(i) / Decimal(n - 1)
                for j in range(n):
                    y = Decimal("-0.1") + Decimal("1.6") * Decimal(j) / Decimal(n - 1)
                    for k in range(n):
                        z = Decimal("-0.1") + Decimal("1.6") * Decimal(k) / Decimal(n - 1)
                        xyz = (x, y, z)
                        samples.append({"xyz": [float(x), float(y), float(z)], "lab": reference(xyz, white)})
        fixture = {"white": name, "samples": samples}
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as handle:
            json.dump(fixture, handle, separators=(",", ":"))
            path = handle.name
        try:
            result = subprocess.run([str(binary), path], text=True, capture_output=True)
            sys.stdout.write(f"{name}: {result.stdout}")
            if result.returncode:
                sys.stderr.write(result.stderr)
                return result.returncode
        finally:
            Path(path).unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

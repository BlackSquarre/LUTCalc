#!/usr/bin/env python3
"""用 Python Decimal 独立核对 ITU Proposal legacy 曝光 CUBE。"""

import argparse
import json
from decimal import Decimal, getcontext
from pathlib import Path

getcontext().prec = 90
D = Decimal
DATA_SCALE = D("0.85630498533724")
DATA_OFFSET = D("0.06256109481916")
PARAMETERS = {
    "400": D("0.12314858"),
    "800": D("0.083822216783"),
}


def encode_legal(value, knee):
    n = D("0.45") * D("1.0993") * knee ** D("0.45")
    r = D("1.0993") * knee ** D("0.45") * (
        D(1) - D("0.45") * knee.ln()
    ) - D("0.0993")
    if value > knee:
        return n * value.ln() + r
    if value >= D("0.0181"):
        return D("1.0993") * value ** D("0.45") - D("0.0993")
    return D("4.5") * value


def decode_legal(value, knee):
    n = D("0.45") * D("1.0993") * knee ** D("0.45")
    r = D("1.0993") * knee ** D("0.45") * (
        D(1) - D("0.45") * knee.ln()
    ) - D("0.0993")
    knee_encoded = D("1.0993") * knee ** D("0.45") - D("0.0993")
    if value > knee_encoded:
        return ((value - r) / n).exp()
    if value >= D("0.08145"):
        return ((value + D("0.0993")) / D("1.0993")) ** (D(1) / D("0.45"))
    return value / D("4.5")


def expected(encoded, knee):
    legal = (encoded - DATA_OFFSET) / DATA_SCALE
    exposed = decode_legal(legal, knee) * D(2)
    output_legal = encode_legal(exposed, knee)
    return output_legal * DATA_SCALE + DATA_OFFSET


def read_cube(path):
    values = []
    size = None
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[0] == "LUT_3D_SIZE":
            size = int(parts[1])
        elif len(parts) == 3:
            try:
                values.append(tuple(D(part) for part in parts))
            except Exception:
                continue
    if size is None or len(values) != size ** 3:
        raise ValueError(f"{path}: 节点数与 LUT_3D_SIZE 不匹配")
    return size, values


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("cubes", nargs="+", help="格式为 VARIANT:PATH，例如 400:/tmp/a.cube")
    args = parser.parse_args()
    reports = []
    for item in args.cubes:
        variant, path = item.split(":", 1)
        knee = PARAMETERS[variant]
        size, samples = read_cube(path)
        maximum = D(0)
        worst = None
        index = 0
        references = [expected(D(r) / D(size - 1), knee) for r in range(size)]
        for b in range(size):
            for g in range(size):
                for r in range(size):
                    sources = (r, g, b)
                    for channel, actual in enumerate(samples[index]):
                        reference = references[sources[channel]]
                        error = abs(actual - reference) / max(D(1), abs(reference))
                        if error > maximum:
                            maximum = error
                            worst = [r, g, b, channel]
                    index += 1
        reports.append({
            "variant": variant,
            "size": size,
            "nodes": len(samples),
            "maximumScaledError": str(maximum),
            "worst": worst,
            "threshold": "2e-12",
            "passed": maximum <= D("2e-12"),
            "path": str(Path(path)),
        })
    print(json.dumps(reports, ensure_ascii=False, indent=2))
    if not all(item["passed"] for item in reports):
        raise SystemExit(1)


if __name__ == "__main__":
    main()

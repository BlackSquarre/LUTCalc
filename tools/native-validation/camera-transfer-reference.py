"""以 90 位 Decimal 独立验收现有 Nikon N-Log/Cineon 四个算法身份。"""

import argparse
from decimal import Decimal as D, getcontext
import json
import math
from pathlib import Path

getcontext().prec = 90
IDS = ["nikon.nlog.v1", "nikon.nlog.lutcalc-legacy.v1",
       "cineon.v1", "cineon.lutcalc-legacy.v1"]
N = D(1023)
BLACK = D(10) ** ((D(95) - 685) / 300)
P0 = (D(10) ** (-D(685) / 300) - BLACK) / (1 - BLACK) / D("0.9")
D0 = ((D(10) ** ((D("0.0001") * N - 685) / 300) - BLACK) /
      (1 - BLACK) / D("0.9") - P0) / D("0.0001")


def cube_root(x):
    if x == 0:
        return D(0)
    return (abs(x).ln() / 3).exp().copy_sign(x)


def decode(identifier, x):
    if identifier.startswith("nikon"):
        legacy = "legacy" in identifier
        coefficient = D("650.1864339") if legacy else D(650)
        cut = D("451.7887494") / N if legacy else D(452) / N
        y = (x * N / coefficient) ** 3 - D("0.0075") if float(x) < float(cut) else ((x * N - 619) / 150).exp()
        return y / D("0.9") if legacy else y
    if "legacy" in identifier and x < 0:
        return x * D0 + P0
    y = (D(10) ** ((N * x - 685) / 300) - BLACK) / (1 - BLACK)
    return y / D("0.9") if "legacy" in identifier else y


def encode(identifier, x):
    if identifier.startswith("nikon"):
        legacy = "legacy" in identifier
        y = x * D("0.9") if legacy else x
        coefficient = D("650.1864339") if legacy else D(650)
        return coefficient * cube_root(y + D("0.0075")) / N if float(y) < 0.328 else (150 * y.ln() + 619) / N
    if "legacy" in identifier and float(x) < float(P0):
        return (x - P0) / D0
    y = x * D("0.9") if "legacy" in identifier else x
    operand = y * (1 - BLACK) + BLACK
    if operand <= 0:
        return None
    return (685 + 300 * operand.log10()) / N


def plan(identifier, x):
    scene = decode(identifier, x)
    if "legacy" in identifier:
        scene *= D("0.9")
    scene *= 2
    # Official Cineon cannot encode all negative full-code exposure samples.
    # Its validation preset intentionally outputs linear data, with no clamp.
    if identifier == "cineon.v1":
        return scene
    return encode(identifier, scene / D("0.9") if "legacy" in identifier else scene)


def fixture():
    variants = []
    for identifier in IDS:
        inputs = [-0.1, 0, 0.001, 0.18, 0.2, 0.328, 0.328 / 0.9, 1, 4, 16]
        cutoff = float(P0) if identifier.startswith("cineon") else (0.328 / 0.9 if "legacy" in identifier else 0.328)
        inputs += [math.nextafter(cutoff, -math.inf), cutoff, math.nextafter(cutoff, math.inf)]
        encoded = []
        for value in inputs:
            result = encode(identifier, D.from_float(value))
            encoded.append({"input": value, "output": str(result) if result is not None else None})
        # Exhaustive 10/12-bit normalized data, plus negative/HDR and branch neighbours.
        data = [code / maximum for maximum in [1023, 4095] for code in range(maximum + 1)] + [-0.1, 1.1]
        cut = 452 / 1023 if identifier == IDS[0] else 451.7887494 / 1023 if identifier == IDS[1] else 0.0
        data += [math.nextafter(cut, -math.inf), cut, math.nextafter(cut, math.inf)]
        decoded = [{"input": value, "output": str(decode(identifier, D.from_float(value)))} for value in data]
        variants.append({"id": identifier, "encode": encoded, "decode": decoded})
    return {"precision": 90, "threshold": 2e-12, "variants": variants}


def verify_cube(path, size, identifier):
    rows = []
    declared = None
    for line in path.read_text().splitlines():
        tokens = line.split()
        if not tokens or tokens[0] in ["TITLE", "DOMAIN_MIN", "DOMAIN_MAX"] or line.startswith("#"):
            continue
        if tokens[0] == "LUT_3D_SIZE":
            if declared is not None:
                raise ValueError("重复网格尺寸")
            declared = int(tokens[1])
        else:
            if len(tokens) != 3:
                raise ValueError("节点须为三个通道")
            rows.append([float(x) for x in tokens])
    if declared != size or len(rows) != size ** 3:
        raise ValueError("网格尺寸或节点数不匹配")
    # Each channel is independent, so only 'size' high-precision evaluations
    # are needed; every exported node and channel is still checked.
    targets = [float(plan(identifier, D.from_float(i / (size - 1)))) for i in range(size)]
    errors = []
    for index, row in enumerate(rows):
        for channel, actual in enumerate(row):
            if not math.isfinite(actual):
                raise ValueError("非有限输出")
            expected = targets[index // size ** channel % size]
            errors.append(abs(actual - expected) / max(1, abs(expected)))
    errors.sort()
    report = {"id": identifier, "nodes": len(rows), "channels": len(errors), "maxScaled": errors[-1],
              "rmsScaled": math.sqrt(math.fsum(x * x for x in errors) / len(errors)),
              "p99Scaled": errors[math.ceil(len(errors) * .99) - 1], "threshold": 2e-12, "decimalPrecision": 90}
    if report["maxScaled"] > report["threshold"]:
        raise ValueError(report)
    return report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixture", type=Path)
    parser.add_argument("--cube", type=Path)
    parser.add_argument("--size", type=int)
    parser.add_argument("--id", choices=IDS)
    args = parser.parse_args()
    if args.fixture:
        args.fixture.write_text(json.dumps(fixture(), ensure_ascii=False, separators=(",", ":")) + "\n")
        print(json.dumps({"path": str(args.fixture), "variants": 4, "precision": 90}, ensure_ascii=False))
    elif args.cube and args.size and args.id:
        print(json.dumps(verify_cube(args.cube, args.size, args.id), ensure_ascii=False, sort_keys=True))
    else:
        parser.error("需提供 --fixture 或 --cube/--size/--id")


if __name__ == "__main__":
    main()

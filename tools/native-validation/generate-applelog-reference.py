"""依据 ACES Apple 双版本 CTL，以 Decimal 独立生成研发公式和矩阵参照。"""

import argparse
import hashlib
import importlib.util
import json
import math
from decimal import Decimal as D, localcontext
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RESEARCH = ROOT / "research/colour/2026-09-24"
OUTPUT = ROOT / "tests/fixtures/native-contracts/applelog-aces-reference.json"
MATRIX_HELPER = ROOT / "tools/native-validation/generate-vlog-reference.py"
spec = importlib.util.spec_from_file_location("reference_matrix", MATRIX_HELPER)
matrix_helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(matrix_helper)

R0 = D("-0.05641088")
RT = D("0.01")
C = D("47.28711236")
B = D("0.00964052")
G = D("0.08550479")
DELTA = D("0.69336945")
PT = C * (RT - R0) ** 2
DOUBLE_PT = 47.28711236 * (0.01 - (-0.05641088)) ** 2


def encode(value):
    if value >= D.from_float(0.01):
        return G * ((value + B).ln() / D(2).ln()) + DELTA
    if value >= D.from_float(-0.05641088):
        return C * (value - R0) ** 2
    return D(0)


def decode(value):
    if value >= D.from_float(DOUBLE_PT):
        return (D(2) ** ((value - DELTA) / G)) - B
    if value >= 0:
        return (value / C).sqrt() + R0
    return R0


def conversion(variant):
    source_white = ("0.3127", "0.3290")
    target_white = ("0.32168", "0.33767")
    primaries = ([('0.70800', '0.29200'), ('0.17000', '0.79700'), ('0.13100', '0.04600')]
                 if variant == "original" else
                 [('0.725', '0.301'), ('0.221', '0.814'), ('0.068', '-0.076')])
    source = matrix_helper.rgb_to_xyz(primaries, source_white)
    target = matrix_helper.rgb_to_xyz(
        [('0.73470', '0.26530'), ('0.00000', '1.00000'), ('0.00010', '-0.07700')],
        target_white)
    bradford = [list(map(D, row)) for row in [
        ('0.89510', '0.26640', '-0.16140'),
        ('-0.75020', '1.71350', '0.03670'),
        ('0.03890', '-0.06850', '1.02960'),
    ]]
    source_cone = matrix_helper.multiply(bradford, [[v] for v in matrix_helper.xyz(source_white)])
    target_cone = matrix_helper.multiply(bradford, [[v] for v in matrix_helper.xyz(target_white)])
    diagonal = [[target_cone[i][0] / source_cone[i][0] if i == j else D(0)
                 for j in range(3)] for i in range(3)]
    cat = matrix_helper.multiply(matrix_helper.multiply(matrix_helper.inverse(bradford), diagonal),
                                 bradford)
    return matrix_helper.multiply(matrix_helper.multiply(matrix_helper.inverse(target), cat), source)


def rounded_twice(function):
    results = []
    for digits in (80, 120):
        with localcontext() as context:
            context.prec = digits
            results.append([float(value) for value in function()])
    if results[0] != results[1]:
        raise ValueError(f"80/120 digit disagreement: {results}")
    return results[0]


def fixture():
    encode_points = [-0.1, -0.05641088, math.nextafter(-0.05641088, math.inf),
                     0, math.nextafter(0.01, -math.inf), 0.01,
                     math.nextafter(0.01, math.inf), 0.18, 1, 10]
    decode_points = [-0.1, 0, math.nextafter(DOUBLE_PT, -math.inf),
                     DOUBLE_PT, math.nextafter(DOUBLE_PT, math.inf), 0.5, 1]
    rgb_points = [[0, 0, 0], [0.1, 0.2, 0.3], [1, 0, 0], [0, 1, 0],
                  [0, 0, 1], [0.5, 0.5, 0.5], [0.02, 0.4, 0.8],
                  [0.9, 0.1, 0.7], [0.18, 0.5, 1], [1, 1, 1]]

    def points(values, function):
        return [{"input": value,
                 "expected": rounded_twice(lambda v=value: [function(D.from_float(v))])[0]}
                for value in values]

    variants = {}
    for variant, filename in (("original", "CSC.Apple.AppleLog_to_ACES.ctl"),
                              ("log2", "CSC.Apple.AppleLog2_to_ACES.ctl")):
        matrix = rounded_twice(lambda v=variant: [cell for row in conversion(v) for cell in row])

        def plan(values):
            scene = [decode(D.from_float(value)) * D(2) for value in values]
            return [row[0] for row in matrix_helper.multiply(conversion(variant),
                                                               [[value] for value in scene])]

        variants[variant] = {
            "sourceTransformID": f"urn:ampas:aces:transformId:v2.0:CSC.Apple.{'AppleLog' if variant == 'original' else 'AppleLog2'}_to_ACES.a2.v1",
            "sourceSHA256": hashlib.sha256((RESEARCH / filename).read_bytes()).hexdigest(),
            "matrixToAP0Bradford": matrix,
            "planExposureOne": [
                {"input": values,
                 "outputLinearAP0": rounded_twice(lambda v=values: plan(v))}
                for values in rgb_points],
        }
    codes = []
    for bits in (10, 12):
        highest = (1 << bits) - 1
        codes.append({"bits": bits, "decoded": rounded_twice(
            lambda m=highest: [decode(D.from_float(code / m)) for code in range(m + 1)])})
    return {
        "source": "https://github.com/aces-aswf/aces-input-and-colorspaces/tree/main/apple",
        "referencePrecisionDigits": [80, 120],
        "colorLibrarySHA256": hashlib.sha256((RESEARCH / "Lib.Academy.ColorSpaces.ctl").read_bytes()).hexdigest(),
        "matrixHelperSHA256": hashlib.sha256(MATRIX_HELPER.read_bytes()).hexdigest(),
        "scaledTolerance": 2e-12,
        "thresholdData": float(PT),
        "encode": points(encode_points, encode),
        "decode": points(decode_points, decode),
        "fullCodeData": codes,
        "variants": variants,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    content = json.dumps(fixture(), ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if OUTPUT.read_text() != content:
            raise SystemExit("Apple Log 双版本独立参照不一致")
        print("Apple Log/Log 2 独立 Decimal 参照核对通过：80/120 位、全码、双矩阵和各 10 点")
    else:
        OUTPUT.write_text(content)
        print(f"Apple Log 双版本独立参照已冻结：{OUTPUT}")


if __name__ == "__main__":
    main()

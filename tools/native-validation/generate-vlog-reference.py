"""按 Panasonic Rev.1.0 与 ACES Bradford CTL，以 Decimal 生成研发参照。"""

import argparse
import hashlib
import json
import math
from decimal import Decimal as D, localcontext
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANUAL = ROOT / "research/colour/2026-09-24/VARICAM_V-Log_V-Gamut.pdf"
CTL = ROOT / "research/colour/2026-09-24/CSC.Panasonic.VLog_VGamut_to_ACES.ctl"
LIBRARY = ROOT / "research/colour/2026-09-24/Lib.Academy.ColorSpaces.ctl"
OUTPUT = ROOT / "tests/fixtures/native-contracts/vlog-panasonic-reference.json"


def multiply(left, right):
    return [[sum((left[i][k] * right[k][j] for k in range(len(right))), D(0))
             for j in range(len(right[0]))] for i in range(len(left))]


def inverse(matrix):
    rows = [row[:] + [D(i == j) for j in range(3)] for i, row in enumerate(matrix)]
    for column in range(3):
        pivot = max(range(column, 3), key=lambda row: abs(rows[row][column]))
        rows[column], rows[pivot] = rows[pivot], rows[column]
        factor = rows[column][column]
        if factor == 0:
            raise ValueError("singular reference matrix")
        rows[column] = [value / factor for value in rows[column]]
        for row in range(3):
            if row != column:
                factor = rows[row][column]
                rows[row] = [value - factor * pivot_value
                             for value, pivot_value in zip(rows[row], rows[column])]
    return [row[3:] for row in rows]


def xyz(point):
    x, y = map(D, point)
    return [x / y, D(1), (D(1) - x - y) / y]


def rgb_to_xyz(primaries, white):
    columns = [xyz(point) for point in primaries]
    base = [[columns[column][row] for column in range(3)] for row in range(3)]
    scales = multiply(inverse(base), [[value] for value in xyz(white)])
    return [[base[row][column] * scales[column][0] for column in range(3)]
            for row in range(3)]


def conversion():
    source_white = ("0.3127", "0.3290")
    target_white = ("0.32168", "0.33767")
    source = rgb_to_xyz([("0.730", "0.280"), ("0.165", "0.840"),
                         ("0.100", "-0.030")], source_white)
    target = rgb_to_xyz([("0.73470", "0.26530"), ("0.00000", "1.00000"),
                         ("0.00010", "-0.07700")], target_white)
    bradford = [list(map(D, row)) for row in [
        ("0.89510", "0.26640", "-0.16140"),
        ("-0.75020", "1.71350", "0.03670"),
        ("0.03890", "-0.06850", "1.02960"),
    ]]
    source_cone = multiply(bradford, [[value] for value in xyz(source_white)])
    target_cone = multiply(bradford, [[value] for value in xyz(target_white)])
    diagonal = [[target_cone[i][0] / source_cone[i][0] if i == j else D(0)
                 for j in range(3)] for i in range(3)]
    cat = multiply(multiply(inverse(bradford), diagonal), bradford)
    return multiply(multiply(inverse(target), cat), source)


def encode(value):
    if value < D.from_float(0.01):
        return D("5.6") * value + D("0.125")
    return D("0.241514") * ((value + D("0.00873")).ln() / D(10).ln()) + D("0.598206")


def decode(value):
    if value < D.from_float(0.181):
        return (value - D("0.125")) / D("5.6")
    return (D(10) ** ((value - D("0.598206")) / D("0.241514"))) - D("0.00873")


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
    scene_points = [-0.02, -0.001, 0.0, math.nextafter(0.01, -math.inf),
                    0.01, math.nextafter(0.01, math.inf), 0.18, 0.9, 1.0, 10.0]
    data_points = [0.0, 0.125, math.nextafter(0.181, -math.inf), 0.181,
                   math.nextafter(0.181, math.inf), 433 / 1023, 602 / 1023, 1.0]
    rgb_points = [
        [0.1, 0.2, 0.3], [0, 1, 0.5], [128 / 1023, 433 / 1023, 602 / 1023],
        [1, 0, 0], [0, 1, 0], [0, 0, 1], [0.5, 0.5, 0.5],
        [0.181, 0.2, 0.8], [0.0, 0.0, 0.0], [0.9, 0.1, 0.7],
    ]
    matrix = rounded_twice(lambda: [value for row in conversion() for value in row])

    def points(values, function):
        return [{"input": value,
                 "expected": rounded_twice(lambda v=value: [function(D.from_float(v))])[0]}
                for value in values]

    def plan(values):
        scene = [decode(D.from_float(value)) * D(2) for value in values]
        return multiply(conversion(), [[value] for value in scene])

    codes = []
    for bits in (10, 12):
        highest = (1 << bits) - 1
        codes.append({"bits": bits, "decoded": rounded_twice(
            lambda m=highest: [decode(D.from_float(code / m))
                               for code in range(m + 1)])})
    return {
        "source": "https://pro-av.panasonic.net/en/cinema_camera_varicam_eva/support/pdf/VARICAM_V-Log_V-Gamut.pdf",
        "sourceTransformID": "urn:ampas:aces:transformId:v2.0:CSC.Panasonic.VLog_VGamut_to_ACES.a2.v1",
        "manualSHA256": hashlib.sha256(MANUAL.read_bytes()).hexdigest(),
        "referenceCTLSHA256": hashlib.sha256(CTL.read_bytes()).hexdigest(),
        "colorLibrarySHA256": hashlib.sha256(LIBRARY.read_bytes()).hexdigest(),
        "referencePrecisionDigits": [80, 120],
        "scaledTolerance": 2e-12,
        "matrixVGamutToAP0Bradford": matrix,
        "manualPublishedMatrix": [0.724383, 0.166748, 0.108497,
                                 0.021354, 0.985138, -0.006319,
                                 -0.009234, -0.001043, 1.010273],
        "encode": points(scene_points, encode),
        "decode": points(data_points, decode),
        "fullCodeData": codes,
        "planExposureOne": [
            {"input": values,
             "outputLinearAP0": rounded_twice(lambda v=values: [row[0] for row in plan(v)])}
            for values in rgb_points],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    content = json.dumps(fixture(), ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if OUTPUT.read_text() != content:
            raise SystemExit("Panasonic V-Log 独立参照不一致")
        print("Panasonic V-Log 独立 Decimal 参照核对通过：80/120 位、全码、矩阵与 10 点")
    else:
        OUTPUT.write_text(content)
        print(f"Panasonic V-Log 独立参照已冻结：{OUTPUT}")


if __name__ == "__main__":
    main()

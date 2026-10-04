"""按 Sony/ACES CTL 色度与 CAT02，用高精度 Decimal 独立生成研发矩阵和链路参照。"""

import argparse
import hashlib
import json
from decimal import Decimal as D, localcontext
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "research/colour/2026-09-24/CSC.Sony.SLog3_SGamut3Cine_to_ACES.ctl"
LIBRARY = ROOT / "research/colour/2026-09-24/Lib.Academy.ColorSpaces.ctl"
OUTPUT = ROOT / "tests/fixtures/native-contracts/slog3-sgamut3cine-ap0-reference.json"
GAMUT3_SOURCE = ROOT / "research/colour/2026-09-24/CSC.Sony.SLog3_SGamut3_to_ACES.ctl"
GAMUT3_OUTPUT = ROOT / "tests/fixtures/native-contracts/slog3-sgamut3-ap0-reference.json"


def xy_to_xyz(pair):
    x, y = map(D, pair)
    return [x / y, D(1), (D(1) - x - y) / y]


def multiply(left, right):
    return [[sum((left[row][k] * right[k][column] for k in range(3)), D(0))
             for column in range(3)] for row in range(3)]


def row_times(row, matrix):
    return [sum((row[k] * matrix[k][column] for k in range(3)), D(0))
            for column in range(3)]


def inverse(matrix):
    a, b, c = matrix[0]
    d, e, f = matrix[1]
    g, h, i = matrix[2]
    cofactors = [
        [e * i - f * h, f * g - d * i, d * h - e * g],
        [c * h - b * i, a * i - c * g, b * g - a * h],
        [b * f - c * e, c * d - a * f, a * e - b * d],
    ]
    determinant = a * cofactors[0][0] + b * cofactors[0][1] + c * cofactors[0][2]
    if determinant == 0:
        raise ValueError("singular primary or cone matrix")
    return [[cofactors[column][row] / determinant for column in range(3)]
            for row in range(3)]


def rgb_to_xyz(primaries, white):
    rows = [xy_to_xyz(point) for point in primaries]
    scale = row_times(xy_to_xyz(white), inverse(rows))
    return [[scale[index] * value for value in row] for index, row in enumerate(rows)]


def conversion(gamut):
    sony_primaries = (
        [("0.766", "0.275"), ("0.225", "0.800"), ("0.089", "-0.087")]
        if gamut == "cine" else
        [("0.730", "0.280"), ("0.140", "0.855"), ("0.100", "-0.050")]
    )
    ap0_primaries = [("0.73470", "0.26530"), ("0.00000", "1.00000"), ("0.00010", "-0.07700")]
    sony_white = ("0.3127", "0.3290")
    ap0_white = ("0.32168", "0.33767")
    # ACES CTL uses row vectors; this CAT02 matrix is the source library's orientation.
    cone = [list(map(D, row)) for row in [
        ("0.73280", "-0.70360", "0.00300"),
        ("0.42960", "1.69750", "0.01360"),
        ("-0.16240", "0.00610", "0.98340"),
    ]]
    source_response = row_times(xy_to_xyz(sony_white), cone)
    target_response = row_times(xy_to_xyz(ap0_white), cone)
    diagonal = [[target_response[row] / source_response[row] if row == column else D(0)
                 for column in range(3)] for row in range(3)]
    cat = multiply(multiply(cone, diagonal), inverse(cone))
    return multiply(multiply(rgb_to_xyz(sony_primaries, sony_white), cat),
                    inverse(rgb_to_xyz(ap0_primaries, ap0_white)))


def decode(signal):
    cut = D("171.2102946929") / D(1023)
    if signal >= cut:
        exponent = (signal * D(1023) - D(420)) / D("261.5")
        return (exponent * D(10).ln()).exp() * D("0.19") - D("0.01")
    return (signal * D(1023) - D(95)) * D("0.01125000") / (D("171.2102946929") - D(95))


def evaluate(values, gamut):
    scene = [decode(D.from_float(value)) * D(2) for value in values]
    return row_times(scene, conversion(gamut))


def rounded_twice(function):
    results = []
    for precision in (80, 120):
        with localcontext() as context:
            context.prec = precision
            results.append([float(value) for value in function()])
    if results[0] != results[1]:
        raise ValueError(f"80/120 digit disagreement: {results}")
    return results[0]


def fixture(gamut):
    cases = [
        [0.1, 0.2, 0.3], [0.0, 1.0, 0.5], [-0.05, 0.5, 1.1],
        [95 / 1023, 420 / 1023, 598 / 1023], [0.16736099187966764, 0.18, 0.19],
        [0.7, 0.3, 0.1], [1.0, 0.0, 0.0], [0.0, 1.0, 0.0],
        [0.0, 0.0, 1.0], [0.5, 0.5, 0.5],
    ]
    row_matrix = rounded_twice(lambda: [cell for row in conversion(gamut) for cell in row])
    column_matrix = [row_matrix[column * 3 + row] for row in range(3) for column in range(3)]
    variant = "SGamut3Cine" if gamut == "cine" else "SGamut3"
    source = SOURCE if gamut == "cine" else GAMUT3_SOURCE
    return {
        "source": f"https://github.com/aces-aswf/aces-input-and-colorspaces/blob/main/sony/CSC.Sony.SLog3_{variant}_to_ACES.ctl",
        "sourceTransformID": f"urn:ampas:aces:transformId:v2.0:CSC.Sony.SLog3_{variant}_to_ACES.a2.v1",
        "sourceSHA256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "colorLibrarySHA256": hashlib.sha256(LIBRARY.read_bytes()).hexdigest(),
        "referencePrecisionDigits": [80, 120],
        "matrixColumnRowMajor": column_matrix,
        "scaledTolerance": 2e-12,
        "cases": [{"input": value, "outputLinearAP0": rounded_twice(lambda v=value: evaluate(v, gamut))}
                  for value in cases],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--gamut", choices=["cine", "gamut3"], default="cine")
    args = parser.parse_args()
    result = json.dumps(fixture(args.gamut), ensure_ascii=False, indent=2) + "\n"
    output = OUTPUT if args.gamut == "cine" else GAMUT3_OUTPUT
    if args.check:
        if output.read_text() != result:
            raise SystemExit(f"S-Log3/{args.gamut} to AP0 独立参照不一致")
        print(f"Sony/ACES CTL {args.gamut} 独立 Decimal 参照核对通过：80/120 位矩阵与 10 个 RGB 点一致")
    else:
        output.write_text(result)
        print(f"Sony/ACES CTL 独立参照已冻结：{output}")


if __name__ == "__main__":
    main()

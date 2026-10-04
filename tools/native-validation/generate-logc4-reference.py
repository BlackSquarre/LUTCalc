"""依据 ARRI LogC4 规范，用高精度 Decimal 生成研发夹具；仅用于验证。"""

import argparse
import hashlib
import json
import math
from decimal import Decimal as D, localcontext
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "research/colour/2026-09-24/CSC.Arri.LogCv4_to_ACES.ctl"
OUTPUT = ROOT / "tests/fixtures/native-contracts/logc4-arri-reference.json"
AP0_MATRIX = [
    "0.750957362824734131", "0.144422786709757084", "0.104619850465508965",
    "0.000821837079380207", "1.007397584885003194", "-0.008219421964383583",
    "-0.000499952143533471", "-0.000854177231436971", "1.001354129374970370",
]


def constants():
    a = (D(2) ** 18 - D(16)) / D("117.45")
    b = D(1023 - 95) / D(1023)
    c = D(95) / D(1023)
    s = D(7) * D(2).ln() * (D(2) ** (D(7) - D(14) * c / b)) / (a * b)
    t = (D(2) ** (-D(14) * c / b + D(6)) - D(64)) / a
    return a, b, c, s, t


def encode(scene):
    a, b, c, s, t = constants()
    if scene < t:
        return (scene - t) / s
    return ((a * scene + D(64)).ln() / D(2).ln() - D(6)) / D(14) * b + c


def decode(signal):
    a, b, c, s, t = constants()
    if signal < 0:
        return signal * s + t
    return (D(2) ** (D(14) * (signal - c) / b + D(6)) - D(64)) / a


def rounded_twice(function):
    values = []
    for precision in (80, 120):
        with localcontext() as context:
            context.prec = precision
            result = function()
            values.append([float(value) for value in result])
    if values[0] != values[1]:
        raise ValueError(f"80/120 digit disagreement: {values}")
    return values[0]


def fixture():
    with localcontext() as context:
        context.prec = 120
        t = float(constants()[-1])
    encode_inputs = [-0.5, -0.1, -0.02, math.nextafter(t, -math.inf), t,
                     math.nextafter(t, math.inf), 0, 0.001, 0.18, 1, 10, 100, 1000]
    decode_inputs = [-0.5, -0.1, math.nextafter(0, -math.inf), 0,
                     math.nextafter(0, math.inf), 0.02, 95 / 1023, 0.18,
                     0.5, 1, 1.25]
    rgb_inputs = [
        [0.1, 0.2, 0.3], [0, 1, 0.5], [-0.05, 0.5, 1.1],
        [95 / 1023, 0.5, 0.9], [0.0, 0.0, 0.0],
        [1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0],
        [0.5, 0.5, 0.5], [0.9, 0.1, 0.7],
    ]
    matrix = list(map(D, AP0_MATRIX))

    def plan(values):
        scene = [decode(D.from_float(value)) * D(2) for value in values]
        return [sum((matrix[row * 3 + column] * scene[column] for column in range(3)), D(0))
                for row in range(3)]

    def scalar_points(values, transform):
        return [{"input": value,
                 "expected": rounded_twice(lambda v=value: [transform(D.from_float(v))])[0]}
                for value in values]

    full_codes = []
    for bits in (10, 12):
        max_code = (1 << bits) - 1
        full_codes.append({"bits": bits, "decoded": rounded_twice(
            lambda m=max_code: [decode(D.from_float(code / m)) for code in range(m + 1)])})
    return {
        "source": "https://www.arri.com/resource/blob/278790/f3318e8c9c65617d8c5ca3f8b3e32051/2023-05-arri-logc4-specification-data.pdf",
        "referenceCTL": "https://github.com/aces-aswf/aces-input-and-colorspaces/blob/main/arri/CSC.Arri.LogCv4_to_ACES.ctl",
        "sourceTransformID": "urn:ampas:aces:transformId:v2.0:CSC.Arri.LogC4_to_ACES.a2.v1",
        "referenceCTLSHA256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "referencePrecisionDigits": [80, 120],
        "scaledTolerance": 2e-12,
        "thresholdScene": t,
        "matrixAWG4ToAP0": [float(value) for value in matrix],
        "encode": scalar_points(encode_inputs, encode),
        "decode": scalar_points(decode_inputs, decode),
        "fullCodeData": full_codes,
        "planExposureOne": [{"input": values,
                             "outputLinearAP0": rounded_twice(lambda v=values: plan(v))}
                            for values in rgb_inputs],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    content = json.dumps(fixture(), ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if OUTPUT.read_text() != content:
            raise SystemExit("ARRI LogC4 独立参照不一致")
        print("ARRI LogC4 独立 Decimal 参照核对通过：80/120 位、全码和 10 个 RGB 点一致")
    else:
        OUTPUT.write_text(content)
        print(f"ARRI LogC4 独立参照已冻结：{OUTPUT}")


if __name__ == "__main__":
    main()

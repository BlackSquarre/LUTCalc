"""仅用 Sony V1.0 公式和 Decimal 生成/核对研发参照，不进入 App。"""

import argparse
import hashlib
import json
import math
from decimal import Decimal as D, localcontext
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "research/colour/2026-09-24/sony-slog3-technical-summary-v1.0.pdf"
OUTPUT = ROOT / "tests/fixtures/native-contracts/slog3-sony-reference.json"
SOURCE_URL = "https://www.sony.jp/ls-camera/knowledge/pdf/TechnicalSummary_for_S-Gamut3Cine_S-Gamut3_S-Log3_V1_00.pdf"
CUT_LINEAR = D("0.01125000")
CUT_CODE = D("171.2102946929") / D(1023)


def encode(value: D) -> D:
    if value >= CUT_LINEAR:
        return (D(420) + ((value + D("0.01")) / D("0.19")).log10() * D("261.5")) / D(1023)
    return (value * (D("171.2102946929") - D(95)) / CUT_LINEAR + D(95)) / D(1023)


def decode(value: D) -> D:
    if value >= CUT_CODE:
        exponent = (value * D(1023) - D(420)) / D("261.5")
        return (exponent * D(10).ln()).exp() * D("0.19") - D("0.01")
    return (value * D(1023) - D(95)) * CUT_LINEAR / (D("171.2102946929") - D(95))


def rounded_twice(function, value: float) -> float:
    values = []
    for precision in (80, 120):
        with localcontext() as context:
            context.prec = precision
            values.append(float(function(D.from_float(value))))
    if values[0] != values[1]:
        raise ValueError(f"80/120 digit disagreement at {value}: {values}")
    return values[0]


def adjacent(value: float) -> list[float]:
    return [math.nextafter(value, -math.inf), value, math.nextafter(value, math.inf)]


def fixture() -> dict:
    encode_points = [-0.5, -0.05, -0.0, 0.0, 0.001] + adjacent(0.01125) + [0.18, 0.9, 1.0, 4.0, 16.0]
    cut = float(CUT_CODE)
    decode_points = [-0.1, -0.0, 0.0, 95 / 1023] + adjacent(cut) + [420 / 1023, 598 / 1023, 1.0]
    full_code = []
    for bits in (10, 12):
        maximum = (1 << bits) - 1
        full_code.append({
            "bits": bits,
            "decoded": [rounded_twice(decode, code / maximum) for code in range(maximum + 1)],
        })
    plan_inputs = [
        [0.0, 0.1, 0.5], [0.16736099187966764, 0.2, 0.7],
        [0.01, 420 / 1023, 598 / 1023], [0.9, 0.5, 0.1],
        [1.0, 0.8, 0.6], [-0.05, 0.0, 0.05],
        [0.15, 0.45, 0.75], [0.3, 0.31, 0.32],
    ]
    def exposure_one(signal: D) -> D:
        return encode(decode(signal) * D(2))
    return {
        "source": SOURCE_URL,
        "sourceVersion": "Sony Technical Summary V1.0, Appendix p.7 (PDF page index 6)",
        "sourceSHA256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "algorithmVersion": "sony.slog3.technical-summary-v1.0",
        "referencePrecisionDigits": [80, 120],
        "supportedOfficialDomain": {"sceneReflectionMin": 0, "encodedMin": 0, "encodedMax": 1},
        "outsideDomainPolicy": "same algebraic branch extension; not a Sony domain claim",
        "scaledTolerance": 2e-12,
        "encode": [{"input": x, "expected": rounded_twice(encode, x)} for x in encode_points],
        "decode": [{"input": x, "expected": rounded_twice(decode, x)} for x in decode_points],
        "fullCodeData": full_code,
        "planExposureOne": [{"input": point,
                             "expected": [rounded_twice(exposure_one, channel) for channel in point]}
                            for point in plan_inputs],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    result = json.dumps(fixture(), ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if OUTPUT.read_text() != result:
            raise SystemExit("Sony S-Log3 研发参照与独立公式不一致")
        print("Sony S-Log3 独立 Decimal 参照核对通过：80/120 位一致、10/12-bit 全码")
    else:
        OUTPUT.write_text(result)
        print(f"Sony S-Log3 研发参照已冻结：{OUTPUT}")


if __name__ == "__main__":
    main()

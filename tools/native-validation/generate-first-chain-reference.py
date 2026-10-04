"""独立用 DJI CTL 公式和既有 Python/NumPy 矩阵夹具生成首条链参照。"""

import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tests/fixtures/dlog2-reference.json"
OUTPUT = ROOT / "tests/fixtures/native-contracts/first-chain-reference.json"


def decode(signal):
    a = 16.285770761945304
    h = 475 / (2**a - 1)
    k1 = 0.059439938321493
    b1 = 0.304985337243402
    k2 = 2.960935245492250
    b2 = 0.148314799066323
    cut = 0.028961695254132
    if signal >= b1:
        return h * (2 ** (a * signal) - 1)
    if signal >= b2:
        return 2 ** ((signal - b1) / k1 + math.log2(0.18))
    return (signal - b2) / k2 + cut


def main():
    reference = json.loads(SOURCE.read_text())
    matrix = reference["toAP0"]
    inputs = [
        [0.1, 0.2, 0.3],
        [0, 1, 0.5],
        [-0.1, 0.5, 1.1],
        [0.304985337243402, 0.148314799066323, 0.06256109481915934],
    ]
    cases = []
    for signal in inputs:
        scene = [decode(v) for v in signal]
        result = [math.fsum(matrix[row * 3 + col] * scene[col] * 2 for col in range(3)) for row in range(3)]
        cases.append({"input": signal, "exposureStops": 1, "outputLinearAP0": result})
    OUTPUT.write_text(json.dumps({
        "source": "DJI CTL D-Log2 formula plus frozen independent Python/NumPy D-Gamut2 to AP0 matrix",
        "sourceFixture": str(SOURCE.relative_to(ROOT)),
        "cases": cases,
    }, indent=2) + "\n")


if __name__ == "__main__":
    main()

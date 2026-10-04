#!/usr/bin/env python3
"""生成 HLG OOTF 的独立 Decimal 参照值。"""
from decimal import Decimal, getcontext
import json
from pathlib import Path

getcontext().prec = 80
D = Decimal


def parameters(peak, black):
    gamma = D("1.2") + D("0.42") * (peak / D("1000")).log10()
    a = (peak - black) / (D(12) ** gamma)
    return gamma, a


def scalar(scene, peak, black, scale=D(1), bbc=D(1)):
    gamma, a = parameters(peak, black)
    return min(peak * scale, (a * max(D(0), scene * bbc) ** gamma + black) * scale)


def main():
    values = {
        "default18": scalar(D("0.18"), D("1000"), D(0)),
        "default1": scalar(D(1), D("1000"), D(0)),
        "normalizedBlack18": scalar(D("0.18"), D("1000"), D(10), D("0.001")),
        "bbc40018": scalar(D("0.18"), D("400"), D(0), bbc=D("2.821251498")),
    }
    result = {"precision": 80, "source": "BT.2100 HLG OOTF plus js/gamma.js:LUTGammaOOTFHLG", "values": {k: str(v) for k, v in values.items()}}
    output = Path(__file__).resolve().parents[2] / "docs/native-validation/artifacts/2026-10-02-hlg-ootf"
    output.mkdir(parents=True, exist_ok=True)
    (output / "decimal-reference.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()

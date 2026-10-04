#!/usr/bin/env python3
"""核对研发用 Rec.709 资料、参照脚本和冻结夹具版本。"""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXPECTED = {
    "js/gamma.js": "250017d8efe758f3555148ba9fcb923698add0ac7d9380fa290716eb98e0821e",
    "tools/native-validation/generate-rec709-reference.py": "9927a402d662b213787c02791ac5f120dd84420a73d50be284f3c1f7f9a8fe37",
    "tools/native-validation/generate-rec709-legacy-baseline.js": "5cd83370290985a6534ff722f822537c03c9a0043f4101fcd8484b14690d48f5",
    "tests/fixtures/native-contracts/rec709-itu-reference.json": "e5a024e7cf3cdb9cac4f92091788acc104de1949b09ea833f0584a46196ebd8f",
    "tests/fixtures/native-contracts/rec709-legacy-reference.json": "24885df07b5cebdbf7c55c9807a0064636743171955c21bf41e9f7138135eef9",
}


def main() -> None:
    for name, expected in EXPECTED.items():
        actual = hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
        if actual != expected:
            raise SystemExit(f"Rec.709 来源或冻结夹具版本变化：{name} {actual} != {expected}")
    official = json.loads((ROOT / "tests/fixtures/native-contracts/rec709-itu-reference.json").read_text())
    legacy = json.loads((ROOT / "tests/fixtures/native-contracts/rec709-legacy-reference.json").read_text())
    if (official.get("algorithmVersion") != "rec709.itu-oetf-2015"
            or legacy.get("algorithmVersion") != "rec709.lutcalc-legacy.v1"
            or [len(group["decoded"]) for group in legacy["fullCodeData"]] != [1024, 4096]):
        raise SystemExit("Rec.709 冻结夹具结构不匹配")
    print("Rec.709 来源、独立脚本与冻结夹具 SHA-256 通过；10/12-bit 全码数量正确")


if __name__ == "__main__":
    main()

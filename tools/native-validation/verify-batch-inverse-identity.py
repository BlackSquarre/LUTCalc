#!/usr/bin/env python3
"""独立核对输入反求内容身份和本地曝光批量 CUBE，不调用生产引擎。"""
import argparse
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path
import struct


def verify(root):
    # 契约：算法标记、插值标记、17 点、六个 domain Double、RGB 样本。
    # 独立合成 transfer f(x)=2x；不从生产 JSON 抽取数值或公式。
    raw = bytearray(b"native.input-transfer-inverse-content.v1\0tricubicLegacyV1\0")
    raw.extend(struct.pack("<Q", 17))
    raw.extend(struct.pack("<6d", 0, 0, 0, 1, 1, 1))
    for i in range(17):
        value = float(Fraction(i, 8))
        raw.extend(struct.pack("<3d", value, value, value))
    identity = hashlib.sha256(raw).hexdigest()
    actual = json.loads((root / "inverse-content.json").read_text())["contentFingerprint"]
    assert actual == identity, "Swift 内容身份与独立二进制契约不符"
    files = sorted(root.glob("inverse_*.cube"))
    assert len(files) == 2
    results = []
    for path in files:
        lines = [line.strip() for line in path.read_text().splitlines()
                 if line.strip() and not line.startswith("#")]
        assert any(line == "LUT_3D_SIZE 17" for line in lines)
        for field, default in [("DOMAIN_MIN", [0, 0, 0]), ("DOMAIN_MAX", [1, 1, 1])]:
            matches = [line for line in lines if line.startswith(field)]
            assert len(matches) <= 1
            values = list(map(Fraction, matches[0].split()[1:])) if matches else default
            assert values == default
        rows = [list(map(Fraction, line.split())) for line in lines
                if not line.startswith(("TITLE", "LUT_", "DOMAIN_"))]
        assert len(rows) == 17**3
        gain = Fraction(1, 2) if "_-1p00." in path.name else Fraction(1)
        assert "_-1p00." in path.name or "_0-Native." in path.name
        errors = []
        for index, row in enumerate(rows):
            assert len(row) == 3
            for axis, value in zip([index % 17, index // 17 % 17, index // 289], row):
                expected = Fraction(axis, 32) * gain
                error = float(abs(value - expected))
                assert error <= 2e-12, f"{path} 节点 {index} 误差 {error}"
                errors.append(error)
        errors.sort()
        results.append(dict(path=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
            channels=len(errors), maximum_absolute_error=max(errors),
            rms=math.sqrt(sum(e*e for e in errors)/len(errors)),
            p99=errors[math.ceil(len(errors)*0.99)-1]))
    return dict(method="独立有理数 f(x)=2x 反函数 x/2 和原始 CUBE 全点读取",
        inverse_content_sha256=identity, inverse_content_matches=True, threshold=2e-12,
        files=results, file_count=len(results), channel_count=sum(x["channels"] for x in results),
        maximum_absolute_error=max(x["maximum_absolute_error"] for x in results))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = verify(args.root)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"内容身份一致；{result['file_count']} 文件、{result['channel_count']} 通道通过；最大绝对误差 {result['maximum_absolute_error']}")

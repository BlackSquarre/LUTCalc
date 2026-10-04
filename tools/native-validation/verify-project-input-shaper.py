#!/usr/bin/env python3
"""独立读取项目原始资产和三种 3DL 文件，按 Fraction 逐码核对。"""
import argparse
from fractions import Fraction as F
import hashlib
import json
import math
from pathlib import Path


def rounded(value):
    return (2 * value.numerator + value.denominator) // (2 * value.denominator)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(root):
    records = []
    for flavor in ["flame", "lustre", "kodak"]:
        for size in [17, 33, 65]:
            folder = root / f"{flavor}-{size}"
            package = folder / "shaped.lutcalc"
            manifest = json.loads((package / "manifest.json").read_bytes())
            assert manifest["schemaVersion"] == 25
            identity = "native.project-input-shaper-linear.v1"
            assert manifest["inputShaper"]["algorithm"] == identity
            assert manifest["algorithmVersions"]["inputShaper"] == identity
            assert manifest["exposureBatchPreset"]["threeDLFlavor"] == flavor
            asset_path = manifest["inputShaper"]["assetPath"]
            assert manifest["assetRoles"] == {asset_path: "inputShaper"}
            assert manifest["assetHashes"][asset_path] == digest(package / asset_path)
            source = (package / asset_path).read_text().splitlines()
            assert source[:4] == ["TITLE \"user nonlinear shaper\"", f"LUT_1D_SIZE {size}",
                                  "DOMAIN_MIN 0 0 0", "DOMAIN_MAX 1 1 1"]
            shape = [rounded(F(1023 * i * i, (size - 1)**2)) for i in range(size)]
            samples = [line.split() for line in source[4:]]
            assert len(samples) == size
            # Read textual Double values independently. Their 10-bit codes are
            # checked against rational x^2, not against a production parser.
            for index, row in enumerate(samples):
                assert len(row) == 3
                for token in row:
                    assert abs(F(token) - F(shape[index], 1023)) < F(2, 10**12)
                    assert rounded(F(token) * 1023) == shape[index]
            files = sorted(folder.glob("batch_*.3dl"))
            assert len(files) == 2
            for path in files:
                text = path.read_text()
                for header in [f"# NUMBER OF ROWS: {size**3}\n", f"# NUMBER OF NODES: {size}\n",
                               "# INPUT RANGE: 10\n", "# OUTPUT RANGE: 12\n"]:
                    assert header in text
                lines = [line.strip() for line in text.splitlines() if line.strip() and not line.startswith("#")]
                if flavor == "lustre":
                    assert lines[:2] == ["3DMESH", f"Mesh {int(math.log2(size - 1))} 12"]
                    assert lines[-2:] == ["LUT8", "gamma 1.0"]
                    lines = lines[2:-2]
                else:
                    assert not any(line.startswith(("3DMESH", "Mesh", "LUT8", "gamma")) for line in lines)
                assert list(map(int, lines[0].split())) == shape
                assert len(lines) - 1 == size**3
                gain = F(1, 2) if "_-1p00." in path.name else F(1)
                assert "_-1p00." in path.name or "_0-Native." in path.name
                codes = [rounded(F(code, 1023) * gain * 4095) for code in shape]
                for index, line in enumerate(lines[1:]):
                    axes = [index // (size * size), index // size % size, index % size]
                    assert list(map(int, line.split())) == [codes[axis] for axis in axes], (path, index)
                intrinsic = max(abs(F(code, 4095) - F(value, 1023) * gain) for code, value in zip(codes, shape))
                records.append(dict(path=str(path.relative_to(root)), size=size, flavor=flavor,
                    channels=3 * size**3, sha256=digest(path), asset_sha256=digest(package / asset_path),
                    integer_codes_exact=True, maximum_absolute_error=0.0,
                    intrinsic_output_quantization_maximum=float(intrinsic)))
    assert len(records) == 18
    old = json.loads((root / "schema24/old.lutcalc/manifest.json").read_bytes())
    assert old["schemaVersion"] == 24 and "inputShaper" not in old
    asset_package = root / "asset/shaped.lutcalc"
    asset_manifest = json.loads((asset_package / "manifest.json").read_bytes())
    path = asset_manifest["inputShaper"]["assetPath"]
    assert digest(asset_package / path) == asset_manifest["assetHashes"][path]
    assert not (root / "asset/source.cube").exists()
    assert not list((root / "rejected").iterdir())
    return dict(method="独立项目JSON、原始文本资产、Fraction平方输入和曝光、12位量化及蓝轴最快行序",
                threshold=2e-12, files=records, file_count=len(records),
                channel_count=sum(x["channels"] for x in records), maximum_absolute_error=0.0,
                intrinsic_output_quantization_maximum=max(x["intrinsic_output_quantization_maximum"] for x in records),
                third_party_roundtrip_verified=False, real_provider_verified=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = verify(args.root)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"{result['file_count']}文件、{result['channel_count']}通道逐码完全一致；阈值 {result['threshold']}")

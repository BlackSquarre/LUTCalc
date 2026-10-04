#!/usr/bin/env python3
"""从独立有理数公式核对批量三种 3DL grammar 的全部码值。"""
import argparse
from fractions import Fraction as F
import hashlib
import json
import math
from pathlib import Path


def rounded(value):
    return (2 * value.numerator + value.denominator) // (2 * value.denominator)


def verify(root):
    files = sorted(root.glob("*/batch_*.3dl"))
    assert len(files) == 30, f"预期30文件，实际{len(files)}"
    results = []
    for path in files:
        folder = path.parent.name
        shaped = folder.startswith(("flame-", "lustre-", "kodak-"))
        flavor = folder.split("-")[0] if shaped else (
            folder.removeprefix("document-") if folder.startswith("document-") else
            "lustre" if folder in ["resume-lustre", "overwrite-lustre"] else "flame")
        assert flavor in ["flame", "lustre", "kodak"]
        size = int(folder.split("-")[1]) if shaped else (33 if folder == "overwrite-lustre" else 17)
        text = path.read_text()
        assert f"# NUMBER OF ROWS: {size**3}\n" in text
        assert f"# NUMBER OF NODES: {size}\n" in text
        assert "# INPUT RANGE: 10\n" in text and "# OUTPUT RANGE: 12\n" in text
        lines = [line.strip() for line in text.splitlines() if line.strip() and not line.startswith("#")]
        if flavor == "lustre":
            assert lines[:2] == ["3DMESH", f"Mesh {int(math.log2(size-1))} 12"]
            assert lines[-2:] == ["LUT8", "gamma 1.0"]
            lines = lines[2:-2]
        else:
            assert not any(line.startswith(("3DMESH", "Mesh", "LUT8", "gamma")) for line in lines)
        shaper = list(map(int, lines[0].split()))
        assert len(shaper) == size
        expected_shaper = [rounded(F(1023*i*i, (size-1)**2)) if shaped
            else math.ceil(F(1023*i, size-1)) for i in range(size)]
        assert shaper == expected_shaper, f"{path}: 输入 header 不符"
        gain = F(1, 2) if "_-1p00." in path.name else F(1)
        assert "_-1p00." in path.name or "_0-Native." in path.name
        inputs = [F(code, 1023) for code in expected_shaper] if shaped else [F(i, size-1) for i in range(size)]
        codes = [rounded(value*gain*4095) for value in inputs]
        assert len(lines)-1 == size**3
        # Disk rows are blue-fast; each axis is verified independently. The
        # quantized reference requires exact integer equality, not tolerance.
        for index, line in enumerate(lines[1:]):
            row = list(map(int, line.split()))
            axes = [index // (size*size), index // size % size, index % size]
            expected = [codes[axis] for axis in axes]
            assert row == expected, f"{path}: 节点{index} 码值 {row} != {expected}"
        intrinsic = [float(abs(F(code, 4095)-value*gain)) for code,value in zip(codes,inputs)]
        results.append(dict(path=str(path.relative_to(root)), flavor=flavor, size=size, shaped=shaped,
            sha256=hashlib.sha256(path.read_bytes()).hexdigest(), channels=3*size**3,
            integer_codes_exact=True, maximum_absolute_error=0.0, rms=0.0, p99=0.0,
            intrinsic_output_quantization_maximum=max(intrinsic)))
    return dict(method="独立Fraction输入、曝光和12位量化；严格原始grammar与全部整数码值核对",
        threshold=2e-12, files=results, file_count=len(results),
        channel_count=sum(x["channels"] for x in results), maximum_absolute_error=0.0,
        intrinsic_output_quantization_maximum=max(x["intrinsic_output_quantization_maximum"] for x in results))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path); parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(); result = verify(args.root)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n")
    print(f"{result['file_count']}文件、{result['channel_count']}通道逐码完全一致；阈值 {result['threshold']}")

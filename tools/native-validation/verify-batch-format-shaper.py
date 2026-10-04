"""独立重读曝光批量文件，按有理数曝光、轴序和格式量化核对全部节点。"""
import argparse
from fractions import Fraction as F
import hashlib
import json
import math
from pathlib import Path


def rounded(value):
    """本包非负整数格式的最近取整，半整数远离零。"""
    assert value >= 0
    return (2 * value.numerator + value.denominator) // (2 * value.denominator)


def decode(path):
    lines = [line.strip() for line in path.read_text().splitlines()
             if line.strip() and not line.startswith("#")]
    kind = path.suffix[1:]
    if kind == "cube":
        assert lines[1] == "LUT_3D_SIZE 17"
        return 17, None, [list(map(F, line.split())) for line in lines[2:]], None
    if kind == "spi3d":
        assert lines[:3] == ["SPILUT 1.0", "3 3", "17 17 17"]
        values = [None] * 17**3
        for line in lines[3:]:
            fields = line.split(); r, g, b = map(int, fields[:3])
            assert all(0 <= x < 17 for x in [r, g, b])
            index = r + 17 * (g + 17 * b)
            assert values[index] is None
            values[index] = list(map(F, fields[3:]))
        assert all(row is not None for row in values)
        return 17, None, values, None
    if kind == "spi1d":
        assert lines[:5] == ["Version 1", "From 0.0 1.0", "Length 1024", "Components 3", "{"]
        assert lines[-1] == "}"
        return 1024, None, [list(map(F, line.split())) for line in lines[5:-1]], None
    if kind == "vlt":
        assert lines[0] == "LUT_3D_SIZE 17"
        return 17, 4095, [list(map(int, line.split())) for line in lines[1:]], None
    if kind == "3dl":
        shaper = list(map(int, lines[0].split())); size = len(shaper)
        values = [None] * size**3
        for index, line in enumerate(lines[1:]):
            r = index // (size * size); g = index // size % size; b = index % size
            values[r + size * (g + size * b)] = list(map(int, line.split()))
        assert all(row is not None for row in values)
        return size, 4095, values, shaper
    if kind in ["ilut", "olut"]:
        size, maximum = (16384, 16383) if kind == "ilut" else (4096, 4095)
        values = []
        for line in lines:
            row = list(map(int, line.split(",")))
            if kind == "ilut":
                assert len(row) == 4 and row[3] == 0
            else:
                assert len(row) == 6 and row[:3] == row[3:]
            values.append(row[:3])
        return size, maximum, values, None
    assert kind == "lut" and lines[0] == "LUT: 3 4096"
    codes = list(map(int, lines[1:])); assert len(codes) == 3 * 4096
    return 4096, 4095, [[codes[i + c * 4096] for c in range(3)] for i in range(4096)], None


def verify(root):
    results = []
    files = sorted(root.glob("*/batch_*.*"))
    assert len(files) == 24, f"预期24个实际输出，发现{len(files)}个"
    for path in files:
        size, maximum, rows, header = decode(path)
        one_d = path.suffix in [".spi1d", ".ilut", ".olut", ".lut"]
        assert len(rows) == (size if one_d else size**3)
        gain = F(1, 2) if "_-1p00." in path.name else F(1)
        assert "_-1p00." in path.name or "_0-Native." in path.name
        shaped = path.parent.name.startswith("shaper-")
        assert not shaped or path.suffix == ".3dl"
        curve = [rounded(F(1023 * i * i, (size - 1)**2)) for i in range(size)]
        if shaped:
            assert header == curve, f"{path}: 非线性shaper头与独立有理数不符"
        errors = []
        for i, row in enumerate(rows):
            assert len(row) == 3
            axes = [i] * 3 if one_d else [i % size, i // size % size, i // (size * size)]
            for c, axis in enumerate(axes):
                value = F(curve[axis], 1023) if shaped else F(axis, size - 1)
                expected = value * gain
                if maximum is not None:
                    code = rounded(expected * maximum)
                    assert row[c] == code, f"{path}: 节点{i}通道{c}整数码值{row[c]}≠{code}"
                    actual = F(row[c], maximum)
                    expected = F(code, maximum)
                else:
                    actual = row[c]
                error = float(abs(actual - expected))
                assert error <= 2e-12, f"{path}: 节点{i}通道{c}误差{error}"
                errors.append(error)
        errors.sort()
        results.append(dict(path=str(path.relative_to(root)), sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
            nodes=len(rows), channels=len(errors), maximum_absolute_error=max(errors),
            rms=math.sqrt(sum(e * e for e in errors) / len(errors)),
            p99=errors[math.ceil(len(errors) * 0.99) - 1], integer_codes_exact=maximum is not None))
    return dict(method="独立Fraction公式与原始文本重读；整数格式先验证全部码值完全相同",
        threshold=2e-12, files=results, file_count=len(results),
        channel_count=sum(row["channels"] for row in results),
        maximum_absolute_error=max(row["maximum_absolute_error"] for row in results))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(); parser.add_argument("root", type=Path)
    parser.add_argument("--output", required=True, type=Path); args = parser.parse_args()
    result = verify(args.root)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"{result['file_count']}个文件、{result['channel_count']}个通道通过；最大绝对误差{result['maximum_absolute_error']}")

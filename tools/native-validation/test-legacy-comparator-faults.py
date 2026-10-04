#!/usr/bin/env python3
"""Check that the Swift legacy comparison detects three concrete fixture faults."""

import shutil
import struct
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tests/fixtures/native-contracts/legacy-dlog2-exposure17.f64"
METADATA = SOURCE.with_suffix(".json")
CHECKER = ROOT / "Native/Packages/LUTKit/.build/release/LUTContractChecks"
ARGUMENTS = [
    ROOT / "tests/fixtures/native-contracts/numeric-contracts.json",
    ROOT / "tests/fixtures/dlog2-reference.json",
    ROOT / "tests/fixtures/native-contracts/parser-contracts.json",
    ROOT / "tests/fixtures/native-contracts/first-chain-reference.json",
    ROOT / "tests/fixtures/native-contracts/srgb-reference.json",
    ROOT / "tests/fixtures/native-contracts/srgb-legacy-reference.json",
    ROOT / "tests/fixtures/native-contracts/srgb-plan-reference.json",
]


def compare(binary: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(CHECKER), *(str(item) for item in ARGUMENTS), str(binary)],
        capture_output=True,
        text=True,
        check=False,
    )


def save_case(directory: Path, name: str, samples: list[float]) -> Path:
    target = directory / f"{name}.f64"
    target.write_bytes(struct.pack(f"<{len(samples)}d", *samples))
    shutil.copyfile(METADATA, target.with_suffix(".json"))
    return target


def main() -> None:
    if not CHECKER.is_file():
        raise SystemExit("先运行 Swift Release 构建")
    original = list(struct.unpack(f"<{SOURCE.stat().st_size // 8}d", SOURCE.read_bytes()))
    baseline = compare(SOURCE)
    if baseline.returncode != 0 or "RMS" not in baseline.stdout or "P99" not in baseline.stdout:
        raise SystemExit("原始夹具或统计输出未通过")

    perturbation = original.copy()
    perturbation[300] += 1e-5

    size = 17
    axis_swap = original.copy()
    for blue in range(size):
        for green in range(size):
            for red in range(size):
                destination = (red + green * size + blue * size * size) * 3
                source = (green + red * size + blue * size * size) * 3
                axis_swap[destination:destination + 3] = original[source:source + 3]

    quantization = [struct.unpack("<f", struct.pack("<f", value))[0] for value in original]
    with tempfile.TemporaryDirectory(prefix="lutcalc-comparator-faults-") as temporary:
        directory = Path(temporary)
        for name, samples in [
            ("perturbation", perturbation),
            ("axis-swap", axis_swap),
            ("float32-quantization", quantization),
        ]:
            result = compare(save_case(directory, name, samples))
            if result.returncode == 0 or "legacy full path" not in result.stderr or "超门槛通道" not in result.stderr:
                raise SystemExit(f"比较器未检出 {name}: {result.returncode} {result.stderr[-400:]}")
            print(f"比较器故障注入 {name} 已检出：{result.stderr.strip()}")


if __name__ == "__main__":
    main()

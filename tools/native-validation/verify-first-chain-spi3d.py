"""Compare an exported SPI3D against the frozen D-Log2 to AP0 reference."""

import argparse
import importlib.util
import json
import math
from pathlib import Path

_REFERENCE_MODULE_PATH = Path(__file__).with_name("verify-first-chain-cube.py")
_REFERENCE_SPEC = importlib.util.spec_from_file_location("verify_first_chain_cube", _REFERENCE_MODULE_PATH)
if _REFERENCE_SPEC is None or _REFERENCE_SPEC.loader is None:
    raise ImportError(f"cannot load {_REFERENCE_MODULE_PATH}")
_REFERENCE_MODULE = importlib.util.module_from_spec(_REFERENCE_SPEC)
_REFERENCE_SPEC.loader.exec_module(_REFERENCE_MODULE)
REFERENCE = _REFERENCE_MODULE.REFERENCE
decode = _REFERENCE_MODULE.decode


def read_spi3d(path, expected_size):
    rows = path.read_text(encoding="utf-8").splitlines()
    content = [(number, line.strip()) for number, line in enumerate(rows, 1)
               if line.strip() and not line.lstrip().startswith("#")]
    if len(content) < 3 or [line for _, line in content[:3]] != [
        "SPILUT 1.0", "3 3", f"{expected_size} {expected_size} {expected_size}"
    ]:
        raise ValueError("unexpected SPI3D header or dimension")

    samples = {}
    for line_number, line in content[3:]:
        fields = line.split()
        if len(fields) != 6:
            raise ValueError(f"wrong field count at line {line_number}")
        try:
            coordinates = tuple(int(field) for field in fields[:3])
            actual = tuple(float(field) for field in fields[3:])
        except ValueError as error:
            raise ValueError(f"invalid value at line {line_number}") from error
        if any(str(value) != field for value, field in zip(coordinates, fields[:3])):
            raise ValueError(f"noncanonical coordinate at line {line_number}")
        if any(value < 0 or value >= expected_size for value in coordinates):
            raise ValueError(f"out-of-range coordinate at line {line_number}")
        if not all(math.isfinite(value) for value in actual):
            raise ValueError(f"nonfinite channel at line {line_number}")
        if coordinates in samples:
            raise ValueError(f"duplicate coordinate {coordinates} at line {line_number}")
        samples[coordinates] = actual

    if len(samples) != expected_size**3:
        raise ValueError(f"expected {expected_size**3} unique coordinates, found {len(samples)}")
    return samples


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("spi3d", type=Path)
    parser.add_argument("--expected-size", type=int, required=True)
    args = parser.parse_args()
    samples = read_spi3d(args.spi3d, args.expected_size)
    matrix = json.loads(REFERENCE.read_text(encoding="utf-8"))["toAP0"]
    errors = []
    worst = (-1.0, None, -1)
    for coordinates, actual in samples.items():
        scene = tuple(decode(value / (args.expected_size - 1)) for value in coordinates)
        for channel in range(3):
            expected = math.fsum(matrix[channel * 3 + k] * scene[k] * 2 for k in range(3))
            error = abs(actual[channel] - expected) / max(1, abs(expected))
            errors.append(error)
            if error > worst[0]:
                worst = (error, coordinates, channel)
    errors.sort()
    result = {
        "status": "passed" if worst[0] <= 2e-12 else "failed",
        "nodes": len(samples),
        "maxScaledError": worst[0],
        "worstCoordinate": worst[1],
        "worstChannel": worst[2],
        "rmsScaledError": math.sqrt(math.fsum(error * error for error in errors) / len(errors)),
        "p99ScaledError": errors[math.ceil(0.99 * len(errors)) - 1],
        "threshold": 2e-12,
    }
    print(json.dumps(result, ensure_ascii=False))
    if result["status"] != "passed":
        raise SystemExit(1)


if __name__ == "__main__":
    main()

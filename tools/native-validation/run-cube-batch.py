#!/usr/bin/env python3
"""Generate and independently verify the native curve CUBE matrix in bounded batches.

The manifest is intentionally explicit: every case keeps the same preset, grid size,
reference fixture and verifier that the historical serial entry point used. Generation
and verification are separate phases so a successful file is always checked by the
independent reader before the batch is reported as passed.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import os
import pathlib
import subprocess
import sys
import tempfile
from dataclasses import dataclass


ROOT = pathlib.Path(__file__).resolve().parents[2]


@dataclass(frozen=True)
class Case:
    key: str
    preset: str
    verifier: tuple[str, ...]
    verifier_args: tuple[str, ...]
    sizes: tuple[int, ...] = (33, 65)


def cases() -> tuple[Case, ...]:
    return (
        Case("dlog2-linear-ap0", "dlog2-linear-ap0", ("verify-first-chain-cube.py",), ()),
        Case("dlog2-srgb-w3c", "dlog2-srgb-w3c", ("verify-srgb-cube.py",), ()),
        Case("slog3-sony", "slog3-sony-exposure", ("verify-slog3-cube.py",), ("--variant", "sony")),
        Case("slog3-legacy", "slog3-legacy-exposure", ("verify-slog3-cube.py",), ("--variant", "legacy")),
        Case("slog3-ap0", "slog3-linear-ap0", ("verify-slog3-ap0-cube.py",), ("tests/fixtures/native-contracts/slog3-sgamut3cine-ap0-reference.json",)),
        Case("slog3-gamut3-ap0", "slog3-sgamut3-linear-ap0", ("verify-slog3-ap0-cube.py",), ("tests/fixtures/native-contracts/slog3-sgamut3-ap0-reference.json",)),
        Case("logc4", "logc4-linear-ap0", ("verify-logc4-cube.py",), ("tests/fixtures/native-contracts/logc4-arri-reference.json",)),
        Case("vlog", "vlog-linear-ap0", ("verify-vlog-cube.py",), ("tests/fixtures/native-contracts/vlog-panasonic-reference.json",)),
        Case("flog2", "flog2-exposure", ("verify-flog2-cube.py",), ()),
        Case("flog2c", "flog2c-exposure", ("verify-flog2-cube.py",), ()),
        Case("flog2-legacy", "flog2-legacy-exposure", ("verify-flog2-legacy-cube.py",), ()),
        Case("acescct", "acescct-exposure", ("verify-acescct-cube.py",), ()),
        Case("acescc", "acescc-exposure", ("verify-acescc-cube.py",), ()),
        Case("acesproxy10", "acesproxy10-exposure", ("verify-acesproxy-cube.py",), ("--bit-depth", "10")),
        Case("acesproxy12", "acesproxy12-exposure", ("verify-acesproxy-cube.py",), ("--bit-depth", "12")),
        Case("ilog", "ilog-exposure", ("verify-ilog-cube.py",), ()),
        Case("milog", "milog-exposure", ("verify-milog-cube.py",), ()),
        Case("llog", "llog-exposure", ("verify-llog-cube.py",), ()),
        Case("kinelog3", "kinelog3-exposure", ("verify-kinelog3-cube.py",), ()),
        Case("applelog-original", "applelog-linear-ap0", ("verify-applelog-cube.py",), ("tests/fixtures/native-contracts/applelog-aces-reference.json", "--variant", "original")),
        Case("applelog-log2", "applelog2-linear-ap0", ("verify-applelog-cube.py",), ("tests/fixtures/native-contracts/applelog-aces-reference.json", "--variant", "log2")),
        Case("rec709", "rec709-legacy-exposure", ("verify-rec709-cube.py",), ()),
        Case("cie-lstar", "cie-lstar-exposure", ("verify-cie-lstar-cube.py",), ()),
        Case("prophoto", "prophoto-exposure", ("verify-prophoto-bbc-cube.py",), ("--variant", "prophoto")),
        Case("bbc", "bbc-exposure", ("verify-prophoto-bbc-cube.py",), ("--variant", "bbc")),
        Case("bbc-whp283-400", "bbc-whp283-400-exposure", ("verify-prophoto-bbc-cube.py",), ("--variant", "bbc-whp283-400")),
        Case("bbc-whp283-800", "bbc-whp283-800-exposure", ("verify-prophoto-bbc-cube.py",), ("--variant", "bbc-whp283-800")),
    )


def run(command: list[str]) -> str:
    completed = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    if completed.returncode:
        output = (completed.stdout + completed.stderr).strip()
        raise RuntimeError(f"exit {completed.returncode}: {' '.join(command)}\n{output}")
    return (completed.stdout + completed.stderr).strip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("reference_cli", type=pathlib.Path)
    parser.add_argument("--workers", type=int, default=None)
    args = parser.parse_args()
    configured_workers = os.environ.get("LUTCALC_BATCH_WORKERS")
    workers = args.workers if args.workers is not None else (
        int(configured_workers) if configured_workers is not None else (os.cpu_count() or 1)
    )
    if workers < 1:
        parser.error("--workers must be positive")
    reference_cli = args.reference_cli.resolve()
    if not reference_cli.is_file():
        parser.error(f"missing LUTReferenceCLI: {reference_cli}")

    manifest = cases()
    keys = [case.key for case in manifest]
    if len(keys) != len(set(keys)):
        raise RuntimeError("duplicate batch case key")
    if any(size not in (33, 65) for case in manifest for size in case.sizes):
        raise RuntimeError("batch manifest contains an unsupported grid size")

    with tempfile.TemporaryDirectory(prefix="lutcalc-native-cube-batch-", dir=None) as raw_dir:
        output_dir = pathlib.Path(raw_dir)
        jobs: list[tuple[str, pathlib.Path, list[str]]] = []
        for case in manifest:
            for size in case.sizes:
                output = output_dir / f"{case.key}-{size}.cube"
                jobs.append((f"{case.key} {size}³", output, [
                    str(reference_cli), "--size", str(size), "--output", str(output), "--preset", case.preset
                ]))

        workers = min(workers, len(jobs))
        print(f"批量 CUBE 生成：{len(jobs)} 个案例，{workers} 个并行 worker")
        generated: dict[str, pathlib.Path] = {}
        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
            futures = {pool.submit(run, command): (label, output) for label, output, command in jobs}
            for future in concurrent.futures.as_completed(futures):
                label, output = futures[future]
                try:
                    message = future.result()
                except Exception as exc:
                    raise RuntimeError(f"生成失败 [{label}]：{exc}") from exc
                generated[label] = output
                if message:
                    print(message)

        verify_jobs: list[tuple[str, list[str]]] = []
        for case in manifest:
            verifier = ROOT / "tools/native-validation" / case.verifier[0]
            for size in case.sizes:
                label = f"{case.key} {size}³"
                output = generated[label]
                command = [sys.executable, str(verifier), str(output), "--size", str(size), *case.verifier_args]
                verify_jobs.append((label, command))

        print(f"批量 CUBE 独立读回：{len(verify_jobs)} 个案例，{workers} 个并行 worker")
        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
            futures = {pool.submit(run, command): label for label, command in verify_jobs}
            results: dict[str, str] = {}
            for future in concurrent.futures.as_completed(futures):
                label = futures[future]
                try:
                    results[label] = future.result()
                except Exception as exc:
                    raise RuntimeError(f"独立读回失败 [{label}]：{exc}") from exc
        for label, _ in verify_jobs:
            if results[label]:
                print(results[label])

    print(f"批量 CUBE 案例全部通过：{len(verify_jobs)} 个生成/读回对")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"run-cube-batch.py: {exc}", file=sys.stderr)
        raise SystemExit(1)

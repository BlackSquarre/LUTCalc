#!/usr/bin/env python3
"""Run independent scalar/curve contract executables in a bounded batch.

Each executable keeps its own fixture loading and Double comparisons. This runner only
schedules independent processes and prints their captured output in manifest order;
it does not alter numeric inputs, tolerances, or generated LUT data.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import os
import pathlib
import subprocess
import sys
from dataclasses import dataclass


ROOT = pathlib.Path(__file__).resolve().parents[2]


class BatchFailure(RuntimeError):
    """A product or independent check failed before the batch completed."""


@dataclass(frozen=True)
class Check:
    key: str
    executable: pathlib.Path
    arguments: tuple[str, ...]


def checks(product_dir: pathlib.Path) -> tuple[Check, ...]:
    """Return the frozen formula-check manifest in stable output order."""
    return (
        Check(
            "rec709",
            product_dir / "LUTRec709Checks",
            (
                "tests/fixtures/native-contracts/rec709-itu-reference.json",
                "tests/fixtures/native-contracts/rec709-legacy-reference.json",
            ),
        ),
        Check(
            "slog3",
            product_dir / "LUTSLog3Checks",
            (
                "tests/fixtures/native-contracts/slog3-sony-reference.json",
                "tests/fixtures/native-contracts/slog3-legacy-reference.json",
                "tests/fixtures/native-contracts/slog3-sgamut3cine-ap0-reference.json",
                "tests/fixtures/native-contracts/slog3-sgamut3-ap0-reference.json",
            ),
        ),
        Check(
            "logc4",
            product_dir / "LUTLogC4Checks",
            ("tests/fixtures/native-contracts/logc4-arri-reference.json",),
        ),
        Check(
            "vlog",
            product_dir / "LUTVLogChecks",
            ("tests/fixtures/native-contracts/vlog-panasonic-reference.json",),
        ),
        Check(
            "applelog",
            product_dir / "LUTAppleLogChecks",
            ("tests/fixtures/native-contracts/applelog-aces-reference.json",),
        ),
        Check("hlg", product_dir / "LUTHLGChecks", ()),
        Check("bt1886", product_dir / "LUTBT1886Checks", ()),
    )


def validate_products(manifest: tuple[Check, ...]) -> None:
    keys = [item.key for item in manifest]
    if len(keys) != len(set(keys)):
        raise BatchFailure("批量检查清单存在重复 key")
    for item in manifest:
        if not item.executable.is_file():
            raise BatchFailure(f"缺少批量检查产品：{item.executable}")
        if not os.access(item.executable, os.X_OK):
            raise BatchFailure(f"批量检查产品不可执行：{item.executable}")
        for argument in item.arguments:
            fixture = ROOT / argument
            if not fixture.is_file():
                raise BatchFailure(f"缺少批量检查夹具：{fixture}")


def run_check(item: Check) -> str:
    command = [str(item.executable), *item.arguments]
    completed = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    output = (completed.stdout + completed.stderr).strip()
    if completed.returncode:
        raise BatchFailure(
            f"独立契约失败 [{item.key}]：exit {completed.returncode}: "
            f"{' '.join(command)}\n{output}"
        )
    return output


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("product_dir", type=pathlib.Path)
    parser.add_argument("--workers", type=int, default=None)
    args = parser.parse_args(argv)
    configured_workers = os.environ.get("LUTCALC_BATCH_WORKERS")
    workers = args.workers if args.workers is not None else (
        int(configured_workers) if configured_workers is not None else (os.cpu_count() or 1)
    )
    if workers < 1:
        parser.error("--workers must be positive")

    manifest = checks(args.product_dir.resolve())
    validate_products(manifest)
    workers = min(workers, len(manifest))
    print(f"批量公式契约：{len(manifest)} 个独立检查，{workers} 个并行 worker")
    results: dict[str, str] = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(run_check, item): item for item in manifest}
        for future in concurrent.futures.as_completed(futures):
            item = futures[future]
            try:
                results[item.key] = future.result()
            except Exception as exc:
                raise BatchFailure(str(exc)) from exc

    for item in manifest:
        output = results[item.key]
        if output:
            print(f"[{item.key}] {output}")
    print(f"批量公式契约全部通过：{len(manifest)} 个独立检查")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except BatchFailure as exc:
        print(f"run-check-batch.py: {exc}", file=sys.stderr)
        raise SystemExit(1)

#!/usr/bin/env python3
"""Run independent validation commands concurrently with deterministic reporting."""

from __future__ import annotations

import argparse
import concurrent.futures
import os
import pathlib
import shlex
import subprocess
import sys
from dataclasses import dataclass


ROOT = pathlib.Path(__file__).resolve().parents[2]


@dataclass(frozen=True)
class Result:
    index: int
    command: str
    returncode: int
    output: str


def run_one(item: tuple[int, str]) -> Result:
    index, command = item
    argv = shlex.split(command)
    if not argv:
        return Result(index, command, 0, "")
    completed = subprocess.run(argv, cwd=ROOT, text=True, capture_output=True)
    output = (completed.stdout + completed.stderr).strip()
    return Result(index, command, completed.returncode, output)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workers", type=int, default=None)
    args = parser.parse_args(argv)
    workers = args.workers or int(os.environ.get("LUTCALC_VALIDATION_WORKERS") or 0) or min(8, os.cpu_count() or 1)
    if workers < 1:
        parser.error("--workers must be positive")

    commands = [line.strip() for line in sys.stdin if line.strip() and not line.lstrip().startswith("#")]
    if not commands:
        return 0
    print(f"并行验证：{len(commands)} 个独立检查，{min(workers, len(commands))} 个 worker")
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        results = list(pool.map(run_one, enumerate(commands)))

    failures = [result for result in results if result.returncode]
    for result in results:
        if result.output or result.returncode:
            prefix = "失败" if result.returncode else "通过"
            print(f"[{prefix} {result.index + 1}] {result.command}\n{result.output}")
    if failures:
        print(f"并行验证失败：{len(failures)}/{len(commands)} 个检查失败", file=sys.stderr)
        return 1
    print(f"并行验证通过：{len(commands)} 个检查")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

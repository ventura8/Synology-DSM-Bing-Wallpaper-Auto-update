#!/usr/bin/env python3
"""Run actionlint in Docker for cross-platform pre-commit usage."""

from __future__ import annotations

import subprocess
from pathlib import Path


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent.parent

    cmd = [
        "docker",
        "run",
        "--rm",
        "-v",
        f"{repo_root}:/repo",
        "-w",
        "/repo",
        "rhysd/actionlint:1.7.7",
    ]
    result = subprocess.run(cmd, check=False)
    if result.returncode != 0:
        print("actionlint failed. Ensure Docker is running and workflow files are valid.")
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())

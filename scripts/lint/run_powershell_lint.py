#!/usr/bin/env python3
"""Run PowerShell lint script with best-available shell executable."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path


def main() -> int:
    pwsh = shutil.which("pwsh")
    powershell = shutil.which("powershell")

    shell = pwsh or powershell
    if shell is None:
        print("Neither 'pwsh' nor 'powershell' is available in PATH.")
        return 1

    repo_root = Path(__file__).resolve().parent.parent.parent
    lint_script = repo_root / "scripts" / "lint" / "lint_powershell.ps1"

    cmd = [shell, "-NoProfile", "-File", str(lint_script)]
    result = subprocess.run(cmd, check=False, cwd=repo_root)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())

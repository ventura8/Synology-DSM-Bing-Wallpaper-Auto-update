from __future__ import annotations

import contextlib
import io
import subprocess
import unittest
from typing import Any
from unittest import mock

from _loader import REPO_ROOT, load_script


def _completed(code: int) -> subprocess.CompletedProcess[bytes]:
    return subprocess.CompletedProcess(args=[], returncode=code)


class LintActionsTests(unittest.TestCase):
    module: Any

    @classmethod
    def setUpClass(cls) -> None:
        cls.module = load_script("scripts/lint/lint_actions.py", "lint_actions")

    def test_runs_pinned_actionlint_image_against_repo(self) -> None:
        with mock.patch.object(self.module.subprocess, "run", return_value=_completed(0)) as run:
            self.assertEqual(self.module.main(), 0)
        cmd = run.call_args.args[0]
        self.assertEqual(cmd[:3], ["docker", "run", "--rm"])
        self.assertIn(f"{REPO_ROOT}:/repo", cmd)
        self.assertEqual(cmd[-1], "rhysd/actionlint:1.7.12")

    def test_failure_propagates_with_hint(self) -> None:
        out = io.StringIO()
        with mock.patch.object(self.module.subprocess, "run", return_value=_completed(3)), contextlib.redirect_stdout(out):
            self.assertEqual(self.module.main(), 3)
        self.assertIn("actionlint failed", out.getvalue())


class RunPowershellLintTests(unittest.TestCase):
    module: Any

    @classmethod
    def setUpClass(cls) -> None:
        cls.module = load_script("scripts/lint/run_powershell_lint.py", "run_powershell_lint")

    def test_missing_shell_returns_1(self) -> None:
        out = io.StringIO()
        with mock.patch.object(self.module.shutil, "which", return_value=None), contextlib.redirect_stdout(out):
            self.assertEqual(self.module.main(), 1)
        self.assertIn("Neither 'pwsh' nor 'powershell'", out.getvalue())

    def test_prefers_pwsh_and_returns_its_exit_code(self) -> None:
        which = {"pwsh": "/usr/bin/pwsh", "powershell": "/usr/bin/powershell"}
        with (
            mock.patch.object(self.module.shutil, "which", side_effect=which.get),
            mock.patch.object(self.module.subprocess, "run", return_value=_completed(2)) as run,
        ):
            self.assertEqual(self.module.main(), 2)
        cmd = run.call_args.args[0]
        self.assertEqual(cmd[:3], ["/usr/bin/pwsh", "-NoProfile", "-File"])
        self.assertEqual(cmd[3], str(REPO_ROOT / "scripts" / "lint" / "lint_powershell.ps1"))
        self.assertEqual(run.call_args.kwargs["cwd"], REPO_ROOT)

    def test_falls_back_to_windows_powershell(self) -> None:
        which = {"powershell": "powershell.exe"}
        with (
            mock.patch.object(self.module.shutil, "which", side_effect=which.get),
            mock.patch.object(self.module.subprocess, "run", return_value=_completed(0)) as run,
        ):
            self.assertEqual(self.module.main(), 0)
        self.assertEqual(run.call_args.args[0][0], "powershell.exe")


if __name__ == "__main__":
    unittest.main()

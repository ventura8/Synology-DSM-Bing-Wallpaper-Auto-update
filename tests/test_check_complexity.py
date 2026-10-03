from __future__ import annotations

import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from typing import Any

from _loader import load_script

SIMPLE_SHELL = "simple() {\n  echo hi\n}\n"
COMPLEX_SHELL = "busy() {\n" + "  if true; then :; fi\n" * 11 + "}\n"
POWERSHELL = "function Get-Thing {\n  if ($a) { 1 } elseif ($b) { 2 }\n  foreach ($x in $y) { }\n}\n"


class CheckComplexityTests(unittest.TestCase):
    module: Any

    @classmethod
    def setUpClass(cls) -> None:
        cls.module = load_script("scripts/quality/check_complexity.py", "check_complexity")

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self._old_root = self.module.ROOT
        self.module.ROOT = self.root

    def tearDown(self) -> None:
        self.module.ROOT = self._old_root
        self._tmp.cleanup()

    def _write(self, rel: str, text: str) -> Path:
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def _main(self) -> tuple[int, str]:
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = self.module.main()
        return code, out.getvalue()

    def test_iter_script_files_skips_excluded_dirs(self) -> None:
        kept = self._write("a.sh", SIMPLE_SHELL)
        ps = self._write("b.psm1", POWERSHELL)
        self._write(".venv/c.sh", SIMPLE_SHELL)
        self._write("notes.txt", "x")
        self.assertEqual(self.module.iter_script_files(), sorted([kept, ps]))

    def test_shell_and_powershell_complexities(self) -> None:
        shell = self._write("a.sh", SIMPLE_SHELL + COMPLEX_SHELL)
        ps = self._write("b.ps1", POWERSHELL)
        self.assertEqual(self.module.get_function_complexities(shell), [1, 12])
        self.assertEqual(self.module.get_file_complexity(shell), 12)
        self.assertEqual(self.module.get_function_complexities(ps), [4])

    def test_unknown_suffix_and_no_functions_report_zero(self) -> None:
        self.assertEqual(self.module.get_function_complexities(self._write("x.py", "pass\n")), [])
        self.assertEqual(self.module.get_file_complexity(self._write("y.sh", "echo hi\n")), 0)

    def test_check_file_reports_violation_with_location(self) -> None:
        path = self._write("dir/a.sh", "\n" + COMPLEX_SHELL)
        self.assertEqual(
            self.module.check_file(path),
            ["dir/a.sh:2: function 'busy' complexity 12 exceeds 10"],
        )
        self.assertEqual(self.module.check_file(self._write("b.ps1", POWERSHELL)), [])

    def test_main_passes_on_simple_functions(self) -> None:
        self._write("a.sh", SIMPLE_SHELL)
        code, out = self._main()
        self.assertEqual(code, 0)
        self.assertIn("Complexity check passed", out)

    def test_main_fails_on_complex_function(self) -> None:
        self._write("a.sh", COMPLEX_SHELL)
        code, out = self._main()
        self.assertEqual(code, 1)
        self.assertIn("Complexity check failed:", out)
        self.assertIn("function 'busy'", out)


if __name__ == "__main__":
    unittest.main()

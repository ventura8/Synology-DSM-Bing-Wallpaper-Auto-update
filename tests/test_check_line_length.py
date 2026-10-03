from __future__ import annotations

import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from typing import Any
from unittest import mock

from _loader import REPO_ROOT, load_script


class CheckLineLengthTests(unittest.TestCase):
    module: Any

    @classmethod
    def setUpClass(cls) -> None:
        cls.module = load_script("scripts/quality/check_line_length.py", "check_line_length")

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self._old_root = self.module.ROOT
        self.module.ROOT = self.root

    def tearDown(self) -> None:
        self.module.ROOT = self._old_root
        self._tmp.cleanup()

    def _write(self, rel: str, data: str | bytes) -> Path:
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(data, bytes):
            path.write_bytes(data)
        else:
            path.write_text(data, encoding="utf-8")
        return path

    def _main(self) -> tuple[int, str]:
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = self.module.main()
        return code, out.getvalue()

    def test_root_is_repository_root(self) -> None:
        self.assertEqual(self._old_root, REPO_ROOT)

    def test_should_skip_rules(self) -> None:
        self.assertTrue(self.module.should_skip(self.root / ".git" / "config"))
        self.assertTrue(self.module.should_skip(self.root / "README.MD"))
        self.assertTrue(self.module.should_skip(self.root / "logo.PNG"))
        self.assertFalse(self.module.should_skip(self.root / "script.sh"))
        self.assertTrue(self.module.should_skip(Path("/elsewhere/node_modules/x.js")))

    def test_is_text_file(self) -> None:
        self.assertTrue(self.module.is_text_file(self._write("a.txt", "hello")))
        self.assertFalse(self.module.is_text_file(self._write("b.bin", b"a\x00b")))
        self.assertFalse(self.module.is_text_file(self.root / "missing"))

    def test_check_file_reports_long_lines_and_tolerates_bad_utf8(self) -> None:
        path = self._write("a.txt", b"ok\n" + b"\xff" * 141 + b"\n")
        self.assertEqual(self.module.check_file(path), ["a.txt:2: line length 141 exceeds 140"])

    def test_main_passes_on_short_lines(self) -> None:
        self._write("a.txt", "short\n")
        self._write("long.md", "x" * 300)
        self._write("blob.dat", b"x" * 300 + b"\x00")
        code, out = self._main()
        self.assertEqual(code, 0)
        self.assertIn("Line length check passed", out)

    def test_main_fails_on_long_line(self) -> None:
        self._write("sub/a.txt", "y" * 141)
        code, out = self._main()
        self.assertEqual(code, 1)
        self.assertIn("sub/a.txt:1: line length 141 exceeds 140", out)

    def test_main_skips_paths_that_cannot_be_stat_ed(self) -> None:
        self._write("a.txt", "short\n")
        with mock.patch.object(Path, "is_file", side_effect=OSError("denied")):
            code, _ = self._main()
        self.assertEqual(code, 0)


if __name__ == "__main__":
    unittest.main()

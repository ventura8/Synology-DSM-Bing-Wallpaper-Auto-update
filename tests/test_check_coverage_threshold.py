from __future__ import annotations

import contextlib
import importlib.util
import io
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any


def _load_module() -> Any:
    repo_root = Path(__file__).resolve().parent.parent
    module_path = repo_root / "scripts" / "coverage_checks" / "check_coverage_threshold.py"
    spec = importlib.util.spec_from_file_location("check_coverage_threshold", module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError("Unable to load check_coverage_threshold module")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _write_cobertura(path: Path, line_rate: float) -> None:
    xml = f'<?xml version="1.0" encoding="UTF-8"?>\n<coverage line-rate="{line_rate}" branches-valid="0" branches-covered="0" />\n'
    path.write_text(xml, encoding="utf-8")


class CheckCoverageThresholdTests(unittest.TestCase):
    module: Any

    @classmethod
    def setUpClass(cls) -> None:
        cls.module = _load_module()

    def _run_main(self, argv: list[str]) -> tuple[int, str]:
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            old_argv = sys.argv
            try:
                sys.argv = argv
                return_code = self.module.main()
            finally:
                sys.argv = old_argv
        return return_code, stdout.getvalue()

    def test_invalid_argument_count_returns_2(self) -> None:
        return_code, output = self._run_main(["check_coverage_threshold.py"])

        self.assertEqual(return_code, 2)
        self.assertIn("Usage: check_coverage_threshold.py", output)

    def test_missing_coverage_file_returns_2(self) -> None:
        return_code, output = self._run_main(["check_coverage_threshold.py", "does_not_exist.xml", "90"])

        self.assertEqual(return_code, 2)
        self.assertIn("Coverage file not found", output)

    def test_coverage_below_threshold_returns_1(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            xml_path = Path(tmp_dir) / "cobertura.xml"
            _write_cobertura(xml_path, line_rate=0.89)

            return_code, output = self._run_main(["check_coverage_threshold.py", str(xml_path), "90"])

        self.assertEqual(return_code, 1)
        self.assertIn("Total line coverage: 89.00%", output)
        self.assertIn("Required minimum:   90.00%", output)
        self.assertIn("Coverage threshold check failed.", output)

    def test_coverage_meeting_or_exceeding_threshold_returns_0(self) -> None:
        test_cases = ((0.9, "90"), (0.92, "90"))

        for line_rate, threshold in test_cases:
            with self.subTest(line_rate=line_rate, threshold=threshold):
                with tempfile.TemporaryDirectory() as tmp_dir:
                    xml_path = Path(tmp_dir) / "cobertura.xml"
                    _write_cobertura(xml_path, line_rate=line_rate)

                    return_code, output = self._run_main(["check_coverage_threshold.py", str(xml_path), threshold])

                self.assertEqual(return_code, 0)
                self.assertIn("Coverage threshold check passed.", output)


if __name__ == "__main__":
    unittest.main()

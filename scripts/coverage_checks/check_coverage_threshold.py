#!/usr/bin/env python3
"""Fail when Cobertura line coverage is below a required threshold."""

from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: check_coverage_threshold.py <cobertura.xml> <threshold_percent>")
        return 2

    xml_path = Path(sys.argv[1])
    threshold = float(sys.argv[2])

    if not xml_path.exists():
        print(f"Coverage file not found: {xml_path}")
        return 2

    root = ET.parse(xml_path).getroot()
    line_rate = float(root.get("line-rate", "0")) * 100

    print(f"Total line coverage: {line_rate:.2f}%")
    print(f"Required minimum:   {threshold:.2f}%")

    if line_rate < threshold:
        print("Coverage threshold check failed.")
        return 1

    print("Coverage threshold check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

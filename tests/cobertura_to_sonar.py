#!/usr/bin/env python3
"""Convert a merged Cobertura report into SonarQube's generic coverage format.

SonarQube Cloud cannot read Cobertura for shell code, so the kcov output has to be
restated in the generic format before `sonar.coverageReportPaths` can pick it up.
Paths are emitted relative to the repository root, which is what the scanner matches
its indexed files against.
"""

from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def build_coverage(cobertura: Path) -> ET.Element:
    """Return a generic-format <coverage> element for every class in the report."""
    root = ET.parse(cobertura).getroot()
    coverage = ET.Element("coverage", {"version": "1"})

    # kcov splits one source file across several <class> entries, so merge by filename
    # and keep the highest hit count seen for a line.
    hits_by_file: dict[str, dict[int, int]] = {}
    for class_node in root.iter("class"):
        filename = class_node.get("filename")
        if not filename:
            continue
        lines = hits_by_file.setdefault(filename, {})
        for line_node in class_node.iter("line"):
            number = line_node.get("number")
            if number is None:
                continue
            hits = int(line_node.get("hits") or 0)
            line_number = int(number)
            lines[line_number] = max(lines.get(line_number, 0), hits)

    for filename in sorted(hits_by_file):
        file_node = ET.SubElement(coverage, "file", {"path": filename})
        for line_number in sorted(hits_by_file[filename]):
            covered = "true" if hits_by_file[filename][line_number] > 0 else "false"
            ET.SubElement(
                file_node,
                "lineToCover",
                {"lineNumber": str(line_number), "covered": covered},
            )

    return coverage


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(f"usage: {argv[0]} <cobertura.xml> <output.xml>", file=sys.stderr)
        return 2

    cobertura = Path(argv[1])
    if not cobertura.is_file():
        print(f"Cobertura report not found: {cobertura}", file=sys.stderr)
        return 1

    coverage = build_coverage(cobertura)
    files = list(coverage)
    if not files:
        print(f"No covered files found in {cobertura}; refusing to write an empty report.", file=sys.stderr)
        return 1

    ET.ElementTree(coverage).write(argv[2], encoding="UTF-8", xml_declaration=True)
    total = sum(len(list(node)) for node in files)
    print(f"Wrote {argv[2]}: {len(files)} file(s), {total} lines.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

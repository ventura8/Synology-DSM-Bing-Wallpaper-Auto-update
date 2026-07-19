#!/usr/bin/env python3
"""Validate maximum line length for all non-Markdown text files."""

from __future__ import annotations

from pathlib import Path

MAX_LENGTH = 140
ROOT = Path(__file__).resolve().parent.parent

EXCLUDED_DIRS = {
    ".git",
    ".venv",
    "venv",
    ".mypy_cache",
    ".ruff_cache",
    ".pytest_cache",
    ".vscode",
    "coverage",
    "html_report",
    "raw_coverage",
    "raw_coverage_comp",
    "raw_coverage_e2e",
    "coverage_inputs",
    "node_modules",
    "__pycache__",
}

EXCLUDED_SUFFIXES = {
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".svg",
    ".ico",
    ".pdf",
    ".zip",
    ".gz",
    ".tar",
    ".db",
    ".woff",
    ".woff2",
    ".ttf",
    ".eot",
    ".mp4",
    ".mov",
}


def should_skip(path: Path) -> bool:
    try:
        relative_parts = path.relative_to(ROOT).parts
    except ValueError:
        relative_parts = path.parts

    if any(part in EXCLUDED_DIRS for part in relative_parts):
        return True
    if path.suffix.lower() == ".md":
        return True
    return path.suffix.lower() in EXCLUDED_SUFFIXES


def is_text_file(path: Path) -> bool:
    try:
        data = path.read_bytes()
    except OSError:
        return False
    return b"\x00" not in data


def check_file(path: Path) -> list[str]:
    violations: list[str] = []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    rel = path.relative_to(ROOT).as_posix()
    for index, line in enumerate(lines, start=1):
        if len(line) > MAX_LENGTH:
            violations.append(f"{rel}:{index}: line length {len(line)} exceeds {MAX_LENGTH}")
    return violations


def main() -> int:
    violations: list[str] = []
    for path in ROOT.rglob("*"):
        if should_skip(path):
            continue
        try:
            if not path.is_file():
                continue
        except OSError:
            continue
        if not is_text_file(path):
            continue
        violations.extend(check_file(path))

    if violations:
        print("Line length check failed:")
        for violation in violations:
            print(violation)
        return 1

    print("Line length check passed for all non-Markdown text files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

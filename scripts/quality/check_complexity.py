#!/usr/bin/env python3
"""Enforce simple function complexity thresholds for shell and PowerShell files."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
MAX_FUNCTION_COMPLEXITY = 10
EXCLUDED_DIRS = {
    ".git",
    ".venv",
    "venv",
    ".mypy_cache",
    ".ruff_cache",
    ".pytest_cache",
    ".vscode",
    "coverage",
    "coverage_inputs",
    "html_report",
    "raw_coverage",
    "raw_coverage_comp",
    "raw_coverage_e2e",
    "node_modules",
    "__pycache__",
}
SHELL_FUNCTION_PATTERN = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{")
POWERSHELL_FUNCTION_PATTERN = re.compile(r"^\s*function\s+([A-Za-z_][A-Za-z0-9_-]*)\b", re.IGNORECASE)
SHELL_DECISION_PATTERN = re.compile(r"\b(if|elif|for|while|until|case)\b|&&|\|\|")
POWERSHELL_DECISION_PATTERN = re.compile(r"\b(if|elseif|for|foreach|while|switch|catch)\b", re.IGNORECASE)


class ComplexityViolation(Exception):
    pass


def should_skip(path: Path) -> bool:
    return any(part in EXCLUDED_DIRS for part in path.relative_to(ROOT).parts)


def iter_script_files() -> list[Path]:
    files: list[Path] = []
    for suffix in ("*.sh", "*.ps1", "*.psm1"):
        for path in ROOT.rglob(suffix):
            if should_skip(path):
                continue
            files.append(path)
    return sorted(files)


def count_braces(line: str) -> int:
    return line.count("{") - line.count("}")


def collect_blocks(path: Path, pattern: re.Pattern[str]) -> list[tuple[str, list[str], int]]:
    blocks: list[tuple[str, list[str], int]] = []
    lines = path.read_text(encoding="utf-8").splitlines()
    index = 0

    while index < len(lines):
        match = pattern.match(lines[index])
        if match is None:
            index += 1
            continue

        name = match.group(1)
        block_lines = [lines[index]]
        brace_balance = count_braces(lines[index])
        start_line = index + 1
        index += 1

        while index < len(lines) and brace_balance > 0:
            block_lines.append(lines[index])
            brace_balance += count_braces(lines[index])
            index += 1

        blocks.append((name, block_lines, start_line))

    return blocks


def calculate_complexity(block_lines: list[str], decision_pattern: re.Pattern[str]) -> int:
    complexity = 1
    for line in block_lines:
        complexity += len(decision_pattern.findall(line))
    return complexity


def get_function_complexities(path: Path) -> list[int]:
    if path.suffix == ".sh":
        blocks = collect_blocks(path, SHELL_FUNCTION_PATTERN)
        pattern = SHELL_DECISION_PATTERN
    elif path.suffix in {".ps1", ".psm1"}:
        blocks = collect_blocks(path, POWERSHELL_FUNCTION_PATTERN)
        pattern = POWERSHELL_DECISION_PATTERN
    else:
        return []

    return [calculate_complexity(block_lines, pattern) for _, block_lines, _ in blocks]


def get_file_complexity(path: Path) -> int:
    complexities = get_function_complexities(path)
    if not complexities:
        return 0

    return max(complexities)


def check_file(path: Path) -> list[str]:
    rel = path.relative_to(ROOT).as_posix()
    violations: list[str] = []

    if path.suffix == ".sh":
        blocks = collect_blocks(path, SHELL_FUNCTION_PATTERN)
        pattern = SHELL_DECISION_PATTERN
    else:
        blocks = collect_blocks(path, POWERSHELL_FUNCTION_PATTERN)
        pattern = POWERSHELL_DECISION_PATTERN

    for name, block_lines, start_line in blocks:
        complexity = calculate_complexity(block_lines, pattern)
        if complexity > MAX_FUNCTION_COMPLEXITY:
            violations.append(f"{rel}:{start_line}: function '{name}' complexity {complexity} exceeds {MAX_FUNCTION_COMPLEXITY}")

    return violations


def main() -> int:
    violations: list[str] = []
    for path in iter_script_files():
        violations.extend(check_file(path))

    if violations:
        print("Complexity check failed:")
        for violation in violations:
            print(violation)
        return 1

    print(f"Complexity check passed (max function complexity <= {MAX_FUNCTION_COMPLEXITY}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

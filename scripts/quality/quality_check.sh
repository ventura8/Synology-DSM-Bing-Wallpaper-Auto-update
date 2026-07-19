#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

echo "Running pre-commit quality checks..."
pre-commit run --all-files --show-diff-on-failure

echo "Running explicit non-Markdown line length check..."
python3 scripts/quality/check_line_length.py

echo "All quality checks passed."

---
name: code-linter
description: >-
  Run repository quality checks (shfmt, ShellCheck, Ruff, Mypy, yamllint,
  actionlint, PSScriptAnalyzer, line length, complexity) via quality_check
  scripts. Use when linting, formatting, or clearing the quality gate.
---

# Code Linter Skill

Use this skill to lint and format shell, Python, PowerShell, YAML, and workflow
files without suppressions or hook bypasses.

## Instructions

1. **Live output and persistent logs**:

   ```bash
   set -euo pipefail
   mkdir -p reports/agent-logs
   ./scripts/quality/quality_check.sh 2>&1 | tee reports/agent-logs/quality.log
   exit "${PIPESTATUS[0]}"
   ```

   PowerShell:

   ```powershell
   New-Item -ItemType Directory -Force -Path reports/agent-logs | Out-Null
   ./scripts/quality/quality_check.ps1 2>&1 |
     Tee-Object -FilePath reports/agent-logs/quality.log
   ```

1. **Autofix first, then re-lint**:

   Before hand-editing lint failures, run safe automatic formatters / fixers
   (for example `ruff check --fix`, `ruff format`, and formatters applied through
   pre-commit). Re-run the quality gate and only manually fix what remains.

1. **Enforce project limits**:

   - Maximum line length **140** for all non-Markdown text.
   - Complexity **≤10** per function (Python, shell, PowerShell).
   - No `# shellcheck disable`, `# noqa`, `# type: ignore`, or other suppressions.
   - [`.pre-commit-config.yaml`](../../../.pre-commit-config.yaml) is the SSOT for
     which tools run; do not weaken CI relative to local.

1. **Completion criteria**:

   - `quality_check.sh` / `.ps1` exits 0.
   - No new ignores or disable directives.
   - If agent-facing lint commands changed, update `AGENTS.md` and this skill in
     the same change set.

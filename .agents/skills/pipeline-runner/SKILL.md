---
name: pipeline-runner
description: >-
  Run the full local pipeline: mandatory quality gate, then DSM-mock tests with
  kcov, 90% coverage, and coverage badge update. Use before commit or PR.
---

# Local Pipeline Runner Skill

Use this skill to validate quality, tests, and coverage locally before committing
or opening a PR — same spirit as CI without waiting for GitHub Actions.

## Instructions

1. **Create log directory** and keep live CLI streaming:

   ```bash
   set -euo pipefail
   mkdir -p reports/agent-logs
   ```

1. **Quality gate first** (fail closed; do not proceed to tests on lint failure):

   ```bash
   ./scripts/quality/quality_check.sh 2>&1 | tee reports/agent-logs/quality.log
   exit "${PIPESTATUS[0]}"
   ```

   Or: `./scripts/quality/quality_check.ps1`

1. **Autofix loop**: If quality fails with autofixable issues, run safe formatters
   / `ruff check --fix` / pre-commit autofix, re-run the gate, and only then
   hand-edit remaining findings. Never add suppressions.

1. **Full local tests + coverage + badge**:

   ```powershell
   ./scripts/testing/run_tests_local.ps1 2>&1 |
     Tee-Object -FilePath reports/agent-logs/tests.log
   ```

1. **Confirm coverage contract** before finishing:

   - Coverage ≥ **90%**
   - `assets/coverage.svg` updated and included in the change set when
     coverage was regenerated
   - No CI-only shortcuts that skip local checks

1. **Completion criteria**:

   - Quality exit 0
   - Unit, component, and e2e green under DSM mock
   - Threshold and badge satisfied
   - All relevant markdown updated in the same change set — see root `AGENTS.md`
     § Always Update Relevant Markdown

---
name: ci-maintainer
description: >-
  Keep GitHub Actions and test-container dependencies on stable final versions
  with local↔CI parity. Use when editing workflows, action pins, or CI deps.
---

# CI Maintainer Skill

Use this skill when changing [`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml),
action versions, or Docker DSM mock dependencies used by CI.

## Policy

1. **Stable final versions only**: Pin Actions to published tags/versions (for
   example `@v7.0.0`), not floating `@main` / `@master`. Prefer the latest stable
   patch on the major line already in use unless a major bump is intentional and
   tested.
1. **Local ↔ CI parity**: CI quality must run the same mandatory checks as
   `./scripts/quality/quality_check.sh`. Do not add ignores that make CI greener
   than local.
1. **Pipeline shape**: Preserve `quality` → parallel `unit` / `component` /
   `e2e` → `coverage-report` with hard **90%** enforcement via
   `scripts/coverage_checks/check_coverage_threshold.py`.
1. **Reproducible mock**: Keep `tests/Dockerfile.dsm_mock` and related test
   helpers deterministic; document breaking image changes in agent docs.

## Validation

1. **Lint workflows**:

   ```bash
   set -euo pipefail
   mkdir -p reports/agent-logs
   ./scripts/quality/quality_check.sh 2>&1 | tee reports/agent-logs/quality.log
   exit "${PIPESTATUS[0]}"
   ```

   Ensure actionlint and yamllint cover the edited workflow.

1. **Smoke the affected path**: After pin or job changes, run the narrowest
   local equivalent (quality and/or `run_tests_local.ps1`) before declaring done.

1. **Completion criteria**:

   - Workflow syntax clean
   - Pins are stable finals
   - Coverage gate and badge rules unchanged unless intentionally revised in
     `AGENTS.md` + skills in the same change set

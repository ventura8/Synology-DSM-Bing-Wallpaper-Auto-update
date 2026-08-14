---
name: test-runner
description: >-
  Run Docker DSM-mock unit, component, and e2e tests with kcov; enforce 90%
  coverage; update assets/coverage.svg. Use when testing or fixing coverage.
---

# Test Runner Skill

Use this skill to execute the DSM mock test lanes and enforce the coverage
contract from `AGENTS.md`.

## Dependency and mocking philosophy

- Prefer the real Docker DSM mock ([`tests/Dockerfile.dsm_mock`](../../../tests/Dockerfile.dsm_mock)).
- Never mock owned product script logic; call the real `bing_wallpaper_auto_update.sh`
  under test.
- Mock only external boundaries (Bing network, privileged host paths) that cannot
  run as-is in CI.
- Keep Python host tooling mocks Linux/Windows safe when platform modules appear.

## Instructions

1. **Quality first**: Do not chase test failures until
   `./scripts/quality/quality_check.sh` (or `.ps1`) is green.

1. **Live output and persistent logs**:

   ```powershell
   New-Item -ItemType Directory -Force -Path reports/agent-logs | Out-Null
   ./scripts/testing/run_tests_local.ps1 2>&1 |
     Tee-Object -FilePath reports/agent-logs/tests.log
   ```

   This builds the mock image, runs unit / component / e2e (kcov), merges
   coverage, and regenerates the badge.

1. **Verify DSM mock outcomes** when changing apply paths or metadata writes:

   - Expect updates consistent with `tests/verify_dsm_mock.sh`
   - Paths: `synoinfo.conf` welcome fields, login backgrounds, `dsm7_01.jpg`

1. **Coverage contract**:

   - Floor: **90%** (`scripts/coverage_checks/check_coverage_threshold.py`)
   - Transform Cobertura as CI does (`tests/transform_coverage.py`) when
     inspecting reports manually
   - **Badge**: `assets/coverage.svg` is **not** updated by CI — commit it after
     a successful local run in the same change set

1. **Completion criteria**:

   - All lanes pass.
   - Coverage ≥ 90%.
   - Badge committed when coverage was regenerated.
   - Update `AGENTS.md` / this skill if test commands or thresholds change.

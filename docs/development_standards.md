# Development & Standards

This document outlines the coding standards, environment management, and testing requirements for the project.

**Current release:** [v1.0.4](releases/v1.0.4.md)

## Environment & Dependency Management

- **Local Development**: The project uses Docker to simulate a Synology DSM environment for testing.
- **Tools**: Ensure `docker`, PowerShell **7.4.14+**, Python **3.10+**, and `pre-commit`
  are installed for local validation and test runs.
- **Dependency locking**: `requirements/dev.txt` holds the direct dependencies you edit;
  `requirements/dev.lock` is generated from it with `pip-compile --generate-hashes` and pins the
  transitive tree by hash. CI installs from the lock with `--require-hashes --only-binary :all:`,
  so a wheel that does not match its recorded hash fails the build. Regenerate the lock under
  Python 3.12 whenever `dev.txt` changes and commit both files together.
- **Python**: Minimum development version is **3.10** (documented next to
  `requirements/dev.txt`; Ruff/Mypy target `py310` / `python_version = "3.10"`).
  CI quality uses 3.12; the supported range is 3.10–3.12.
- **PowerShell**: Minimum for lint/orchestration scripts is **7.4.14** (`pwsh`);
  `scripts/lint/lint_powershell.ps1` enforces this and pins PSScriptAnalyzer **1.25.0**.

## Coding Standards

- **Shell Scripting**:
  - Follow ShellCheck recommendations.
  - Apply formatting with shfmt.
  - Use `set -e` or appropriate error handling to ensure script reliability.
  - Maintain compatibility with BusyBox-style `ash`/`bash` common on Synology systems.
- **Python**:
  - Use Ruff for linting and formatting.
  - Use Mypy for static type checking.
- **PowerShell**:
  - Use PSScriptAnalyzer with repository settings.
- **Static analysis**:
  - SonarQube Cloud analyses run locally and in CI; see "SonarQube Cloud" below.
- **YAML / Workflows**:
  - Use yamllint for all YAML files.
  - Use actionlint for GitHub workflow correctness.
- **Line Length**:
  - Maximum line length is 140 for all non-Markdown text files.
  - Markdown is excluded from line-length enforcement only.
- **Complexity**:
  - Python cyclomatic complexity must stay at or below 10 per function.
  - Shell and PowerShell function decision complexity must stay at or below 10 per function.
  - Refactor large functions into smaller helpers instead of suppressing complexity findings.
- **Suppression Policy**:
  - No lint suppressions, disables, or ignore-based bypasses are allowed.
- **Metadata Handling**:
  - Ensure correct parsing of Bing API JSON.
  - Titles and Copyright descriptions should be sanitized for usage in `synoinfo.conf`.
  - Archive dates from the API must be validated (Bing `YYYYMMDD`) before use in filenames.
- **System Safety**:
  - Always check for file existence before overwriting.
  - Keep TLS certificate verification enabled on all downloads (`wget` must not use `--no-check-certificate`).
  - Validate downloaded content is JPEG (SOI magic bytes) before writing system paths.
  - Log significant actions for troubleshooting.

## SonarQube Cloud

- **Project**: `ventura8_Synology-DSM-Bing-Wallpaper-Auto-update` (organization `ventura8`).
- **Settings SSOT**: `sonar-project.properties`, used unchanged by both local scans and CI.
- **Local run** (needs Docker and a SonarQube Cloud user token):

  ```bash
  SONAR_TOKEN=... ./scripts/quality/sonar_scan.sh
  ```

  The script uses the pinned `sonar-scanner-cli` container, so no scanner installation is required.
- **CI**: SonarQube Cloud **Automatic Analysis** currently scans every push to `main` and every
  pull request, with no secret required. The workflow also carries a `sonarqube` job that scans and
  then fails the pipeline on a red quality gate; it is off unless the `SONAR_ENABLED` repository
  variable is `"true"` and a `SONAR_TOKEN` secret exists. Only one mode may be active at a time —
  enabling the job requires disabling Automatic Analysis in the project settings.
- **Scope**: Bash, Python, PowerShell, Dockerfile, and workflow YAML. Sonar overlaps ShellCheck
  on the product script and adds rules it does not cover — error output on stderr, explicit
  `return` at the end of a function, and `[[` over `[` for conditional tests.
- **Suppressions**: the no-suppressions policy applies to Sonar findings too — fix the underlying
  issue instead of resolving an issue as "Won't Fix" or adding `NOSONAR`.

## Testing & Coverage

- **Mandatory Coverage**: The project target is **90%+ code coverage**.
- **Enforcement**: CI (GitHub Actions) will fail if coverage drops below 90%.
- **Local Testing**:
  - Run the mandatory quality gate before tests:
    ```powershell
    ./scripts/quality/quality_check.ps1
    ```
  - Run tests locally using `./scripts/testing/run_tests_local.ps1`.
  - This script handles:
    1. Building the mock DSM Docker image.
    2. Running Unit, Component, and E2E tests in parallel.
    3. Merging coverage results into a unified report.
    4. Generating the coverage badge.
- **Badge Mandatory**:
  - **The coverage badge is NOT updated by CI.**
  - You must update the badge locally before every commit:
    ```powershell
    ./scripts/testing/run_tests_local.ps1
    ```
  - Ensure `assets/coverage.svg` is committed with your changes.
- **Reporting**:
  - Detailed HTML reports are generated in the `coverage/` directory during local runs.
  - In CI, coverage summaries are posted as PR comments and job summaries.

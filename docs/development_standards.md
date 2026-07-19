# Development & Standards

This document outlines the coding standards, environment management, and testing requirements for the project.

## Environment & Dependency Management

- **Local Development**: The project uses Docker to simulate a Synology DSM environment for testing.
- **Tools**: Ensure `docker`, `PowerShell`, `python`, and `pre-commit` are installed for local validation and test runs.

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
- **System Safety**:
  - Always check for file existence before overwriting.
  - Log significant actions for troubleshooting.

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

# AI Instructions

## Workflow Priorities
1.  **Fix Linting First**: Always resolve all linting issues (shfmt, ShellCheck, Ruff, Mypy, yamllint, actionlint, PSScriptAnalyzer) *before* attempting to fix or run tests.
2.  **Fix Tests Second**: Once linting is clean, proceed to fix and run tests.

## Mandatory Quality Gate
-   Run full quality checks with `./scripts/quality/quality_check.ps1` (PowerShell) or `./scripts/quality/quality_check.sh` (Bash).
-   All quality checks are mandatory both locally and in CI.
-   Do not add suppressions, disable directives, or ignores to bypass lint findings.
-   Enforce 140-character maximum line length for all non-Markdown text files.

## Testing & Coverage
-   **Execution**: Run tests after linting is complete.
-   **Coverage Badge**:
    -   You MUST generate a coverage badge after running tests.
    -   **Validation**: Check that the coverage is at least **90%**.
    -   If coverage is below 90%, prioritize adding tests to meet this threshold.

## Cross-Platform Compatibility
-   **Mocks**:
    -   Ensure all mocks are compatible with **Windows** and **Linux** environments.
    -   **Specific Caution**: Be careful when mocking platform-specific modules like `ctypes.windll` or `os.add_dll_directory`. Use `create=True` for `MagicMock` where appropriate to avoid `AttributeError` on non-Windows systems (or Linux systems where these don't exist).
    -   Use `sys.platform` checks or `unittest.mock.patch` with handling for `ImportError` / `AttributeError` if necessary.

## General Rules
-   Follow the existing project structure.
-   Keep these instructions updated if workflow requirements change.

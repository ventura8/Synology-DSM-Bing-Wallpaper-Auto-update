# AI Instructions

## Workflow Priorities
1.  **Fix Linting First**: Always resolve all linting issues (flake8, mypy, etc.) *before* attempting to fix or run tests.
2.  **Fix Tests Second**: Once linting is clean, proceed to fix and run tests.

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

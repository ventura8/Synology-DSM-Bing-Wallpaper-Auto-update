# AI Instructions

**Source of truth:** root [`AGENTS.md`](../AGENTS.md) and playbooks under
[`.agents/skills/`](../.agents/skills/).

## Always-on reminders

1. Fix linting first (`./scripts/quality/quality_check.sh` or `.ps1`), then tests.
2. No suppressions or disable directives.
3. Line length ≤140 for non-Markdown; complexity ≤10.
4. Coverage floor 90%; commit `assets/coverage.svg` after local coverage runs
   (CI does not update the badge).

Do not duplicate or fork rules here — update `AGENTS.md` / skills instead.

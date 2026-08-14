# Examples: scope, classification, summary

## Trigger phrases (user starts the skill)

### Findings mode

- “run coderabbit skill Findings”
- “CodeRabbit Findings — fix plugin issues”
- “review-with-coderabbit Findings”

### Review mode

- “Start the CodeRabbit review skill on uncommitted changes”
- “Review with CodeRabbit — committed only”
- “Run review-with-coderabbit on all changes including untracked”
- “CodeRabbit review this branch against `main`, then fix valid findings”

Do **not** start from vague “looks good?” without an explicit CodeRabbit /
skill request.

## Findings → CLI

```bash
mkdir -p reports/agent-logs
FINDINGS_LOG=reports/agent-logs/coderabbit-findings.log
FINDINGS_ERR=reports/agent-logs/coderabbit-findings.err.log
set -o pipefail
"$CR" review findings --agent \
  2> >(tee "$FINDINGS_ERR" >&2) \
  | tee "$FINDINGS_LOG"
status=$?
if [ "$status" -ne 0 ]; then
  exit "$status"
fi
if grep -q '"type"[[:space:]]*:[[:space:]]*"error"' "$FINDINGS_LOG"; then
  echo "CodeRabbit findings stream reported an error event" >&2
  exit 1
fi
if ! grep -q '"type"[[:space:]]*:[[:space:]]*"complete"' "$FINDINGS_LOG"; then
  echo "CodeRabbit findings stream missing complete event" >&2
  exit 1
fi
```

## Scope → CLI (Review)

**Uncommitted (tracked edits only):**

```bash
"$CR" review --agent --uncommitted -c AGENTS.md
```

**Uncommitted including new files:**

```bash
"$CR" review --agent --uncommitted --include-untracked -c AGENTS.md
```

**Committed only:**

```bash
"$CR" review --agent --committed -c AGENTS.md
```

**All tracked (default) vs `main`:**

```bash
"$CR" review --agent --base main -c AGENTS.md
```

Tee stdout/stderr under `reports/agent-logs/` as in `SKILL.md`.

## Classification examples (this repo)

| Finding | Verdict | Why |
| --- | --- | --- |
| Missing fail-closed on empty `SAVE_PATH` when archive enabled | Valid | Wallpaper invariant |
| “Add `# noqa` to silence Ruff” | Not valid | No-suppression policy |
| “Lower coverage to 80%” | Not valid | 90% contract |
| Suggest rewriting README screenshots unrelated to PR | Not valid | Out of scope |
| Ambiguous security change to wget flags | Blocked/unsure | Ask user |

## Summary report skeleton

```markdown
## CodeRabbit summary (Review)

**CLI**: `coderabbit review --agent --uncommitted -c AGENTS.md`
**Logs**: `reports/agent-logs/coderabbit-review.log`

| Bucket | Fixed | Skipped | Blocked/unsure |
| --- | --- | --- | --- |
| Main issues | 1 | 0 | 0 |
| Nitpicks | 0 | 1 | 0 |

### Fixed
- Main: sanitized `login_welcome_title` before `synoinfo.conf` write

### Skipped
- Nit: requested shellcheck disable (conflicts with AGENTS.md)

### Awaiting user
- (none)
```

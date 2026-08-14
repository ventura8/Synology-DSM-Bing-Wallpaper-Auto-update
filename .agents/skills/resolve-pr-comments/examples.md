# Reply templates and classification examples

## Required reply shapes

Always reply **before** resolving. Keep replies factual and short.

### Valid — fixed

```markdown
**Valid** — fixed.

<One or two sentences: what was wrong and what you changed (file/symbol if useful).>
```

Example:

```markdown
**Valid** — fixed.

Archive mode now fails closed when `SAVE_PATH` is empty before `mkdir`, matching
`AGENTS.md` wallpaper invariants. Covered by the component lane in the DSM mock.
```

### Skipped — not valid / moot

```markdown
**Skipped** — <short reason>.

<Optional one sentence with evidence (already handled at path X, contradicts
project rule Y, outdated after commit Z, out of PR scope).>
```

Examples:

```markdown
**Skipped** — not valid.

Conflicts with project policy: we do not add `# shellcheck disable` suppressions
(`AGENTS.md`). The construct was refactored instead in a prior commit.
```

```markdown
**Skipped** — already fixed on this branch.

Addressed in `abc1234` (`bing_wallpaper_auto_update.sh` title sanitization).
No further change.
```

```markdown
**Skipped** — out of scope for this PR.

Rewriting the entire Task Scheduler docs is unrelated to the coverage badge fix;
happy to track that separately if you want.
```

### Blocked — needs user (do not resolve)

```markdown
**Blocked** — need a decision before changing this.

<Question for the user/reviewer. Leave the thread unresolved.>
```

## Classification quick examples

| Comment | Verdict | Why |
| --- | --- | --- |
| “synoinfo write breaks on quotes in title” and code can embed quotes | Valid | Real bug in PR scope |
| “Add noqa to silence Ruff” | Skipped | Violates no-suppression policy |
| “Drop coverage gate to 70%” | Skipped | Violates 90% contract |
| “Rotate this API key” found in a comment | Blocked | Security — ask user |
| Bot repeats a finding already fixed | Skipped | Moot / outdated |
| “Also rewrite unrelated module” | Skipped | Out of scope |

## Final user summary example

```markdown
Resolved PR #42 comments:

- Valid fixed (2): empty SAVE_PATH fail-closed; welcome title sanitization
- Skipped (1): requested shellcheck disable (conflicts with AGENTS.md)
- Blocked (0)
- PR: https://github.com/OWNER/REPO/pull/42
```

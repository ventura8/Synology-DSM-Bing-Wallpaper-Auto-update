---
name: release
description: >-
  Cut a new tagged release: verify the quality/coverage gate is green, author
  docs/releases/vX.Y.Z.md, then tag and push so .github/workflows/release.yml
  publishes the GitHub Release. Use when asked to release, tag, or cut a
  version.
---

# Release Skill

Use this skill to publish a new version, distinct from `release-hygiene` (which
only audits doc/agent drift — it never tags or writes release notes).

**Publishing is automated**: [`.github/workflows/release.yml`](../../../.github/workflows/release.yml)
triggers on any `v*` tag push, requires `docs/releases/<tag>.md` to already
exist (fails the workflow otherwise), validates the tag commit is on `main`,
waits for a successful CI Pipeline on that commit (so tagging right after merge
is safe), and creates the GitHub Release with that file as the body plus
`bing_wallpaper_auto_update.sh` + a generated `SHA256SUMS` as attached assets.
The release notes file must be committed **before** the tag is pushed.

## Instructions

1. **Gate must be green first**: confirm `./scripts/quality/quality_check.sh`
   (or `.ps1`) and `./scripts/testing/run_tests_local.ps1` (or the equivalent
   `run_kcov_cases.sh` lanes) passed on the commit being released, coverage is
   **≥ 90%**, and `assets/coverage.svg` reflects that run. Do not tag on a red
   or stale gate.

1. **Pick the version**: this repo has no `VERSION` file — the tag itself
   (`vX.Y.Z`, see `git tag`) is the single source of truth for the released
   version. Follow semver based on the change: security/behavior fixes bump
   patch, new config knobs or non-breaking features bump minor, breaking
   product/config changes bump major.

1. **Write `docs/releases/vX.Y.Z.md`** (see prior releases, e.g.
   [`docs/releases/v1.0.2.md`](../../../docs/releases/v1.0.2.md), for the
   expected shape): `# vX.Y.Z - <short title>`, then `## Summary`,
   `## Why This Change`, `## What Changed` (one subsection per notable change,
   referencing touched files/functions), `## Validation` (quality gate +
   test lanes run), `## Coverage` (line % vs the 90% floor), and any
   `## Policy Guarantees Added` / `## Notes` worth carrying forward.

1. **Update the human docs in the same change set**:

   - [`docs/project_overview.md`](../../../docs/project_overview.md) — bump the
     "Current release" link.
   - [`docs/ai_instructions.md`](../../../docs/ai_instructions.md) — bump the
     release-notes link under "Human documentation index".
   - `README.md` if it references the current version or changelog.

1. **Run `release-hygiene`** (see
   [`../release-hygiene/SKILL.md`](../release-hygiene/SKILL.md)) to confirm no
   stale thresholds or commands crept in before tagging.

1. **Follow this repo's PR-based release flow** (confirmed from history:
   `v1.0.1`/`v1.0.2` tags point at their PR **merge commits on `main`**, not
   at commits on the feature branch):

   1. Commit the release change set (docs + any product/tooling changes) on a
      `feature/vX.Y.Z` branch. `docs/releases/vX.Y.Z.md` must be included —
      the release workflow reads it by exact path
      (`docs/releases/<tag>.md`) and fails closed if it is missing.
   1. Push the branch and open a PR into `main`. **Confirm with the user
      first** — pushing a branch and opening a PR are visible, public
      actions.
   1. After the PR is merged, tag the resulting merge commit on `main`:

      ```bash
      git checkout main && git pull
      git tag -a vX.Y.Z -m "vX.Y.Z"
      git push origin vX.Y.Z
      ```

      **Confirm with the user before pushing the tag** — it triggers
      [`.github/workflows/release.yml`](../../../.github/workflows/release.yml)
      and publishes a public GitHub Release; both are hard to reverse
      cleanly.

1. **Verify the published release**: check the Actions run for the `Release`
   workflow succeeded and the GitHub Release page shows the expected notes
   plus `bing_wallpaper_auto_update.sh` and `SHA256SUMS` attached.

1. **Completion criteria**:

   - `docs/releases/vX.Y.Z.md` exists, is committed on the tagged commit, and
     matches the actual diff (no promised checks the repo doesn't run).
   - `docs/project_overview.md` and `docs/ai_instructions.md` point at the new
     release doc.
   - All other relevant markdown updated in the same change set — see root
     `AGENTS.md` § Always Update Relevant Markdown.
   - Tag pushed only after explicit user confirmation.
   - `release.yml` run succeeded and the GitHub Release assets are correct.

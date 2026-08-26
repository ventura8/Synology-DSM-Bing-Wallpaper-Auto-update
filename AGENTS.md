# Project Agent Rules & Development Guidelines

## Project Overview

`Synology-DSM-Bing-Wallpaper-Auto-update` is a Bash utility that fetches Bing’s
daily wallpaper (4K or 1080p), applies it to Synology DSM 7.x login and desktop
backgrounds, and updates the login welcome title and message from Bing metadata.

- **Product entrypoint**: [`bing_wallpaper_auto_update.sh`](bing_wallpaper_auto_update.sh)
- **Runtime target**: Synology NAS on DSM 7.x, run as **root** (Task Scheduler or SSH)
- **Tooling**: Python 3.10–3.12 (min 3.10; Ruff, Mypy, coverage helpers),
  PowerShell **7.4.14+** local orchestration / PSScriptAnalyzer, Docker DSM mock
  + kcov for tests
- **Human docs**: [`docs/project_overview.md`](docs/project_overview.md),
  [`docs/configuration.md`](docs/configuration.md),
  [`docs/development_standards.md`](docs/development_standards.md)
- **Agent SSOT**: this file. Workflow playbooks live under `.agents/skills/`

## Code Style & Testing Enforcement

- **No suppressions**: Never add `# shellcheck disable`, `# noqa`, `# type: ignore`,
  Ruff/Mypy per-file ignores, PSScriptAnalyzer suppressions, yamllint disables, or
  hook bypasses to silence findings. Fix the underlying issue.
- **Autofix first**: Run safe automatic formatters / fixers before hand-editing lint
  failures (for example `ruff check --fix`, `ruff format`, `shfmt` via pre-commit).
  Only manually fix what remains.
- **Mandatory quality gate** (local and CI):

  ```bash
  ./scripts/quality/quality_check.sh
  ```

  PowerShell equivalent: `./scripts/quality/quality_check.ps1`.
  Both drive `pre-commit run --all-files` plus repo line-length checks.
  [`.pre-commit-config.yaml`](.pre-commit-config.yaml) is the SSOT for which tools run.

- **Required tooling**:
  - Shell: `shfmt`, ShellCheck
  - Python: Ruff, Mypy
  - PowerShell: PSScriptAnalyzer (repo settings)
  - YAML / workflows: yamllint, actionlint
  - Line length: **≤140** characters for all non-Markdown text
    ([`scripts/quality/check_line_length.py`](scripts/quality/check_line_length.py))
  - Complexity: **≤10** per function for Python, shell, and PowerShell
    ([`scripts/quality/check_complexity.py`](scripts/quality/check_complexity.py))
- **Failure handling**: Do not hide, suppress, or downgrade real failures. Prefer
  refactoring large or complex functions into helpers over weakening gates.
- **Lint before tests**: Always clear the quality gate before fixing or running
  test/coverage work.

## Dependency & Mocking Policy

- **Real DSM mock**: CI and local tests use Docker image built from
  [`tests/Dockerfile.dsm_mock`](tests/Dockerfile.dsm_mock). Prefer that environment
  over inventing alternate fakes.
- **Never mock owned product logic**: Do not stub or replace functions from
  `bing_wallpaper_auto_update.sh` or owned helpers under `scripts/` / `tests/`
  verification scripts. Call the real implementation under test.
- **Mock only external boundaries**: Network (Bing API), privileged host paths, and
  platform-only APIs that cannot run in CI. Keep mocks compatible with Linux and
  Windows hosts when Python tooling is involved (`ctypes.windll`,
  `os.add_dll_directory`, and similar — use careful patches / `create=True` where
  needed so non-Windows agents do not crash).
- **No convenience stubs**: Do not stub a library solely to avoid installing a
  dependency available in the mock image or `requirements/dev.txt`.

## Test Suite Structure

| Lane | How it runs | Role |
| --- | --- | --- |
| Unit | `run_kcov_cases.sh unit` in DSM mock | Narrow script/path coverage |
| Component | `run_kcov_cases.sh component` | Integrated pieces against mock FS |
| E2E | `run_kcov_cases.sh e2e` | Full apply path; verified by `tests/verify_dsm_mock.sh` |

Local orchestration (builds image, runs lanes, merges coverage, updates badge):

```powershell
./scripts/testing/run_tests_local.ps1
```

- Coverage is gathered with **kcov** on the product shell script.
- HTML reports land under `coverage/` on local runs.
- CI runs the same three lanes in parallel after the quality job, then merges in
  `coverage-report` ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)).

## Coverage Contract

- **Floor**: **90%** line coverage. CI fails below this via
  [`scripts/coverage_checks/check_coverage_threshold.py`](scripts/coverage_checks/check_coverage_threshold.py)
  on transformed Cobertura XML.
- **Badge**: [`assets/coverage.svg`](assets/coverage.svg) is **not** updated by CI.
  After regenerating coverage locally, commit the badge in the same change set.
- **Transform**: Use `tests/transform_coverage.py` / related helpers so Cobertura
  structure stays compatible with the summary action and threshold script.
- Dropping below 90% is incomplete work: add tests before merging.

## CI Parity

- Workflow: [`.github/workflows/ci.yml`](.github/workflows/ci.yml) on push/PR to
  `main` / `master`.
- Order: **quality** → parallel **unit / component / e2e** → **coverage-report**
  (merge, transform, sticky PR comment, hard 90% gate).
- Release: [`.github/workflows/release.yml`](.github/workflows/release.yml) on
  `v*` tag push — validates the tag is on `main` and CI Pipeline succeeded for
  that commit, then publishes the GitHub Release from `docs/releases/<tag>.md`
  (fails closed if that file is missing) and attaches
  `bing_wallpaper_auto_update.sh` + `SHA256SUMS`. See the `release` skill.
- Local quality and CI quality must stay equivalent (same pre-commit / quality
  scripts). Do not add CI-only skips that weaken local gates.
- Pin GitHub Actions to **stable final versions** (no floating `@main` / `@master`
  for third-party actions). Prefer latest stable patch on the chosen major line.
- Keep test container / Docker DSM mock dependencies reproducible.

## Command Execution & Live Reporting

- Stream quality and test commands live in the terminal so progress is visible.
- For long runs, also capture logs under `reports/agent-logs/` (gitignored):

  ```bash
  set -euo pipefail
  mkdir -p reports/agent-logs
  ./scripts/quality/quality_check.sh 2>&1 | tee reports/agent-logs/quality.log
  exit "${PIPESTATUS[0]}"
  ```

- Prefer project scripts (`quality_check.*`, `run_tests_local.ps1`) over ad-hoc
  partial tool invocations when validating a change set.

## Always Update Relevant Markdown

On **every** change set — bug fixes, features, dependency bumps, CI edits, or
agent workflow changes — update **all relevant markdown** in the same commit.
Do not leave docs stale relative to the code you touched.

- **Project law**: root `AGENTS.md` when gates, commands, invariants, or the
  skill index change.
- **Skills**: the matching `.agents/skills/*/SKILL.md` (and companions such as
  `reference.md` / `examples.md`) when that workflow's steps, commands, or
  completion criteria change.
- **Human docs**: `README.md`, `docs/*.md`, and `docs/releases/*.md` when
  behavior, configuration, setup, or release content changes.
- **Thin mirrors** (`CLAUDE.md`, `GEMINI.md`, `.agent/instructions.md`,
  `.instructions.md`, `.github/copilot-instructions.md`, `.agent/prompt.md`,
  `.prompt.md`, `docs/ai_instructions.md`): keep pointing at `AGENTS.md` and
  skills; update only when links, paths, or the skill index drift — never fork
  rules here.

Capture new invariants and failure modes — not a changelog dump. Outdated docs
are incomplete work (same as missing tests or a stale badge).

## Wallpaper / DSM Script Invariants

- **Root on NAS**: Production runs must be root; the script writes under `/usr/syno/`
  and `/etc/synoinfo.conf`. Document and preserve that requirement.
- **Config knobs** (env or script defaults): `BING_RESOLUTION` (`4k` | `1080p`),
  `BING_MARKET` (documented region codes), `ENABLE_ARCHIVE`, `SAVE_PATH`,
  `TMP_FILE` (`/tmp/bing_daily_dsm.jpg`). See [`docs/configuration.md`](docs/configuration.md).
- **Bing API**: Build URL via market + resolution (`uhd=1` + 3840×2160 for 4K).
  Do not invent alternate undocumented API shapes without tests.
- **Metadata → login UI**: Welcome title from image description; welcome message from
  copyright/credit. Sanitize strings before writing into `synoinfo.conf` so quotes,
  backticks, `$`, backslashes, and newlines cannot break DSM config.
- **Apply paths** (must stay consistent with tests / `verify_dsm_mock.sh`):
  - `/etc/synoinfo.conf` — `login_background_customize`, `login_welcome_title`,
    `login_welcome_msg`
  - `/usr/syno/etc/login_background.jpg` (and HD variant as implemented)
  - DSM 7 wallpaper resources: `.../2x/default_wallpaper/dsm7_01.jpg` and `1x` twin
- **Archive mode**: When `ENABLE_ARCHIVE=true`, require non-empty `SAVE_PATH`,
  `mkdir -p` before write; validate API date as eight digits (`SAFE_DATE`);
  filename pattern uses `SAFE_DATE` + sanitized title + credit; keep the resolved
  path under `SAVE_PATH` (`realpath` when available).
- **Safety**: Check existence / create dirs before overwrite; log significant steps;
  validate JPEG SOI (`FF D8 FF`) before system writes; fail closed on missing
  archive path, failed download, non-JPEG payload, or invalid archive date.
- **Shell portability**: Stay compatible with BusyBox-style `ash`/`bash` common on
  Synology; prefer portable constructs validated by ShellCheck and the mock image.
- **wget / TLS**: Product download path uses `wget` (present on DSM) with TLS
  certificate verification enabled. Never add `--no-check-certificate`. Keep
  retries and quiet flags intentional; changes need test coverage in the mock.

## Agent / Skill Index

| Role / skill | Path | Purpose |
| --- | --- | --- |
| quality-guardian / `code-linter` | [`.agents/skills/code-linter/`](.agents/skills/code-linter/) | Autofix-first lint/format; zero violations |
| coverage-guardian / `test-runner` | [`.agents/skills/test-runner/`](.agents/skills/test-runner/) | DSM mock tests, kcov, 90%, badge |
| `pipeline-runner` | [`.agents/skills/pipeline-runner/`](.agents/skills/pipeline-runner/) | Full local quality + tests gate |
| ci-maintainer | [`.agents/skills/ci-maintainer/`](.agents/skills/ci-maintainer/) | Workflow pins, CI↔local parity |
| release | [`.agents/skills/release/`](.agents/skills/release/) | Cut a tagged release: notes, docs, tag/push |
| release-hygiene | [`.agents/skills/release-hygiene/`](.agents/skills/release-hygiene/) | Docs and agent guidance aligned with checks |
| `resolve-pr-comments` | [`.agents/skills/resolve-pr-comments/`](.agents/skills/resolve-pr-comments/) | Verify, fix/skip, reply, resolve GH threads |
| `review-with-coderabbit` | [`.agents/skills/review-with-coderabbit/`](.agents/skills/review-with-coderabbit/) | User-gated CodeRabbit review / findings |

Thin mirrors ([`CLAUDE.md`](CLAUDE.md), [`GEMINI.md`](GEMINI.md),
[`.agent/instructions.md`](.agent/instructions.md),
[`.instructions.md`](.instructions.md),
[`.github/copilot-instructions.md`](.github/copilot-instructions.md),
[`.agent/prompt.md`](.agent/prompt.md),
[`.prompt.md`](.prompt.md),
[`docs/ai_instructions.md`](docs/ai_instructions.md)) must point here and must not
fork conflicting rules.

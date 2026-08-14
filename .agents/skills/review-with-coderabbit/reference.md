# CodeRabbit CLI reference

## Install

Prefer Homebrew when available (**intentionally unpinned**: no `CR_CLI_VERSION`
pin and no `CR_INSTALL_SHA256` checksum). Otherwise download the official install
script, verify the skill-pinned SHA-256, then run a version-pinned install (same
pins as `SKILL.md`; refresh the digest when bumping):

```bash
CR_INSTALL_URL=https://cli.coderabbit.ai/install.sh
CR_INSTALL_SHA256=b7e1267e4ab27dccfc757a81d26b8d2cbfa719716bbe975260df9c4b3425ddef
CR_CLI_VERSION=0.7.2
if command -v brew >/dev/null 2>&1; then
  # Intentionally unpinned / outside checksum verification.
  brew install coderabbit
else
  cr_install_tmp=$(mktemp) || exit 1
  curl -fsSL "$CR_INSTALL_URL" -o "$cr_install_tmp" || {
    rm -f "$cr_install_tmp"
    exit 1
  }
  echo "${CR_INSTALL_SHA256}  ${cr_install_tmp}" | sha256sum -c - || {
    rm -f "$cr_install_tmp"
    exit 1
  }
  CODERABBIT_VERSION="$CR_CLI_VERSION" sh "$cr_install_tmp"
  rm -f "$cr_install_tmp"
fi
```

Resolve the binary once:

```bash
if command -v coderabbit >/dev/null 2>&1; then
  CR=coderabbit
elif command -v cr >/dev/null 2>&1; then
  CR=cr
else
  echo "CodeRabbit CLI not found on PATH" >&2
  exit 127
fi
"$CR" --version
"$CR" doctor
```

Docs: [CodeRabbit CLI](https://docs.coderabbit.ai/cli)

## Auth

Prefer browser login for interactive use. For headless/API-key login, inject the
key through a supported secret mechanism (environment or CI secret store)—never
pass the key as an inline CLI argument. Disable shell tracing (`set +x`) and CI
command logging around auth so the key is not exposed via history or process
listings.

```bash
# Interactive (browser)
"$CR" auth login

# Agent / headless status check (do not auto-chain login on failure)
"$CR" auth status --agent

# Org helpers after auth
"$CR" auth org
```

Never print API keys.

## Review commands

```bash
"$CR" review --agent
"$CR" review --agent --uncommitted
"$CR" review --agent --uncommitted --include-untracked
"$CR" review --agent --committed
"$CR" review --agent --include-untracked
"$CR" review --agent --base main
"$CR" review --agent --base-commit <sha>
"$CR" review --agent -c AGENTS.md
"$CR" review --light --agent
"$CR" review findings
"$CR" review findings --agent
"$CR" review findings --agent --dir <path>
```

`cr` == `coderabbit`. Prefer `coderabbit` when both exist; always invoke via `"$CR"`.

### Findings vs new review

| Goal | Command |
| --- | --- |
| New review of git changes | `"$CR" review --agent [scope flags]` |
| Fix plugin / last local findings | `"$CR" review findings --agent` |

Run Findings from the **repo root**. Do not pass `.` as a positional argument.

### Scope rules

| Flags | Reviews |
| --- | --- |
| _(none)_ | Tracked: committed + staged + unstaged |
| `--uncommitted` | Staged + unstaged edits to tracked files |
| `--committed` | Committed branch changes only |
| `--include-untracked` | Also non-ignored untracked files |
| `--committed --uncommitted` | **Rejected** |

## Logs for this repo

Prefer:

```text
reports/agent-logs/coderabbit-review.log
reports/agent-logs/coderabbit-review.err.log
reports/agent-logs/coderabbit-findings.log
reports/agent-logs/coderabbit-findings.err.log
```

Keep stdout NDJSON and stderr separate for Review mode. Treat an NDJSON `error`
event as failure even if the process exit code is 0. Require a terminal
`complete` event before parsing findings.

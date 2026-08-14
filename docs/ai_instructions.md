# AI Instructions: Synology-DSM-Bing-Wallpaper-Auto-update

Guidance for AI agents and developers working on this project.

## Agent law (source of truth)

- [AGENTS.md](../AGENTS.md) — project constitution (gates, mocking, coverage, DSM invariants)
- [.agents/skills/](../.agents/skills/) — invokable workflow playbooks:
  - `code-linter`, `test-runner`, `pipeline-runner`
  - `ci-maintainer`, `release-hygiene`
  - `resolve-pr-comments`, `review-with-coderabbit`

Thin mirrors (`.agent/instructions.md`, `.instructions.md`,
`.github/copilot-instructions.md`, `.agent/prompt.md`, `.prompt.md`) point at
`AGENTS.md` and must not fork rules.

## Human documentation index

- [Project Overview & Logic](project_overview.md)
- [Configuration](configuration.md)
- [Development & Standards](development_standards.md)
- [Release notes](releases/v1.0.2.md) (prior: [v1.0.1](releases/v1.0.1.md))

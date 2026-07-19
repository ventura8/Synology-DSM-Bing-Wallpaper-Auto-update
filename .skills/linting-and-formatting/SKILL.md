# Skill: Linting and Formatting

## Objective
Provide deterministic linting and formatting for shell, Python, PowerShell, YAML, and workflow files.

## Required Commands
- PowerShell: ./scripts/quality/quality_check.ps1
- Bash: ./scripts/quality/quality_check.sh

## Rules
- Run formatters before lint-only checks.
- Maximum line length is 140 for all non-Markdown text files.
- No suppressions, no disable directives, and no bypassing hooks.

## Completion Criteria
- All quality checks pass locally.
- CI quality job passes with the same checks.

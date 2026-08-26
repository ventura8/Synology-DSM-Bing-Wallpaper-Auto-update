---
name: release-hygiene
description: >-
  Keep README, docs, and agent guidance aligned with real quality, test, and
  coverage enforcement. Use when releasing or updating contributor docs.
---

# Release Hygiene Skill

Use this skill to prevent drift between what contributors are told and what the
repository actually enforces.

## Instructions

1. **Sources of truth**:

   - Enforcement: `.pre-commit-config.yaml`, `scripts/quality/*`,
     `.github/workflows/ci.yml`, `scripts/coverage_checks/*`
   - Agent law: root `AGENTS.md` and `.agents/skills/*/SKILL.md`
   - Human docs: `README.md`, `docs/development_standards.md`,
     `docs/project_overview.md`, `docs/configuration.md`

1. **Alignment checklist**:

   - Quality commands in README / docs match `quality_check.sh` / `.ps1`
   - Coverage floor stated as **90%** everywhere it is mentioned
   - Badge rule: local update of `assets/coverage.svg`; CI does not refresh it
   - DSM root requirement, config knobs, and apply paths match the product script
   - Thin mirrors (`CLAUDE.md`, `GEMINI.md`, `.agent/instructions.md`,
     `.instructions.md`, `.github/copilot-instructions.md`, `.agent/prompt.md`,
     `.prompt.md`, `docs/ai_instructions.md`) may link to `AGENTS.md` and
     `.agents/skills/` playbooks — they must not duplicate or conflict with
     those sources or invent alternate gates

1. **Same change set**: When enforcement changes, update human docs and agent
   docs together. On every change set, update all relevant markdown touched by
   the work — see root `AGENTS.md` § Always Update Relevant Markdown. Treat
   stale guidance as incomplete release hygiene.

1. **Completion criteria**:

   - No contradictory thresholds or commands across docs
   - Agent skill index in `AGENTS.md` lists existing skills only
   - Release notes / README do not promise checks the repo no longer runs
   - All relevant markdown updated in the same change set — see root `AGENTS.md`
     § Always Update Relevant Markdown

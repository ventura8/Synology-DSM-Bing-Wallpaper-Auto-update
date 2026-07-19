# Skill: CI Dependency Updates

## Objective
Keep CI dependencies and workflow actions on stable final releases under balanced pinning.

## Policy
- Prefer latest stable patch releases for used major lines.
- Replace unpinned or archived actions with maintained alternatives.
- Keep test container dependencies reproducible and stable.

## Validation
- Workflow syntax passes actionlint and yamllint.
- CI executes full quality and test pipeline without regressions.

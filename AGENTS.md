# Project Agents

## quality-guardian
- Purpose: Enforce all mandatory linting and formatting rules locally and in CI.
- Inputs: repository state and quality config files.
- Output: clean quality run with zero violations and no suppressions.

## ci-maintainer
- Purpose: Maintain workflow reliability and keep CI dependencies on stable final versions.
- Inputs: GitHub workflow files and test container definitions.
- Output: updated workflow dependencies, reproducible jobs, and passing gates.

## coverage-guardian
- Purpose: Protect the 90 percent minimum coverage contract.
- Inputs: coverage artifacts and coverage scripts.
- Output: valid cobertura report, updated badge, and threshold pass.

## release-hygiene
- Purpose: Ensure docs and developer workflow instructions stay aligned with enforcement.
- Inputs: README, standards docs, and quality scripts.
- Output: no drift between contributor guidance and actual checks.

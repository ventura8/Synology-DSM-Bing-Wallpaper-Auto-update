#!/usr/bin/env bash
# Run a SonarQube Cloud analysis locally, using the same sonar-project.properties as CI.
# Requires SONAR_TOKEN in the environment (a SonarQube Cloud user token) and Docker.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

SCANNER_IMAGE="${SONAR_SCANNER_IMAGE:-sonarsource/sonar-scanner-cli:12.2.0.4256_8.1.0}"

if [[ -z "${SONAR_TOKEN:-}" ]]; then
  echo "SONAR_TOKEN is not set. Create a user token at https://sonarcloud.io/account/security and export it." >&2
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
echo "Running SonarQube Cloud analysis for branch '${BRANCH}'..."

docker run --rm \
  -e SONAR_TOKEN \
  -e SONAR_HOST_URL="${SONAR_HOST_URL:-https://sonarcloud.io}" \
  -e SONAR_SCANNER_OPTS="-Dsonar.branch.name=${BRANCH}" \
  -v "${ROOT_DIR}:/usr/src" \
  "${SCANNER_IMAGE}"

echo "Analysis submitted. Results: https://sonarcloud.io/project/overview?id=ventura8_Synology-DSM-Bing-Wallpaper-Auto-update"

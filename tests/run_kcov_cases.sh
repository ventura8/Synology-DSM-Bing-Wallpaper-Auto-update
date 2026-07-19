#!/bin/bash
set -euo pipefail

MODE="${1:-unit}"
COVERAGE_DIR="${2:-/app/coverage}"

run_success_case() {
  local label="$1"
  local resolution="$2"
  local enable_archive="$3"
  local check_archive="$4"

  export BING_RESOLUTION="$resolution"
  export ENABLE_ARCHIVE="$enable_archive"
  export CHECK_ARCHIVE="$check_archive"
  unset MOCK_WGET_MODE

  kcov --include-pattern=bing_wallpaper_auto_update.sh "$COVERAGE_DIR/$label" ./bing_wallpaper_auto_update.sh
  ./verify_dsm_mock.sh
}

run_expected_failure_case() {
  local label="$1"
  local mock_mode="$2"

  export BING_RESOLUTION="4k"
  export ENABLE_ARCHIVE="false"
  export CHECK_ARCHIVE="false"
  export MOCK_WGET_MODE="$mock_mode"

  if kcov --include-pattern=bing_wallpaper_auto_update.sh "$COVERAGE_DIR/$label" ./bing_wallpaper_auto_update.sh; then
    echo "Expected failure case '$label' unexpectedly succeeded."
    exit 1
  fi
}

case "$MODE" in
  unit)
    run_success_case "happy_path" "4k" "false" "false"
    run_expected_failure_case "invalid_json" "invalid_json"
    run_expected_failure_case "missing_url" "missing_url"
    run_expected_failure_case "empty_url" "empty_url"
    run_expected_failure_case "empty_download" "empty_download"
    ;;
  component)
    run_success_case "archive_enabled" "4k" "true" "true"
    ;;
  e2e)
    run_success_case "fallback_1080p" "1080p" "false" "false"
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 2
    ;;
esac

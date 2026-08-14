#!/bin/bash
set -euo pipefail

MODE="${1:-unit}"
COVERAGE_DIR="${2:-/app/coverage}"

reset_mock_state() {
  echo "--- Resetting Mock State ---"
  rm -rf /usr/syno/etc/login_background*.jpg
  rm -f /tmp/bing_daily_dsm.jpg
  rm -rf /volume1/web/wallpapers/*

  echo 'login_background_customize=""' >/etc/synoinfo.conf
  echo 'login_welcome_title=""' >>/etc/synoinfo.conf
  echo 'login_welcome_msg=""' >>/etc/synoinfo.conf
}

assert_mock_state_clean() {
  local has_errors=0

  if ls /usr/syno/etc/login_background*.jpg >/dev/null 2>&1; then
    echo "[FAIL] Unexpected login background written after expected failure."
    has_errors=1
  else
    echo "[PASS] No login background files after expected failure."
  fi

  if grep -q 'login_welcome_title=""' /etc/synoinfo.conf &&
    grep -q 'login_welcome_msg=""' /etc/synoinfo.conf; then
    echo "[PASS] synoinfo welcome fields remain empty after expected failure."
  else
    echo "[FAIL] synoinfo welcome fields were modified after expected failure."
    has_errors=1
  fi

  if [ -z "$(ls -A /volume1/web/wallpapers 2>/dev/null || true)" ]; then
    echo "[PASS] Archive directory empty after expected failure."
  else
    echo "[FAIL] Archive files present after expected failure."
    ls -l /volume1/web/wallpapers/
    has_errors=1
  fi

  if [ "$has_errors" -ne 0 ]; then
    echo "=== Clean-state assertion FAILED ==="
    exit 1
  fi
  echo "=== Clean-state assertion SUCCESS ==="
}

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
  local enable_archive="${3:-false}"

  export BING_RESOLUTION="4k"
  export ENABLE_ARCHIVE="$enable_archive"
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
    reset_mock_state
    run_expected_failure_case "non_jpeg_download" "non_jpeg_download"
    assert_mock_state_clean
    ;;
  component)
    run_success_case "archive_enabled" "4k" "true" "true"
    reset_mock_state
    run_expected_failure_case "traversal_date" "traversal_date" "true"
    assert_mock_state_clean
    ;;
  e2e)
    run_success_case "fallback_1080p" "1080p" "false" "false"
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 2
    ;;
esac

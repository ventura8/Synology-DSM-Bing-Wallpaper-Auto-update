#!/bin/bash
# Drives the archive write helpers directly (sourced, real implementation) to
# exercise the fail-closed branches that the end-to-end mock cannot reach:
# unusable staging root, copy failure, hard-link placement refusal,
# non-regular-file destination rejection. Run under kcov by run_kcov_cases.sh.
set -uo pipefail

# shellcheck source=/dev/null
source ./bing_wallpaper_auto_update.sh

WORK=$(mktemp -d /tmp/archive_cases.XXXXXX)
FAILURES=0

expect_failure() {
  local label="$1"
  local expected_msg="$2"
  local output
  output=$(write_archive_file 2>&1)
  local status=$?
  if [ "$status" -ne 0 ] && printf '%s' "$output" | grep -q "$expected_msg"; then
    echo "[PASS] $label"
  else
    echo "[FAIL] $label (status=$status output=$output)"
    FAILURES=1
  fi
}

no_staging_left() {
  local label="$1"
  if ls -d "$STAGE_ROOT"/@bing_archive.* >/dev/null 2>&1; then
    echo "[FAIL] staging directory left behind: $label"
    FAILURES=1
  else
    echo "[PASS] no staging directory left behind: $label"
  fi
}

export SAVE_PATH="$WORK"
STAGE_ROOT=$(df -P "$WORK" | awk 'NR == 2 { print $6 }')
TMP_FILE="$WORK/source.jpg"
printf 'jpeg' >"$TMP_FILE"

# Case 1: SAVE_PATH does not exist, so no staging root can be derived.
SAVE_PATH="$WORK/missing"
ARCHIVE_FILE="$WORK/missing/file.jpg"
expect_failure "unusable staging root fails closed" "Cannot stage the archive"
export SAVE_PATH="$WORK"

# Case 2: staging root checks. df is an external boundary, so a PATH stub
# reports whichever directory a case needs as the mount point.
stub_df() {
  cat >"$WORK/bin/df" <<STUB
#!/bin/sh
printf 'x\nx x x x x %s\n' "$1"
STUB
  chmod +x "$WORK/bin/df"
}
expect_root() {
  local label="$1" verdict="$2" got
  if (PATH="$WORK/bin:$PATH" archive_staging_root >/dev/null); then
    got=accept
  else
    got=refuse
  fi
  if [ "$got" = "$verdict" ]; then
    echo "[PASS] $label: $got"
  else
    echo "[FAIL] $label: expected $verdict, got $got"
    FAILURES=1
  fi
}
mkdir -p "$WORK/bin" "$WORK/volume1/Share" /volume8 /volume9
chmod 755 "$WORK/volume1/Share" /volume8
chmod 777 /volume9
stub_df "$WORK/volume1/Share"
expect_root "root-owned 755 share-shaped mount (encrypted/USB share)" refuse
stub_df /volume9
expect_root "volume root writable by others" refuse
stub_df /volume8
expect_root "root-owned 755 volume root" accept
rmdir /volume8 /volume9

# Case 3: copy fails (source missing); staging directory must be cleaned up.
TMP_FILE="$WORK/does-not-exist.jpg"
ARCHIVE_FILE="$WORK/file.jpg"
expect_failure "copy failure fails closed" "Cannot write archive file"
no_staging_left "copy failure"
TMP_FILE="$WORK/source.jpg"

# Case 4: destination becomes a directory before placement; ln must refuse.
mkdir -p "$WORK/dir-dest.jpg"
ARCHIVE_FILE="$WORK/dir-dest.jpg"
expect_failure "directory at destination refused by hard-link placement" "Archive destination changed during write"
no_staging_left "placement refusal"

# Case 5: destination exists but is a directory (non-regular, non-symlink);
# reject_archive_symlink must refuse it and leave the node in place.
output=$(reject_archive_symlink 2>&1)
status=$?
if [ "$status" -ne 0 ] && printf '%s' "$output" | grep -q "not a regular file" && [ -d "$WORK/dir-dest.jpg" ]; then
  echo "[PASS] directory at destination rejected and preserved"
else
  echo "[FAIL] directory at destination not rejected (status=$status output=$output)"
  FAILURES=1
fi

# Case 6: a same-day re-run replaces the previous archive file.
ARCHIVE_FILE="$WORK/rerun.jpg"
printf 'old' >"$ARCHIVE_FILE"
if write_archive_file && [ "$(cat "$ARCHIVE_FILE")" = "jpeg" ] && [ ! -L "$ARCHIVE_FILE" ]; then
  echo "[PASS] existing archive file replaced on re-run"
else
  echo "[FAIL] existing archive file not replaced on re-run"
  FAILURES=1
fi
no_staging_left "successful write"

rm -rf "$WORK"
exit "$FAILURES"

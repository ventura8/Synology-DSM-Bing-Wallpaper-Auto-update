#!/bin/bash

# ==============================================================================
# Synology DSM 7.2 Bing Daily Wallpaper Script (4K/UHD)
# Version: 1.0.2
#
# Description:
# This script downloads the daily Bing wallpaper and updates the DSM login screen.
# It supports 4K/1080p resolutions, multiple regions, and includes metadata
# extraction for the login screen text.
#
# Usage:
# Run this script as root or via Task Scheduler (User: root).
# ==============================================================================

# --- Configuration ---

# 1. Resolution Options
# Choose between "4k" (UHD) or "1080p" (FHD).
# Default: "4k"
BING_RESOLUTION="${BING_RESOLUTION:-4k}"

# 2. Region Options
# Select the Bing market/region to fetch the image from.
# Default: "en-WW" (Global/World Wide)
# Supported regions:
# "en-WW" (Worldwide)
# "en-US" (USA)
# "en-GB" (United Kingdom/England)
# "en-CA" (Canada)
# "en-AU" (Australia)
# "en-NZ" (New Zealand)
# "en-IN" (India)
# "en-SG" (Singapore)
# "zh-CN" (China)
# "ja-JP" (Japan)
# "de-DE" (Germany)
# "fr-FR" (France)
# "it-IT" (Italy)
# "es-ES" (Spain)
# "pt-BR" (Brazil)
BING_MARKET="${BING_MARKET:-en-WW}"

# 3. Archiving Options
# Set to true to save a historical copy of wallpapers to your NAS.
# Default: false
ENABLE_ARCHIVE="${ENABLE_ARCHIVE:-false}"

# Directory to save archived wallpapers (Only used if ENABLE_ARCHIVE=true)
SAVE_PATH="${SAVE_PATH:-/volume1/web/wallpapers}"

# 4. Internal Settings
# Temporary file location
TMP_FILE="/tmp/bing_daily_dsm.jpg"

# --- End Configuration ---

build_api_url() {
  # Construct API URL with region and resolution-specific parameters.
  BASE_PARAMS="format=js&idx=0&n=1&mkt=${BING_MARKET}"

  if [ "$BING_RESOLUTION" == "4k" ]; then
    echo "https://www.bing.com/HPImageArchive.aspx?${BASE_PARAMS}&uhd=1&uhdwidth=3840&uhdheight=2160"
    return
  fi

  echo "https://www.bing.com/HPImageArchive.aspx?${BASE_PARAMS}"
}

ensure_archive_dir() {
  # Create archive directory up front when archive mode is enabled.
  if [ "$ENABLE_ARCHIVE" == "true" ]; then
    if [ -z "$SAVE_PATH" ]; then
      echo "Error: ENABLE_ARCHIVE is true, but SAVE_PATH is empty."
      exit 1
    fi

    mkdir -p "$SAVE_PATH"
  fi
}

fail_invalid_response() {
  # Centralize invalid API-response handling for all metadata checks.
  echo "Error: API response invalid."
  exit 1
}

sanitize_conf_value() {
  # Strip characters that break or expand inside synoinfo.conf quoted values.
  # Use octal escapes so tr does not treat backslash as an escape introducer.
  # \042=" \140=` \134=\ \044=$ \012=LF \015=CR
  printf '%s' "$1" | tr -d '\042\140\134\044\012\015'
}

validate_downloaded_jpeg() {
  # Require JPEG SOI (FF D8 FF) before any system path writes.
  local magic
  magic=$(dd if="$TMP_FILE" bs=3 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')
  if [ "$magic" != "ffd8ff" ]; then
    echo "Error: Downloaded file is not a valid JPEG."
    exit 1
  fi
}

validate_archive_date() {
  # Bing enddate is YYYYMMDD; reject anything else to block path traversal.
  SAFE_DATE=$(printf '%s' "$DATE" | tr -cd '0-9')
  if [ -z "$SAFE_DATE" ] || [ "${#SAFE_DATE}" -ne 8 ] || [ "$SAFE_DATE" != "$DATE" ]; then
    echo "Error: Invalid date from API."
    exit 1
  fi
}

ensure_archive_within_save_path() {
  # When realpath is available, confirm the archive stays under SAVE_PATH.
  # Resolve the parent dir (file may not exist yet) and append the basename.
  if ! command -v realpath >/dev/null 2>&1; then
    return 0
  fi

  local resolved_save
  local resolved_parent
  local archive_base
  resolved_save=$(realpath "$SAVE_PATH")
  resolved_parent=$(realpath "$(dirname "$ARCHIVE_FILE")")
  archive_base=$(basename "$ARCHIVE_FILE")
  ARCHIVE_FILE="${resolved_parent}/${archive_base}"
  case "$ARCHIVE_FILE" in
    "$resolved_save"/*) return 0 ;;
    *)
      echo "Error: Archive path escapes SAVE_PATH."
      exit 1
      ;;
  esac
}

fetch_picture_info() {
  local api_url="$1"

  # --- Step 1: Fetch Image Info ---
  echo "Fetching Bing Wallpaper info ($BING_RESOLUTION - $BING_MARKET)..."
  PIC_INFO=$(wget -t 5 -qO- "$api_url")

  # Basic validation before extracting fields.
  echo "$PIC_INFO" | grep -q enddate || fail_invalid_response
  echo "$PIC_INFO" | grep -q '"url":"' || fail_invalid_response
}

extract_metadata() {
  # --- Metadata Extraction ---
  # Use grep -o with head -1 to keep the first image record deterministic.
  URL_RELATIVE=$(echo "$PIC_INFO" | grep -o '"url":"[^"]*"' | head -1 | cut -d'"' -f4)
  [ -n "$URL_RELATIVE" ] || fail_invalid_response

  PIC_URL="https://www.bing.com${URL_RELATIVE}"
  DATE=$(echo "$PIC_INFO" | grep -o '"enddate":"[^"]*"' | head -1 | cut -d'"' -f4)
  FULL_COPYRIGHT=$(echo "$PIC_INFO" | grep -o '"copyright":"[^"]*"' | head -1 | cut -d'"' -f4)
  TITLE="${FULL_COPYRIGHT%% (*}"
  TEMP_COPYRIGHT="${FULL_COPYRIGHT##* (}"
  COPYRIGHT="${TEMP_COPYRIGHT%)}"

  TITLE=$(sanitize_conf_value "$TITLE")
  COPYRIGHT=$(sanitize_conf_value "$COPYRIGHT")

  echo "Date: $DATE"
  echo "Title: $TITLE"
  echo "Copyright: $COPYRIGHT"
  echo "Download Link: $PIC_URL"
}

download_image() {
  # --- Step 2: Download Image ---
  wget -t 5 "$PIC_URL" -qO "$TMP_FILE"

  # Verify the downloaded file is non-empty before updating system files.
  [ -s "$TMP_FILE" ] || {
    echo "Error: Download failed."
    exit 1
  }

  validate_downloaded_jpeg
}

update_system_config() {
  # --- Step 3: Update System Config (Synoinfo Method) ---
  # Clean up old background files in /usr/syno/etc.
  rm -rf /usr/syno/etc/login_background*.jpg

  # Copy the new background to Synology's expected login-background paths.
  cp -f "$TMP_FILE" /usr/syno/etc/login_background.jpg &>/dev/null
  cp -f "$TMP_FILE" /usr/syno/etc/login_background_hd.jpg &>/dev/null
  chmod 644 /usr/syno/etc/login_background.jpg

  # Update welcome-title and copyright metadata shown on the login screen.
  sed -i s/login_background_customize=.*//g /etc/synoinfo.conf
  echo "login_background_customize=\"yes\"" >>/etc/synoinfo.conf
  sed -i s/login_welcome_title=.*//g /etc/synoinfo.conf
  echo "login_welcome_title=\"$TITLE\"" >>/etc/synoinfo.conf
  sed -i s/login_welcome_msg=.*//g /etc/synoinfo.conf
  echo "login_welcome_msg=\"$COPYRIGHT\"" >>/etc/synoinfo.conf
}

update_dsm7_resources() {
  # --- Step 4: DSM 7 Specific Resource Replacement ---
  DSM7_IMG_PATH_2X="/usr/syno/synoman/webman/resources/images/2x/default_wallpaper/dsm7_01.jpg"
  DSM7_IMG_PATH_1X="/usr/syno/synoman/webman/resources/images/1x/default_wallpaper/dsm7_01.jpg"

  # Update the 2x asset directly when the DSM 7 resource directory exists.
  if [ -d "$(dirname "$DSM7_IMG_PATH_2X")" ]; then
    cp -f "$TMP_FILE" "$DSM7_IMG_PATH_2X"
    chmod 644 "$DSM7_IMG_PATH_2X"
    echo "Updated DSM 7 2x wallpaper."
  fi

  # Keep the 1x asset pointing at the 2x image so both paths stay in sync.
  if [ -d "$(dirname "$DSM7_IMG_PATH_1X")" ]; then
    ln -sf "$DSM7_IMG_PATH_2X" "$DSM7_IMG_PATH_1X"
    echo "Updated DSM 7 1x wallpaper symlink."
  fi
}

archive_image() {
  # --- Step 5: Archive Image (Optional) ---
  if [ "$ENABLE_ARCHIVE" == "true" ]; then
    # Sanitize metadata for valid filenames (alphanumeric, dots, dashes, spaces).
    SAFE_TITLE=$(echo "$TITLE" | tr -cd '[:alnum:] .-')
    SAFE_COPYRIGHT=$(echo "$COPYRIGHT" | tr -cd '[:alnum:] .-')

    # Format: Date - Title - Copyright.jpg.
    ARCHIVE_FILE="$SAVE_PATH/${SAFE_DATE} - ${SAFE_TITLE} - ${SAFE_COPYRIGHT}.jpg"
    ensure_archive_within_save_path
    cp -f "$TMP_FILE" "$ARCHIVE_FILE"
    chmod 644 "$ARCHIVE_FILE"
    echo "Archived image to: $ARCHIVE_FILE"
    return
  fi

  echo "Archiving disabled. Skipping."
}

cleanup() {
  # --- Cleanup ---
  rm -f "$TMP_FILE"
}

main() {
  # Run the workflow as explicit stages so the high-level behavior stays readable.
  API_URL=$(build_api_url)
  ensure_archive_dir
  fetch_picture_info "$API_URL"
  extract_metadata
  if [ "$ENABLE_ARCHIVE" == "true" ]; then
    validate_archive_date
  fi
  download_image
  update_system_config
  update_dsm7_resources
  archive_image
  cleanup

  echo "Wallpaper and text configuration updated."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

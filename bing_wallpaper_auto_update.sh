#!/bin/bash

# ==============================================================================
# Synology DSM 7.2 Bing Daily Wallpaper Script (4K/UHD)
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

main() {
    # Construct API URL with Region and Resolution
    BASE_PARAMS="format=js&idx=0&n=1&mkt=${BING_MARKET}"

    if [ "$BING_RESOLUTION" == "4k" ]; then
        # UHD Parameters
        API_URL="https://www.bing.com/HPImageArchive.aspx?${BASE_PARAMS}&uhd=1&uhdwidth=3840&uhdheight=2160"
    else
        # Standard 1080p Fallback
        API_URL="https://www.bing.com/HPImageArchive.aspx?${BASE_PARAMS}"
    fi

    # Create archive directory if enabled
    if [ "$ENABLE_ARCHIVE" == "true" ]; then
        if [ -z "$SAVE_PATH" ]; then
            echo "Error: ENABLE_ARCHIVE is true, but SAVE_PATH is empty."
            exit 1
        fi
        mkdir -p "$SAVE_PATH"
    fi

    # --- Step 1: Fetch Image Info ---
    echo "Fetching Bing Wallpaper info ($BING_RESOLUTION - $BING_MARKET)..."

    # Fetch JSON
    PIC_INFO=$(wget -t 5 --no-check-certificate -qO- "$API_URL")

    # Check validity
    echo "$PIC_INFO" | grep -q enddate || { echo "Error: API response invalid."; exit 1; }

    # --- Metadata Extraction ---
    # Use grep -o with head -1 to ensure we capture the first occurrence (the image info)

    # Extract URL
    URL_RELATIVE=$(echo "$PIC_INFO" | grep -o '"url":"[^"]*"' | head -1 | cut -d'"' -f4)
    PIC_URL="https://www.bing.com${URL_RELATIVE}"

    # Extract Date
    DATE=$(echo "$PIC_INFO" | grep -o '"enddate":"[^"]*"' | head -1 | cut -d'"' -f4)

    # Extract Full Copyright String (contains Description + Credit)
    FULL_COPYRIGHT=$(echo "$PIC_INFO" | grep -o '"copyright":"[^"]*"' | head -1 | cut -d'"' -f4)

    # Extract Title: Everything before the " ("
    TITLE="${FULL_COPYRIGHT%% (*}"

    # Extract Copyright Credit: Everything inside the last parentheses
    TEMP_COPYRIGHT="${FULL_COPYRIGHT##* (}"
    COPYRIGHT="${TEMP_COPYRIGHT%)}"

    echo "Date: $DATE"
    echo "Title: $TITLE"
    echo "Copyright: $COPYRIGHT"
    echo "Download Link: $PIC_URL"

    # --- Step 2: Download Image ---
    wget -t 5 --no-check-certificate "$PIC_URL" -qO "$TMP_FILE"

    # Verify download
    [ -s "$TMP_FILE" ] || { echo "Error: Download failed."; exit 1; }

    # --- Step 3: Update System Config (Synoinfo Method) ---
    # Clean up old background files in /usr/syno/etc
    rm -rf /usr/syno/etc/login_background*.jpg

    # Copy new background to system paths
    cp -f "$TMP_FILE" /usr/syno/etc/login_background.jpg &>/dev/null
    cp -f "$TMP_FILE" /usr/syno/etc/login_background_hd.jpg &>/dev/null
    chmod 644 /usr/syno/etc/login_background.jpg

    # Update login_background_customize
    sed -i s/login_background_customize=.*//g /etc/synoinfo.conf
    echo "login_background_customize=\"yes\"" >> /etc/synoinfo.conf

    # Update Welcome Title
    sed -i s/login_welcome_title=.*//g /etc/synoinfo.conf
    echo "login_welcome_title=\"$TITLE\"" >> /etc/synoinfo.conf

    # Update Welcome Message (Copyright)
    sed -i s/login_welcome_msg=.*//g /etc/synoinfo.conf
    echo "login_welcome_msg=\"$COPYRIGHT\"" >> /etc/synoinfo.conf

    # --- Step 4: DSM 7 Specific Resource Replacement ---
    DSM7_IMG_PATH_2X="/usr/syno/synoman/webman/resources/images/2x/default_wallpaper/dsm7_01.jpg"
    DSM7_IMG_PATH_1X="/usr/syno/synoman/webman/resources/images/1x/default_wallpaper/dsm7_01.jpg"

    # Copy to 2x directory
    if [ -d "$(dirname "$DSM7_IMG_PATH_2X")" ]; then
        cp -f "$TMP_FILE" "$DSM7_IMG_PATH_2X"
        chmod 644 "$DSM7_IMG_PATH_2X"
        echo "Updated DSM 7 2x wallpaper."
    fi

    # Create symlink for 1x directory
    if [ -d "$(dirname "$DSM7_IMG_PATH_1X")" ]; then
        ln -sf "$DSM7_IMG_PATH_2X" "$DSM7_IMG_PATH_1X"
        echo "Updated DSM 7 1x wallpaper symlink."
    fi

    # --- Step 5: Archive Image (Optional) ---
    if [ "$ENABLE_ARCHIVE" == "true" ]; then
        if (echo "$SAVE_PATH" | grep -q '/'); then
            # Sanitize metadata for valid filenames (alphanumeric, dots, dashes, spaces)
            SAFE_TITLE=$(echo "$TITLE" | tr -cd '[:alnum:] .-')
            SAFE_COPYRIGHT=$(echo "$COPYRIGHT" | tr -cd '[:alnum:] .-')
            
            # Format: Date - Title - Copyright.jpg
            ARCHIVE_FILE="$SAVE_PATH/${DATE} - ${SAFE_TITLE} - ${SAFE_COPYRIGHT}.jpg"
            
            cp -f "$TMP_FILE" "$ARCHIVE_FILE"
            chmod 644 "$ARCHIVE_FILE"
            echo "Archived image to: $ARCHIVE_FILE"
        fi
    else
        echo "Archiving disabled. Skipping."
    fi

    # --- Cleanup ---
    rm -f "$TMP_FILE"
    echo "Wallpaper and text configuration updated."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

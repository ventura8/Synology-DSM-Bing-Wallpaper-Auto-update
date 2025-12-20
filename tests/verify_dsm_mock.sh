#!/bin/bash
set -e

echo "=== Starting Verification ==="
echo "Mode: CHECK_ARCHIVE=${CHECK_ARCHIVE:-false}"

HAS_ERRORS=0

# 1. Verify Login Background was created
if [ -f "/usr/syno/etc/login_background.jpg" ]; then
    echo "[PASS] /usr/syno/etc/login_background.jpg exists."
else
    echo "[FAIL] /usr/syno/etc/login_background.jpg missing."
    HAS_ERRORS=1
fi

# 2. Verify Synoinfo Config Updates
# The mock returns "Mock Title" and "Mock Credit"
if grep -q 'login_welcome_title="Mock Title"' /etc/synoinfo.conf; then
    echo "[PASS] synoinfo.conf: login_welcome_title set to Mock Title."
else
    echo "[FAIL] synoinfo.conf: login_welcome_title incorrect."
    grep "login_welcome_title" /etc/synoinfo.conf
    HAS_ERRORS=1
fi

if grep -q 'login_welcome_msg="© Mock Credit"' /etc/synoinfo.conf; then
    echo "[PASS] synoinfo.conf: login_welcome_msg set to Mock Credit."
else
    echo "[FAIL] synoinfo.conf: login_welcome_msg incorrect."
    grep "login_welcome_msg" /etc/synoinfo.conf
    HAS_ERRORS=1
fi

# 3. Verify DSM 7 Resources
if [ -s "/usr/syno/synoman/webman/resources/images/2x/default_wallpaper/dsm7_01.jpg" ]; then
     echo "[PASS] DSM 7 2x wallpaper exists and has content."
else
     echo "[FAIL] DSM 7 2x wallpaper missing or empty."
     HAS_ERRORS=1
fi

# 4. Verify Archive (Conditional)
if [ "$CHECK_ARCHIVE" == "true" ]; then
    # The script uses format: "Region - Date - Title - Copyright.jpg" or similiar
    # Actually logic is: "$SAVE_PATH/${DATE} - ${SAFE_TITLE} - ${SAFE_COPYRIGHT}.jpg"
    # Mock Date: 20230102
    # Mock Title: Mock Title
    # Mock Copyright: © Mock Credit (stripped to " Mock Credit")
    
    EXPECTED_ARCHIVE="/volume1/web/wallpapers/20230102 - Mock Title -  Mock Credit.jpg"
    
    if [ -f "$EXPECTED_ARCHIVE" ]; then
        echo "[PASS] Archive file created: $EXPECTED_ARCHIVE"
    else
        echo "[FAIL] Archive file missing: $EXPECTED_ARCHIVE"
        ls -l /volume1/web/wallpapers/
        HAS_ERRORS=1
    fi
fi

if [ $HAS_ERRORS -eq 0 ]; then
    echo "=== Verification SUCCESS ==="
    exit 0
else
    echo "=== Verification FAILED ==="
    exit 1
fi

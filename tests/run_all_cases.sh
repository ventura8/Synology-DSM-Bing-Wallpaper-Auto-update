#!/bin/bash
set -e

MODE="${1:-all}"

# Helper to reset state between tests
reset_state() {
    echo "--- Resetting Mock State ---"
    rm -rf /usr/syno/etc/login_background*.jpg
    rm -f /tmp/bing_daily_dsm.jpg
    rm -rf /volume1/web/wallpapers/*
    
    # Reset Config
    echo 'login_background_customize=""' > /etc/synoinfo.conf
    echo 'login_welcome_title=""' >> /etc/synoinfo.conf
    echo 'login_welcome_msg=""' >> /etc/synoinfo.conf
}

if [[ "$MODE" == "all" || "$MODE" == "unit" ]]; then
    echo "=== 1. Running Unit Tests (Defaults: 4K, No Archive) ==="
    reset_state
    export BING_RESOLUTION="4k"
    export ENABLE_ARCHIVE="false"
    export CHECK_ARCHIVE="false"
    ./bing_wallpaper_auto_update.sh
    ./verify_dsm_mock.sh
fi

if [[ "$MODE" == "all" || "$MODE" == "component" ]]; then
    echo "=== 2. Running Component Tests (Archive Enabled) ==="
    reset_state
    export BING_RESOLUTION="4k"
    export ENABLE_ARCHIVE="true"
    export CHECK_ARCHIVE="true"
    ./bing_wallpaper_auto_update.sh
    ./verify_dsm_mock.sh
fi

if [[ "$MODE" == "all" || "$MODE" == "e2e" ]]; then
    echo "=== 3. Running E2E Tests (1080p Fallback) ==="
    reset_state
    export BING_RESOLUTION="1080p"
    export ENABLE_ARCHIVE="false"
    export CHECK_ARCHIVE="false"
    ./bing_wallpaper_auto_update.sh
    ./verify_dsm_mock.sh
fi

echo "=== Selected Tests ($MODE) Completed Successfully ==="

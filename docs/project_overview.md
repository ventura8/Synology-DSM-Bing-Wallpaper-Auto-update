# Project Overview & Logic

This project provides an automated solution for updating the Synology DSM 7.2 login screen wallpaper with the Bing Daily Image.

**Current release:** [v1.0.3](releases/v1.0.3.md)

## Core Logic

The script `bing_wallpaper_auto_update.sh` follows these steps:

1.  **Market Selection**: Detects or uses configured Bing market (default: `en-WW`).
2.  **API Call**: Fetches daily image metadata from `https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=$MARKET` with TLS verification enabled.
3.  **Metadata Extraction**:
    *   Extracts image URL (4K or 1080p).
    *   Extracts image description (Title) and copyright information.
    *   Sanitizes title/copyright for safe `synoinfo.conf` writes.
4.  **Download**: Downloads the image to a temporary location (TLS verified).
5.  **Content Validation**: Confirms the download is a JPEG (SOI magic bytes) before any system writes.
6.  **Apply to System**:
    *   Updates `/etc/synoinfo.conf` for the login welcome title and message.
    *   Overwrites the default DSM wallpaper at `/usr/syno/synoman/webman/resources/images/2x/default_wallpaper/dsm7_01.jpg`.
    *   Updates `/usr/syno/etc/login_background.jpg`.
7.  **Archiving (Optional)**: If enabled, validates Bing `enddate` as `YYYYMMDD`, then saves under `SAVE_PATH` only (path containment when `realpath` is available).

## Testing Strategy

- **Mocking**: Since we cannot run on a real Synology DSM during CI, we use a Docker-managed mock environment (`tests/Dockerfile.dsm_mock`).
- **kcov**: Used for gathering code coverage from Shell scripts.
- **Verification**: `tests/verify_dsm_mock.sh` checks if the system files and configurations were correctly updated by the script.
- **Failure cases**: Mock modes cover invalid API JSON, empty downloads, non-JPEG payloads, and traversal dates in archive mode.

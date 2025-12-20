# Project Overview & Logic

This project provides an automated solution for updating the Synology DSM 7.2 login screen wallpaper with the Bing Daily Image.

## Core Logic

The script `bing_wallpaper_auto_update.sh` follows these steps:

1.  **Market Selection**: Detects or uses configured Bing market (default: `en-WW`).
2.  **API Call**: Fetches daily image metadata from `https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=$MARKET`.
3.  **Metadata Extraction**:
    *   Extracts image URL (4K or 1080p).
    *   Extracts image description (Title) and copyright information.
4.  **Download**: Downloads the image to a temporary location.
5.  **Apply to System**:
    *   Updates `/etc/synoinfo.conf` for the login welcome title and message.
    *   Overwrites the default DSM wallpaper at `/usr/syno/synoman/webman/resources/images/2x/default_wallpaper/dsm7_01.jpg`.
    *   Updates `/usr/syno/etc/login_background.jpg`.
6.  **Archiving (Optional)**: If enabled, saves the image with descriptive metadata in the filename to a specified archive directory.

## Testing Strategy

- **Mocking**: Since we cannot run on a real Synology DSM during CI, we use a Docker-managed mock environment (`tests/Dockerfile.dsm_mock`).
- **kcov**: Used for gathering code coverage from Shell scripts.
- **Verification**: `tests/verify_dsm_mock.sh` checks if the system files and configurations were correctly updated by the script.

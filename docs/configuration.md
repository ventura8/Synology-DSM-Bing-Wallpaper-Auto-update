# Configuration

You can configure the wallpaper script by modifying the variables at the top of the `bing_wallpaper_auto_update.sh` file or by passing environment variables.

## Primary Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `BING_RESOLUTION` | `4k` | Image resolution. Use `4k` (3840x2160) or `1080p` (1920x1080). |
| `BING_MARKET` | `en-WW` | The Bing region/market to fetch from (e.g., `en-US`, `ja-JP`). |
| `ENABLE_ARCHIVE` | `false` | If `true`, saves a copy of the daily image to `SAVE_PATH`. |
| `SAVE_PATH` | `/volume1/web/wallpapers` | Directory for archiving images. Must be non-empty when archiving; files stay under this path. |

## Advanced Settings

- `TMP_FILE`: `/tmp/bing_daily_dsm.jpg`. Temporary storage during processing.

## Safety Notes

- HTTPS downloads keep TLS certificate verification enabled.
- Downloaded content must look like a JPEG before system wallpaper paths are updated.
- Archive filenames use a validated eight-digit Bing date (`YYYYMMDD`).
- The archive destination must not be a symlink or other non-regular file; the script fails closed
  instead of writing through it. The file is staged in a private directory at `SAVE_PATH`'s volume
  root (`/volumeN` on DSM — outside any shared folder, so share permissions and ACL inheritance
  cannot reach it) and hard-linked into place; `link(2)` never follows a symlink at the destination.
  The mount point must be a volume root (`/volumeN`) that is root-owned and not group/other-writable,
  or archiving fails with an error. **Encrypted shared folders and USB/eSATA shares are their own
  mounts and are therefore not supported for `SAVE_PATH`** — SynoACL grants share writers access to
  such a mount regardless of its POSIX mode, so it cannot be used as a private staging area. As the
  script runs as root and `SAVE_PATH` is often a shared folder, prefer a `SAVE_PATH` that only
  administrators can write to.
- Title/copyright values are sanitized before writing `/etc/synoinfo.conf`.

## Supported Region Codes

| Code | Region | Code | Region |
| :--- | :--- | :--- | :--- |
| `en-WW` | Worldwide | `en-IN` | India |
| `en-US` | USA | `it-IT` | Italy |
| `en-AU` | Australia | `ja-JP` | Japan |
| `pt-BR` | Brazil | `en-NZ` | New Zealand |
| `en-CA` | Canada | `es-ES` | Spain |
| `zh-CN` | China | `en-GB` | England (UK) |
| `fr-FR` | France | `en-SG` | Singapore |
| `de-DE` | Germany | | |

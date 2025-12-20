# Configuration

You can configure the wallpaper script by modifying the variables at the top of the `bing_wallpaper_auto_update.sh` file or by passing environment variables.

## Primary Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `BING_RESOLUTION` | `4k` | Image resolution. Use `4k` (3840x2160) or `1080p` (1920x1080). |
| `BING_MARKET` | `en-WW` | The Bing region/market to fetch from (e.g., `en-US`, `ja-JP`). |
| `ENABLE_ARCHIVE` | `false` | If `true`, saves a copy of the daily image to `SAVE_PATH`. |
| `SAVE_PATH` | `/volume1/web/wallpapers` | Directory for archiving images. |

## Advanced Settings

- `TMP_FILE`: `/tmp/bing_daily_dsm.jpg`. Temporary storage during processing.

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

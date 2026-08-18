# USAGE GUIDE: Headless Dive Automation (v3.1.0)

This guide provides detailed instructions on how to use the automation suite to generate professional diving movies and highlights directly from your terminal.

## 1. Initial Configuration

Before running any scripts, you must set up your local environment.

1.  **Copy the template:**
    ```bash
    cp .env.example .env
    ```
2.  **Edit `.env`:**
    - `SEARCH_DIR`: Path to your camera's DCIM folder (where `.MP4` files live).
    - `LOGS_DIR`: Path to your dive logs folder (where `.CSV` files live).

## 2. Paved Road (Direct GitHub Execution)

Thanks to `uv` and PEP 723, you can execute the core engine directly from GitHub without cloning the repository or setting up `.env` files. `uv` will dynamically download the script, create an ephemeral environment, and install `pandas` in milliseconds.

```bash
uv run https://raw.githubusercontent.com/akimchik/paralenz-rendering/main/scripts/build_headless_movie.py \
  --date 2026-06-27 \
  --logs_dir /path/to/logs \
  --media_dir /path/to/media \
  --output my_dive.mp4
```

## 3. Running the Automation Locally (via uv)

If you have cloned the repository, execute the engine directly using `uv run`. This handles the `pandas` dependency automatically and provides full access to the CLI flags.

### Basic Usage (Full Day Render)
Builds a chronological movie of all the day's dives with a dynamic HUD.
```bash
uv run --with pandas scripts/build_headless_movie.py \
  --date 2026-06-27 \
  --logs_dir ./data/logs \
  --media_dir ./data/media \
  --output my_dive.mp4
```

### Advanced Execution Examples

**1. Generate 5-Chapter Smart Highlights for Dive 1:**
```bash
uv run --with pandas scripts/build_headless_movie.py \
  --date 2026-06-27 --logs_dir ./data/logs --media_dir ./data/media --output highlights.mp4 \
  --mode highlights --dive_list 1
```

**2. Add a custom 2-hour offset if the camera RTC drifted:**
```bash
uv run --with pandas scripts/build_headless_movie.py \
  --date 2026-06-27 --logs_dir ./data/logs --media_dir ./data/media --output offset_dive.mp4 \
  --offset 7200
```

**3. Disable dynamic color correction (if using physical red filters):**
```bash
uv run --with pandas scripts/build_headless_movie.py \
  --date 2026-06-27 --logs_dir ./data/logs --media_dir ./data/media --output raw_color.mp4 \
  --water none
```

### CLI Arguments Reference
- `--date`: (Required) Target ISO8601 date (e.g. `2026-06-27`).
- `--logs_dir`: (Required) Path to directory containing `.CSV` logs.
- `--media_dir`: (Required) Path to directory containing `.MP4` files.
- `--output`: (Required) Output path for the rendered MP4 file.
- `--mode`: `full` (renders entire dive sessions) or `highlights` (5-chapter smart slices). Default is `full`.
- `--offset`: Forces a manual time sync offset in seconds between telemetry and video creation time.
- `--dive_list`: Comma-separated list of Dive IDs to render (e.g. `1,3,4`). If omitted, renders all dives.
- `--water`: **EXPERIMENTAL.** `saltwater` (default) enables dynamic red boost. `none` disables color correction.
- `--gap`: Gap threshold in seconds to detect new dives. Default is `7200`.

## 3. Key Advanced Features

### Global Multi-Dive Support
The system automatically detects multiple dives in your logs using a configurable gap (default: 5 minutes/300 seconds). It correlates each video clip to the correct dive using its recording timestamp.
- **Auto-Sync:** If you have 3 dives in one day, the script will generate 3 separate HUD profiles and sync the correct data to the correct footage automatically.
- **Session Detection:** It identifies gaps in activity to separate "Dives" from "Surface intervals."

### Dynamic HUD
A real-time depth and temperature HUD is injected into the video using dynamic SubRip (`.srt`) subtitle generation. The script relies on native camera hardware RTC synchronization (zero-offset) by default, ensuring perfect alignment between the `.MP4` files and `.CSV` telemetry logs. A manual offset can be supplied if drift occurs.

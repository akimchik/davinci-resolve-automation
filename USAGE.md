# USAGE GUIDE: Headless Dive Automation (v3.0.0)

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

## 3. Running the Automation via Local Wrapper

If you have cloned the repository, the simplest way to use the engine is through the included `./render` wrapper script, which reads from your `.env` file.

### Basic Usage (Full Day Render)
Builds a chronological movie of all the day's dives with a dynamic HUD.
```bash
./render -d YYYY-MM-DD
# Example: ./render -d 2026-06-27
```

### Option A: Standard Full Movie for a Specific Dive
To target a single dive (e.g., Dive 1):
```bash
./render -d 2026-06-27 -l 1 -m full
```

### Option B: Condensed Highlight Reel
Creates a punchy reel by extracting 3-second action slices from every clip instead of joining them fully.
```bash
# Add a custom 2-hour offset if the camera RTC drifted
./render -d 2026-06-27 -m full --offset 7200

# Disable dynamic color correction (if using physical red filters)
./render -d 2026-06-27 -m highlights --water none
```

### CLI Arguments Reference
- `-d, --date`: (Required) Target ISO8601 date (e.g. `2026-06-27`).
- `-m, --mode`: `full` (renders entire dive sessions) or `highlights` (5-chapter smart slices).
- `--offset`: Forces a manual time sync offset in seconds between telemetry and video creation time.
- `--dive_list`: Comma-separated list of Dive IDs to render (e.g. `1,3,4`). If omitted, renders all dives.
- `--water`: **EXPERIMENTAL.** `saltwater` (default) enables dynamic red boost. `none` disables color correction.
- `-g, --gap` (Optional): Gap threshold in seconds to detect new dives. Default is `300`.
- `-o, --output` (Optional): Custom output path for the rendered MP4 file. Default is `$HOME/Movies/dive_<date>.mp4`.

## 3. Key Advanced Features

### Global Multi-Dive Support
The system automatically detects multiple dives in your logs using a configurable gap (default: 5 minutes/300 seconds). It correlates each video clip to the correct dive using its recording timestamp.
- **Auto-Sync:** If you have 3 dives in one day, the script will generate 3 separate HUD profiles and sync the correct data to the correct footage automatically.
- **Session Detection:** It identifies gaps in activity to separate "Dives" from "Surface intervals."

### Dynamic HUD
A real-time depth and temperature HUD is injected into the video using dynamic SubRip (`.srt`) subtitle generation. The script relies on native camera hardware RTC synchronization (zero-offset) by default, ensuring perfect alignment between the `.MP4` files and `.CSV` telemetry logs. A manual offset can be supplied if drift occurs.

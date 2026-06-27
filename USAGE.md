# USAGE GUIDE: Headless Dive Automation (v2.0.0)

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

## 2. Running the Automation via Wrapper

The simplest way to use the engine is through the included `./render` wrapper script.

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
./render -d 2026-06-27 -m highlights
```

### Command-Line Arguments Reference

- `-d, --date` (Required): The date to render, in `YYYY-MM-DD` format.
- `-m, --mode` (Optional): `full` or `highlights`. Default is `full`.
- `-l, --dive_list` (Optional): A dive ID (e.g. `1` or `2`) or comma-separated list of dives to process. If omitted, all dives for the day are processed.
- `-g, --gap` (Optional): Gap threshold in seconds to detect new dives. Default is `300`.
- `-o, --output` (Optional): Custom output path for the rendered MP4 file. Default is `$HOME/Movies/dive_<date>.mp4`.

## 3. Key Advanced Features

### Global Multi-Dive Support
The system automatically detects multiple dives in your logs using a configurable gap (default: 5 minutes/300 seconds). It correlates each video clip to the correct dive using its recording timestamp.
- **Auto-Sync:** If you have 3 dives in one day, the script will generate 3 separate HUD profiles and sync the correct data to the correct footage automatically.
- **Session Detection:** It identifies gaps in activity to separate "Dives" from "Surface intervals."

### Dynamic HUD
A transparent depth profile is injected into the video, tracking your real-time depth and temperature based on your dive computer's CSV telemetry. The system automatically calculates the time offset between your camera and the dive computer.

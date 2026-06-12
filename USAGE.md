# USAGE GUIDE: DaVinci Resolve Automation

This guide provides detailed instructions on how to use the automation suite to generate professional diving movies and highlights.

## 1. Initial Configuration

Before running any scripts, you must set up your local environment.

1.  **Copy the template:**
    ```bash
    cp config.lua.example config.lua
    ```
2.  **Edit `config.lua`:**
    - `search_dir`: Path to your camera's DCIM folder (where `.MP4` files live).
    - `logs_dir`: Path to your dive logs folder (where `.CSV` files live).
    - `python_path`: Path to your `.venv/bin/python3`.
    - `underwater_lut`: (Optional) Path to a `.cube` LUT for automatic color correction.

## 2. Running the Automation

The scripts are designed to be run from the **DaVinci Resolve Console** (Workspace -> Console -> Lua tab).

### Option A: Standard Full Movie
Builds a chronological movie of the day's dives with a dynamic HUD and intro card.
```lua
dofile("path/to/create_movie.lua")
```

### Option B: Condensed Highlight Reel
Creates a punchy 5-7 minute reel by taking action slices from every clip.
```lua
dofile("path/to/create_highlights.lua")
```

### Option C: Previewing Dive Sessions
If you have multiple dives in a single day and want to know their exact times and depths before rendering, run the preview utility:
```lua
dofile("path/to/list_dives.lua")
-- Output example:
-- Dive #1: 10:00:00 - 10:45:00 | Max Depth: 25.2m | Duration: 45 min
-- Dive #2: 12:30:00 - 13:15:00 | Max Depth: 18.0m | Duration: 45 min
```

### Option D: Advanced CLI Overrides
You can override your `config.lua` settings directly in the console without editing the file. This is also how you **target a specific dive**:
```lua
-- Override paths and target date, and only process Dive #2
arg = { "--logs_dir", "/Volumes/Backup/LOGS", "--date", "2026-06-05", "--dive_id", "2" }
dofile("path/to/create_movie.lua")
```

## 3. Key Advanced Features

### Global Multi-Dive Support
The system automatically detects multiple dives in your logs. It correlates each video clip to the correct dive using its recording timestamp.
- **Auto-Sync:** If you have 3 dives in one day, the script will generate 3 separate HUD profiles and sync the correct data to the correct footage automatically.
- **Session Detection:** It identifies gaps in activity to separate "Dives" from "Surface intervals."

### Visual Polishing
- **Ken Burns Effect:** Introductory photos automatically receive a professional slow-zoom motion.
- **Dynamic HUD:** A transparent depth profile is injected into every clip, featuring a "red dot" that tracks your real-time position on the graph.
- **Auto-LUT:** If `underwater_lut` is configured, every clip receives a primary color grade automatically upon import.

## 5. Headless Mode (No DaVinci Resolve Required)

If DaVinci Resolve is unavailable or unstable, you can use the standalone FFmpeg engine to generate your movie. This is faster and runs entirely in the terminal.

### Run Automated Highlights
This will automatically find "Action Moments" (Max Depth, Fast Descents) and create a highlight reel.
```bash
python3 scripts/auto_render.py --date "2026-06-06"
```

### Advanced Headless CLI
You can control the process manually via the main engine:
```bash
python3 scripts/build_headless_movie.py \
  --date "2026-06-06" \
  --logs_dir "/path/to/logs" \
  --media_dir "/path/to/media" \
  --mode [highlights|full] \
  --output "dive_video.mp4"
```
*Note: Requires FFmpeg installed on your Mac (`brew install ffmpeg`).*

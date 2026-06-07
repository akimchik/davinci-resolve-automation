# DaVinci Resolve Automation Scripts

Automate the creation of 4K 60fps diving movies and highlight reels directly from your camera's DCIM folder, integrated with real-time telemetry data.

## Features

- **Movie Assembly:** Chronologically joins high-res MP4s and uses the first JPG of the day as a title background.
- **AI-Free Highlights:** Creates a punchy highlight reel by taking three 3-second "action slices" (Start, Mid, End) from every clip.
- **Dynamic HUD:** Programmatically generates a 4K depth profile graph and overlays real-time depth/temperature telemetry using Fusion keyframes.
- **Strict Filtering:** Implements precise single-day filtering (using `-newermt`) to ensure only the target date's media is processed.
- **Integrated Cleanup:** Automatically wipes previous temporary projects at the start of every run.
- **Professional Overlays:** Uses Track Locking to render "Diving Session" text directly on top of your dive photos.
- **60fps Stability:** Implements a double-pass initialization to force and lock the 60fps frame rate in the Free version.
- **License-Safe:** Configured with "Native" CPU encoding to bypass "Hardware Acceleration" limitations.

## Prerequisites

### 1. Python Environment
This project uses a hybrid Python/Lua architecture for data visualization.
```bash
# Set up the virtual environment
python3 -m venv .venv
source .venv/bin/activate
pip install matplotlib pandas
```

### 2. DaVinci Resolve
- Ensure Resolve is open.
- Go to `Workspace -> Console` and switch to the **Lua** tab.

## Project Structure

- `create_movie.lua`: Main script to build the full history movie with HUD.
- `create_highlights.lua`: Script to build the condensed action reel with HUD.
- `telemetry_parser.lua`: Module for advanced CSV log analysis.
- `scripts/generate_telemetry.py`: Python engine for graph and keyframe generation.
- `config.lua.example`: Template for your local environment configuration.

## Setup & Usage

### 1. Configuration
Copy `config.lua.example` to `config.lua` and edit it:
- Update `search_dir` and `logs_dir` to point to your camera storage.
- The `date_filter` automatically defaults to today.

### 2. Running in DaVinci Resolve

**Option A: Default to Today**
```lua
dofile("path/to/davinci-resolve-automation/create_movie.lua")
```

**Option B: Specific Date Override**
```lua
DIVE_DATE = "2026-06-07"; dofile("path/to/davinci-resolve-automation/create_movie.lua")
```

## Professional Standards
- **Zero-Warning Policy:** All Lua code is verified against `luacheck`.
- **Testing:** Standalone tests for the parser and generator are located in `tests/`.
- **Privacy:** Local paths and binary assets are strictly excluded via `.gitignore`.

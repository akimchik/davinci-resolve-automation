# DaVinci Resolve Automation Scripts

Automate the creation of 4K 60fps diving movies and highlight reels directly from your camera's DCIM folder, integrated with real-time telemetry data.

## Features

- **Universal Multi-Dive Support:** Automatically detects multiple dive sessions per day and correlates video clips using recording timestamps.
- **Movie Assembly:** Chronologically joins high-res MP4s and uses the first JPG of the day as a title background.
- **AI-Free Highlights:** Creates a punchy highlight reel by taking three 3-second "action slices" (Start, Mid, End) from every clip.
- **Dynamic HUD:** Programmatically generates 4K depth profile graphs and overlays real-time depth/temperature telemetry using Fusion keyframes.
- **Ken Burns Effect:** Introductory photos automatically receive professional slow-zoom motion for a cinematic feel.
- **Auto-LUT Integration:** Applies standard "Underwater Recovery" color grades to all clips automatically.
- **Strict Filtering:** Implements precise single-day filtering (using `-newermt`) to ensure only the target date's media is processed.
- **Integrated Cleanup:** Automatically wipes previous temporary projects at the start of every run.
- **Professional Overlays:** Renders location (GPS), max depth, and temperature data directly on title cards.
- **60fps Stability:** Implements a double-pass initialization to force and lock the 60fps frame rate in the Free version.
- **License-Safe:** Configured with "Native" CPU encoding to bypass "Hardware Acceleration" limitations.
- **Autonomous Verification:** Includes a headless mock-API testing framework for CI/CD integration.

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
- `scripts/generate_telemetry.py`: Python engine for multi-session graph and metadata generation.
- `config.lua.example`: Template for your local environment configuration.

## Setup & Usage

For detailed instructions on configuration, CLI overrides, and running the scripts, please see the [**USAGE.md**](./USAGE.md) file.

## Professional Standards
- **Zero-Warning Policy:** All Lua code is verified against `luacheck`.
- **Testing:** Comprehensive unit and integration tests are located in `tests/`.
- **Privacy:** Local paths and binary assets are strictly excluded via `.gitignore`.

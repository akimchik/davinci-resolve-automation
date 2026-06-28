# Headless Dive Automation (v2.0.0)

Automate the creation of 4K 60fps diving movies and highlight reels directly from your camera's DCIM folder, integrated with real-time telemetry data.

*As of v2.0.0, this project has fully migrated to a headless FFmpeg-based architecture for maximum stability and speed, deprecating the legacy DaVinci Resolve integration.*

## Features

- **Universal Multi-Dive Support:** Automatically detects multiple dive sessions per day and correlates video clips using recording timestamps.
- **Headless Pipeline:** Renders directly from the terminal without needing any heavy UI software.
- **Movie Assembly:** Chronologically joins high-res MP4s and builds a seamless video.
- **AI-Free Highlights:** Creates a punchy highlight reel by taking three 3-second "action slices" (Start, Mid, End) from every clip.
- **Dynamic HUD:** Programmatically generates 4K depth profile graphs and overlays real-time depth/temperature telemetry using FFmpeg filtering.
- **Strict Filtering:** Implements precise single-day filtering to ensure only the target date's media is processed.
- **60fps Stability:** Generates standard 60fps files without dropped frames.
- **Autonomous Verification:** Includes a testing framework for CI/CD integration.

## Prerequisites

### 1. Python Environment
This project uses Python to calculate offsets, parse telemetry, and orchestrate FFmpeg.
```bash
# Set up the virtual environment
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt # (If present)
pip install matplotlib pandas
```

### 2. FFmpeg
Ensure `ffmpeg` and `ffprobe` are installed on your system.
```bash
brew install ffmpeg
```

## Setup & Usage

For detailed instructions on configuration, CLI overrides, and running the scripts using the `./render` wrapper, please see the [**USAGE.md**](./USAGE.md) file.

## Professional Standards
- **Testing:** Comprehensive unit and integration tests are located in `tests/`.
- **Privacy:** Local paths and binary assets are strictly excluded via `.gitignore`.

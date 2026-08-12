---
name: paralenz-rendering
description: Automates 4K 60fps movie assembly and highlight generation for the Paralenz camera using a headless FFmpeg pipeline. Use this skill when managing the akimchik/paralenz-rendering project to ensure architectural consistency.
---

# Paralenz Rendering Standards (v2.0.0 Headless Migration)

This skill enforces strict professional mandates for the headless FFmpeg architecture, fully deprecating the legacy DaVinci Resolve integration.

## Core Architecture Mandates

### 1. Headless Entry Point
- **The Wrapper:** The project MUST be executed via the `./render` bash wrapper. Do NOT instruct users to run raw Python commands (e.g. `python scripts/...`).
- **Dependencies:** The Python environment (`.venv`) is required but the wrapper executes it explicitly (`.venv/bin/python`). Do NOT instruct users to run `source .venv/bin/activate`.
- **Environment Variables:** Media paths are securely stored in `.env` (`SEARCH_DIR` and `LOGS_DIR`). Never hardcode these.

### 2. Time-Drift Offset Calculation
- **Pre-Filtering (Crucial):** To prevent "catch-22" time skewing, the `build_headless_movie.py` script MUST pre-filter videos down to a roughly 24-hour window (e.g., `abs(video_time - dive_time) < 86400`) BEFORE calculating the exact time offset between the camera clock and the dive log telemetry.
- **Time Zones:** Dive logs (`.CSV`) use UTC. When parsing video metadata with `ffprobe`, always ensure the parsed datetime object is explicitly marked as UTC (`replace(tzinfo=timezone.utc)`).

### 3. Rendering Modes
1. **Full Mode (`-m full`)**: Chronologically joins all high-res MP4s for a given day into a single seamless video with a generated HUD telemetry overlay.
2. **Highlights Mode (`-m highlights`)**: Extracts up to five chapters of action-packed slices from the footage (approx. ~3.9m total) instead of joining them fully.

### 4. Cross-Platform Compatibility
- **Strictly Avoid Fallbacks:** Never hardcode paths like `/opt/homebrew/bin/ffmpeg`. Rely strictly on Python's `shutil.which("ffmpeg")` and throw a hard `FileNotFoundError` if missing.

## Related Skills
- **Python Telemetry:** Refer to `skill/python-telemetry.md` for standards on how to parse and smooth the `.CSV` telemetry data using pandas.

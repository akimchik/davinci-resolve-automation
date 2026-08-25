---
name: python-telemetry-processing
description: Best practices for processing telemetry data (GPS, Depth, Temp) using Python for video overlays.
---

# Python Telemetry Standards

## 1. Data Processing (Pandas)
- **Strict Dependencies:** The project uses PEP 723 inline script metadata for dependency management via `uv`. Do NOT introduce `requirements.txt`, `pip`, `venv`, or any manual dependency installation. All dependencies must be declared inside each script's `# /// script` block.
- **Time Synchronization:** Always align telemetry to a relative start time (0s). Handle camera offsets (e.g., UTC+1) explicitly in configuration.
- **Resampling:** Resample data to match the video frame rate (e.g., `df.resample('16.67ms').mean()` for 60fps) to prevent "stuttering" overlays.
- **Smoothing:** Use rolling averages (`rolling(window=X).mean()`) for jittery sensors like GPS or high-frequency depth sensors.
- **Session Detection:** Use gaps in timestamps (e.g., > 30 mins) to automatically segment "Dives" from "Surface time".

## 2. Visualization (FFmpeg Headless)
- **Hardware Acceleration:** Use `h264_videotoolbox` on macOS for performant rendering.
- **Dynamic Range:** Normalize timestamps to actual video duration.
- **Filter Syntax:** Always escape reserved characters (`:`, `|`) in FFmpeg `drawtext` filters.

## 3. Metadata Extraction
- **Resolution Filtering:** Use `ffprobe` to inspect internal stream metadata (width/height) to robustly exclude low-res proxies, ignoring filenames.

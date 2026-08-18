---
name: python-telemetry-processing
description: Best practices for processing telemetry data (GPS, Depth, Temp) using Python for video overlays.
---

# Python Telemetry Standards

## 1. Data Processing (Pandas)
- **Strict Dependencies:** Strictly rely on the existing `requirements.txt`. Do NOT install or introduce new third-party Python libraries without explicit user permission.
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

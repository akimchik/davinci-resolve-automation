---
name: paralenz-rendering
description: Automates 4K 60fps movie assembly and highlight generation for the Paralenz camera using a headless FFmpeg pipeline. Use this skill when managing the akimchik/paralenz-rendering project to ensure architectural consistency.
---

# Paralenz Rendering Standards (v2.2.0 Dynamic Telemetry Engine)

This skill enforces strict professional mandates for the headless FFmpeg architecture, fully deprecating the legacy DaVinci Resolve integration.

## Core Architecture Mandates

### 0. Agent Execution Protocol (The Ball of Thread)
- **AGENT PROTOCOL:** Before taking any action (creating a branch, writing code, bumping a version), the AI MUST explicitly read this file and related `skill/` documents, map its proposed changes to the rules, and seek approval via an Implementation Plan.
- **Architecture Modifications Only:** Modifying actual existing codebase files is vastly preferred over writing brand-new one-off scripts. Do NOT do snap decisions like custom test scripts, temporary bash hacks, or fast solutions that break project logic or are obvious workarounds. Stick to the project architecture.

### 1. Headless Entry Point
- **The Wrapper:** The project MUST be executed via the `./render` bash wrapper. Do NOT instruct users to run raw Python commands (e.g. `python scripts/...`).
- **Dependencies:** The Python environment (`.venv`) is required but the wrapper executes it explicitly (`.venv/bin/python`). Do NOT instruct users to run `source .venv/bin/activate`.
- **Environment Variables:** Media paths are securely stored in `.env` (`SEARCH_DIR` and `LOGS_DIR`). Never hardcode these.

### 2. Time-Drift Offset Calculation
- **Camera RTC Synchronization:** Videos and telemetry logs are natively synchronized via the camera's internal Real-Time Clock (RTC). The script MUST default to a zero-offset rather than attempting to auto-calculate drift.
- **Time Zones:** Dive logs (`.CSV`) use UTC. When parsing video metadata with `ffprobe`, always ensure the parsed datetime object is explicitly marked as UTC (`replace(tzinfo=timezone.utc)`).

### 3. Rendering Modes
1. **Full Mode (`-m full`)**: Chronologically joins all high-res MP4s for a given day into a single seamless video with a generated HUD telemetry overlay.
2. **Highlights Mode (`-m highlights`)**: Extracts up to five chapters of action-packed slices from the footage (approx. ~3.9m total) instead of joining them fully.

### 4. Cross-Platform Compatibility
- **Strictly Avoid Fallbacks:** Never hardcode paths like `/opt/homebrew/bin/ffmpeg`. Rely strictly on Python's `shutil.which("ffmpeg")` and throw a hard `FileNotFoundError` if missing.

## Related Skills
- **Python Telemetry:** Refer to `skill/python-telemetry.md` for standards on how to parse and smooth the `.CSV` telemetry data using pandas.

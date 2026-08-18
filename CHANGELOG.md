# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **UV Paved Road Execution**: Migrated the execution pipeline to `uv`, replacing the legacy `pip`/`venv` flow. Implemented PEP 723 inline script metadata in `build_headless_movie.py`, enabling zero-config execution directly from GitHub without cloning.
- **Dynamic Color Correction**: Added an automatic FFmpeg `colorbalance` filter that dynamically restores absorbed red light proportionally to the current dive depth (scaling up to 40% boost at 30 meters), eliminating the need for static `.cube` LUTs.

## [v3.0.0] - 2026-08-18

### Added
- **Dynamic Telemetry Engine**: Replaced static overlay text with a dynamic SubRip (`.srt`) subtitle generator. Overlays now update second-by-second, syncing precise unrounded depth, temperature, and exact `ISO8601` timestamps directly from the CSV logs.
- **Telemetry Polish**: Date and Time are stripped from the subtitle for a cleaner look. Font size has been adjusted.

### Fixed
- **Time Synchronization Bug**: Removed automatic offset logic. The script now relies on native camera hardware RTC synchronization (zero-offset) by default, fixing the 3-minute drift between video and telemetry data.

## [v2.1.0] - 2026-08-12

### Added
- **Dynamic Color Correction (Experimental)**: Added an automatic FFmpeg `colorbalance` filter that dynamically restores absorbed red light proportionally to the current dive depth (up to 40% at 30 meters). Note: Can amplify noise in deep shadows. Added `--water` argument (`saltwater`, `none`) to toggle the feature.
- **Auto-Bootstrap**: Added logic to `./render` to automatically build the Python virtual environment and install dependencies if they are missing.
- **Portable Status Script**: Replaced hardcoded status checks with a universal `check-status.py` script that uses a portable shebang (`#!/usr/bin/env python3`).
- **Autonomous Architecture Rules**: Enforced strict rules inside `skill/github-release-management.md` for branching algorithms and release management.

### Fixed
- **Highlights Output Bug**: Ensured that the `-m highlights` command appends a `_highlights` suffix to the output filename to prevent overwriting the full movie render.
- **Temporary Files**: Added a safe, automated cleanup step using `shutil.rmtree` to remove `temp_slices_*` directories upon successful rendering.

## [v2.0.0] - 2026-06-27

### Added
- **Headless Migration**: Completely transitioned the project from the legacy DaVinci Resolve UI workflow to a fully headless FFmpeg-based pipeline.
- **Smart Highlights**: Upgraded the highlight extraction engine to support a 5-chapter chronological extraction for punchier reels.

### Changed
- **Entry Point**: Standardized all execution through the `./render` bash wrapper.

### Removed
- **DaVinci Resolve Dependencies**: Purged all legacy Lua API documentation and scripts associated with the UI-based pipeline.

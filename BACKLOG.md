# Project Backlog & Feature Roadmap

This file tracks planned features and professional improvements for the Headless FFmpeg Automation suite.

## Phase 3: Visual Polishing & Core Upgrades (In Progress)
- [ ] **UV Migration:** Migrate the entire Python environment and dependency management to `uv` (Astral's fast Python package installer) for lightning-fast bootstrapping and deterministic lockfiles.
- [ ] **Automatic Color Correction:** Apply a standard "Underwater Recovery" LUT or `.cube` grade to all MP4s dynamically during the FFmpeg render process (using `lut3d`).
- [ ] **Smooth Transitions:** Automate cross-dissolves (crossfades) between raw 4K clips using the FFmpeg `xfade` filter instead of hard cuts.

## Phase 4: Workflow Improvements
- [ ] **Multi-Day Processing:** Upgrade the `./render` wrapper to accept a range of dates (or automatically process all available media dates) in a single run.
- [ ] **Concurrent Rendering:** Explore using Python's `multiprocessing` to generate highlight slices in parallel before the final FFmpeg concatenation.

---
*Last updated: August 18, 2026*

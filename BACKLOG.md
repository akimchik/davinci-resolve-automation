# Project Backlog & Feature Roadmap

This file tracks planned features and professional improvements for the DaVinci Resolve Automation suite.

## Phase 2: Telemetry Integration (In Progress)
- [ ] **Log Parser Module:** Develop a robust parser for `LOGXX.csv` files to extract time-series data.
- [ ] **Data Correlation:** Match video timestamps with telemetry data points (GPS, Depth, Temp).
- [ ] **Telemetry Title Card:** Generate an image/Text+ card with "Max Depth", "Min Temp", and "Dive Duration".
- [ ] **Dynamic Overlays:** Implement live depth/temperature readouts that update during video playback.
- [ ] **GPS Visualization:** Create a map overlay showing the dive location (if surface coordinates are available).

## Phase 3: Visual Polishing
- [ ] **Ken Burns Effect for JPGs:** Programmatically add motion to photos to keep them dynamic.
- [ ] **Smooth Transitions:** Automate cross-dissolves between clips.
- [ ] **Automatic Color Correction:** Apply a standard "Underwater Recovery" LUT or grade to all MP4s.

## Phase 4: Workflow Improvements
- [ ] **Interactive Folder Picker:** Use Resolve's UI to pick the source folder instead of `config.lua`.
- [ ] **Multi-Day Processing:** Allow processing a range of dates in one run.
- [ ] **Plugin/FDK Integration:** Explore using DaVinci Resolve plugins for better telemetry rendering.

---
*Last updated: June 07, 2026*

---
name: davinci-resolve-automation
description: Automates 4K 60fps movie assembly and highlight generation in DaVinci Resolve. Use this skill when managing the akimchik/davinci-resolve-automation project to ensure professional standards and license compatibility.
---

# DaVinci Resolve Automation Standards (Post-Mortem v1.1)

This skill enforces strict professional mandates derived from real-world failures during development.

## Core Mandates

### 1. Visual & License Standards (4K 60fps)
- **Resolution:** Strictly use Ultra HD (3840 x 2160). No hardcoding; pull from `Config.resolution_width/height`.
- **Frame Rate:** Strictly use **60.00 fps** (or as defined in `Config.frame_rate`).
- **Native Encoding:** Always use `Encoder = "Native"` (CPU) to bypass license pop-ups for 4K 60fps in the Free version.
- **Proxies:** Explicitly disable proxies (`perfProxyMediaMode = 0`) to prevent pixelation/quality loss.

### 2. Professional Editing Workflows (Verified)
- **Edit Page Mandate:** Always use `res:OpenPage("edit")` before playhead manipulation.
- **Overlays:** Follow the verified sequence: 1. Add background. 2. `SetCurrentTimecode(0)`. 3. Insert Title (Text+).
- **Track Locking:** Do NOT use `SetTrackLock` during title insertion as it can block the API from placing text.
- **Trimming:** Strictly use `SetMarkInOut(start, end)` for highlights. `SetClipProperty` is for metadata, NOT trimming.

### 3. Project Integrity & Privacy
- **Config as Truth:** Pull ALL environment settings from `config.lua`. Placeholders only in tracked files.
- **Global Scoping:** Core Resolve objects (`res`, `project`, `mediapool`, `timeline`) MUST be global (no `local`) to ensure visibility during `dofile` execution.
- **Zero-Warning Policy:** Run `luacheck` locally before every commit. Target = 0 warnings.
- **Privacy:** NEVER hardcode USER_HOME_DIRECTORY or specific volume names. Use dynamic resolution via `debug.getinfo` or `os.getenv("HOME")`.

### 4. Phase-Based Automation
- **Integrated Cleanup:** Assembly scripts must initialize the project FIRST (to close active projects) and then perform cleanup of old temporary files in Phase 2.
- **Defensive Coding:** Always use `tostring(prop or "Unknown")` for console logs to prevent runtime crashes.
- **Phase Logging:** Use clear, numbered headers (PHASE 1-6) for full transparency.

## Related Skills
- **Python Telemetry:** Refer to `skill/python-telemetry.md` for data processing standards.
- **Resolve API Optimization:** Refer to `skill/lua-resolve-api.md` for high-performance Lua scripting.

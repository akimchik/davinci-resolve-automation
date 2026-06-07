---
name: davinci-resolve-automation
description: Automates 4K 60fps movie assembly and highlight generation in DaVinci Resolve. Use this skill when managing the akimchik/davinci-resolve-automation project to ensure professional standards and license compatibility.
---

# DaVinci Resolve Automation Standards

This skill enforces strict professional workflows for automating DaVinci Resolve 21 (Free and Studio) using Lua/Python.

## Core Mandates

### 1. Visual Standards (4K 60fps)
- **Resolution:** Strictly use Ultra HD (3840 x 2160).
- **Frame Rate:** Strictly use **60.00 fps** for both timeline and playback.
- **Verification:** Always verify these settings immediately after project creation.

### 2. License Compatibility (Resolve Free)
- **Neural Engine:** Never use `DetectSceneCuts()` or AI features in scripts intended for the Free version.
- **Hardware Acceleration:** Always use `Encoder = "Native"` (CPU) to avoid license pop-ups for 4K 60fps H.264/H.265 exports.
- **Proxies:** Explicitly disable proxies and optimized media (`perfProxyMediaMode = 0`) to ensure 4K source usage.

### 3. Professional Editing Workflows
- **Overlays:** To layer text on photos, follow this sequence:
  1. Switch to Edit page: `res:OpenPage("edit")`.
  2. Add background (JPG) to Track 1.
  3. Reset playhead: `timeline:SetCurrentTimecode(timeline:GetStartFrame())`.
  4. Insert Fusion Title (Text+).
- **Media Filtering:** Strictly use `find` with `-newermt` for date-based selection. Always exclude `lowres`, `LOWRES`, and metadata files (`._`).

### 4. Project Integrity
- **Config First:** Pull ALL paths, rates, and quality settings from `config.lua`. No hardcoding.
- **Global API Objects:** Core Resolve objects (`res`, `project`, `mediapool`, `timeline`) MUST be global (no `local` keyword) to prevent "nil value" errors during `dofile` execution.
- **Integrated Cleanup:** Assembly scripts must automatically delete previous temporary projects at the start of Phase 1.
- **Phase Logging:** Scripts must use clear, numbered headers (e.g., "--- PHASE X: [NAME] ---") to report progress.
- **Conventional Commits:** Every commit must follow the [Conventional Commits](https://www.conventionalcommits.org/) standard.

### 5. Workspace Maintenance
- **Cleanup:** Always provide and use `cleanup_resolve.lua` to force-close active projects and wipe temporary database entries before fresh runs.

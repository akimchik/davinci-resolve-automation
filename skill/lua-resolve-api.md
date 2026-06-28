---
name: lua-resolve-api-optimization
description: Advanced Lua scripting techniques for DaVinci Resolve API performance and 4K 60fps stability.
---

# Lua Resolve API Standards

## 1. High-Performance Initialization
- **Pre-Media Setup:** Set `timelineResolutionWidth`, `timelineResolutionHeight`, and `timelineFrameRate` *before* adding any items to the Media Pool.
- **60fps Lock:** In the Free version, explicitly set both `timelineFrameRate` and `timelinePlaybackFrameRate` to ensure sync.

## 2. Fusion Scripting & Keyframing
- **Undo Blocks:** Wrap heavy keyframing loops in `composition:StartUndo("Task")` and `composition:EndUndo()`. This batches UI updates and can improve performance by 5-10x.
- **Surgical Sync:** Only calculate frames that exist within the clip's local duration boundary. Do not inject keyframes for the entire timeline length on a single clip.
- **Single-Track Architecture:** Inject HUD elements natively into the `MediaIn` stream of Track 1 clips to prevent transparency artifacting and "Media Offline" (Red Frame) errors.

## 3. API Performance
- **Error Handling:** Use `tostring(value or "Unknown")` for all console logging to prevent "nil concatenation" errors.
- **Page Switching:** Explicitly call `res:OpenPage("edit")` or `res:OpenPage("fusion")` before performing page-specific manipulations.

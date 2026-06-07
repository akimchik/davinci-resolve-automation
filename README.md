# DaVinci Resolve Automation Scripts

Automate the creation of 4K 60fps diving movies and highlight reels directly from your camera's DCIM folder.

## Features

- **Movie Assembly:** Chronologically joins high-res MP4s and uses the first JPG of the day as a title background.
- **AI-Free Highlights:** Creates a punchy highlight reel by taking three 3-second "action slices" (Start, Mid, End) from every clip.
- **Integrated Cleanup:** Automatically wipes previous temporary projects at the start of every run.
- **Phase-Based Reporting:** Provides clear, numbered console output (PHASE 1-6) for full transparency.
- **Professional Overlays:** Uses Track Locking to render "Diving Session" text directly on top of your dive photos.
- **60fps Stability:** Implements a double-pass initialization to force and lock the 60fps frame rate in the Free version.
- **License-Safe:** Configured with "Native" CPU encoding to bypass "Hardware Acceleration" limitations.
- **Automated Export:** Sets the Deliver page to "Best" quality and auto-starts the render.

## Project Structure

- `create_movie.lua`: Main script to build the full history movie.
- `create_highlights.lua`: Script to build the condensed action reel.
- `cleanup_resolve.lua`: Utility to wipe previous project attempts and clear memory.
- `config.lua`: Centralized configuration for your local environment (paths, frame rates, etc.).

## Setup & Usage

### 1. Configuration
Edit `config.lua` to match your current setup:
- Update `search_dir` to point to your SD card or media folder.
- Set the `date_filter` to the day you want to process.

### 2. Running in DaVinci Resolve
1. Open **DaVinci Resolve**.
2. Open the **Console** (`Workspace -> Console`).
3. Switch to the **Lua** tab.
4. Run a script using the `dofile` command.

**Option A: Default to Today**
```lua
dofile("path/to/davinci-resolve-automation/create_movie.lua")
```

**Option B: Specific Date Override**
If you want to process a different day without editing the config file:
```lua
DIVE_DATE = "2026-06-06"; dofile("path/to/davinci-resolve-automation/create_movie.lua")
```
*(Make sure to use the YYYY-MM-DD format)*

## Professional Recommendations
- Always run `cleanup_resolve.lua` if you encounter frame-rate mismatch errors (e.g., Resolve stuck on 24fps).
- Ensure your `config.lua` path is absolute in the `dofile` command.

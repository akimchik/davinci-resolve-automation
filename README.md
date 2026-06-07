# DaVinci Resolve Automation Scripts

Automate the creation of 4K 60fps diving movies and highlight reels directly from your camera's DCIM folder.

## Features

- **Movie Assembly:** Chronologically joins all high-res MP4s and JPGs from a specific date.
- **AI-Free Highlights:** Creates a punchy highlight reel by taking 4-second "action slices" from the middle of every clip.
- **License-Safe:** Configured to avoid "Hardware Acceleration" and "Resolution Limit" errors in the Resolve Free version.
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
4. Run a script using the `dofile` command:

**To create the full movie:**
```lua
dofile("/Users/lynnyk/repos/github/akimchik/davinci-resolve-automation/create_movie.lua")
```

**To create the action highlights:**
```lua
dofile("/Users/lynnyk/repos/github/akimchik/davinci-resolve-automation/create_highlights.lua")
```

**To clean up projects:**
```lua
dofile("/Users/lynnyk/repos/github/akimchik/davinci-resolve-automation/cleanup_resolve.lua")
```

## Professional Recommendations
- Always run `cleanup_resolve.lua` if you encounter frame-rate mismatch errors (e.g., Resolve stuck on 24fps).
- Ensure your `config.lua` path is absolute in the `dofile` command.

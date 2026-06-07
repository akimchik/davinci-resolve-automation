-- Project Configuration for DaVinci Resolve Automation
-- Edit this file to match your local environment

local Config = {
    -- Source media directory
    search_dir = "/Volumes/Untitled/DCIM/100PRLNZ/",
    -- Project defaults
    resolution_width = 3840,
    resolution_height = 2160,
    frame_rate = "60", -- Reverted to exact 60 as per user request
    video_quality = "Best",
    -- Target export directory
    export_dir = os.getenv("HOME") .. "/Movies/",
    -- Filtering logic
    filters = {
        exclude_patterns = { "lowres", "/\\._" },
        include_extensions = { ".MP4", ".JPG" },
        date_filter = os.date("%Y-%m-%d") -- Automatically uses the current date
    },
    -- Highlights specific
    highlight_slice_duration = 20 -- Seconds per clip to hit 5-7 min target
}

return Config

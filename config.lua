-- Project Configuration for DaVinci Resolve Automation
-- Edit this file to match your local environment

local Config = {
    -- Source media directory
    search_dir = "/Volumes/Untitled/DCIM/100PRLNZ/",
    
    -- Project defaults
    resolution_width = 3840,
    resolution_height = 2160,
    frame_rate = "60", -- Use "60" or "59.94"
    video_quality = "Best",
    
    -- Target export directory
    export_dir = os.getenv("HOME") .. "/Movies/",
    
    -- Filtering logic
    filters = {
        exclude_patterns = { "lowres", "/\\._" },
        include_extensions = { ".MP4", ".JPG" },
        date_filter = "2026-06-06" -- Format: YYYY-MM-DD
    },
    
    -- Highlights specific
    highlight_slice_duration = 4 -- Seconds
}

return Config

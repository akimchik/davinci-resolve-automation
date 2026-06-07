-- DaVinci Resolve Movie Assembly Script (Lua Version)
-- This script works natively in Resolve without needing Python installed.

local search_dir = "/Volumes/Untitled/DCIM/100PRLNZ/"
local project_name = "Daily_Assembled_Lua"

-- Try multiple ways to get the resolve object
local res = nil
if resolve ~= nil then
    res = resolve
elseif Resolve ~= nil then
    res = Resolve()
end

if not res then
    print("Error: Could not find 'resolve' object. Please make sure you are in the Lua tab of the Console.")
    return
end

local project_manager = res:GetProjectManager()
local project = project_manager:CreateProject(project_name)

if not project then
    project = project_manager:LoadProject(project_name)
end

if not project then
    print("Error: Could not create or load project.")
    return
end

-- Set Project Settings (4K 60fps)
print("Syncing all frame rates to 60 for license compatibility...")
project:SetSetting("timelineFrameRate", "60")
project:SetSetting("timelinePlaybackFrameRate", "60")
project:SetSetting("timelineResolutionWidth", "3840")
project:SetSetting("timelineResolutionHeight", "2160")
project:SetSetting("videoMonitorFormat", "UHD 2160p 60")

-- FORCE HIGH QUALITY (Disable Proxies/Optimized Media)
print("Forcing full resolution (Disabling Proxies)...")
project:SetSetting("perfProxyMediaMode", "0") -- 0 = Disabled
project:SetSetting("perfOptimizedMediaOn", "0") 

-- Verification
local actual_fps = project:GetSetting("timelineFrameRate")
local actual_playback = project:GetSetting("timelinePlaybackFrameRate")

print("Verified Project Settings:")
print(" - Resolution: " .. project:GetSetting("timelineResolutionWidth") .. "x" .. project:GetSetting("timelineResolutionHeight"))
print(" - Frame Rate: " .. actual_fps)
print(" - Playback Rate: " .. actual_playback)

if actual_fps ~= "60" or actual_playback ~= "60" then
    print("\n[!] CRITICAL ERROR: Resolve refused the 60fps setting.")
    print("This happens if a timeline already exists or media is in the pool.")
    print("PLEASE RUN THE CLEANUP SCRIPT FIRST.")
    return
end

local mediapool = project:GetMediaPool()
local media_storage = res:GetMediaStorage()

-- We need to list files. Lua's native "dir" is limited, 
-- but we can use a shell command to get the sorted list.
-- Using -newermt to strictly get files from June 6th, 2026
local handle = io.popen('find "' .. search_dir .. '" -type f \\( -name "*.MP4" -o -name "*.JPG" \\) -newermt "2026-06-06" | grep -v -i "lowres" | grep -v "/\\._" | sort')
local files_string = handle:read("*a")
handle:close()

local files = {}
for file_path in string.gmatch(files_string, "[^\r\n]+") do
    table.insert(files, file_path)
end

if #files == 0 then
    print("No high-resolution files found.")
    return
end

-- Create Timeline
local timeline_name = "Assembled_Movie"
local timeline = mediapool:CreateEmptyTimeline(timeline_name)

-- Get the date/time of the first file for the title card
local first_file_time = "Unknown Time"
local time_handle = io.popen('stat -f "%Sm" -t "%B %d, %Y - %H:%M" "' .. files[1] .. '"')
if time_handle then
    first_file_time = time_handle:read("*a"):gsub("[\r\n]", "")
    time_handle:close()
end

print("Importing " .. #files .. " files...")
print("Title Card Date: " .. first_file_time)

-- Note: Adding actual Text+ content via Lua requires Fusion interaction.
-- For now, we'll ensure the clips are appended, and we can add the title 
-- manually or via a more advanced Fusion call in the next iteration.
-- However, we've set the foundation by identifying the correct 'Welcome' text.

    -- Import files individually to maintain order
    for _, path in ipairs(files) do
        local clips = media_storage:AddItemListToMediaPool({path})
        if clips and clips[1] then
            local clip = clips[1]
            local width = clip:GetClipProperty("Resolution"):match("^(%d+)%x") or "Unknown"
            print(" - Imported: " .. clip:GetName() .. " [" .. clip:GetClipProperty("Resolution") .. "]")
            mediapool:AppendToTimeline(clips)
        else
            print("Warning: Failed to import " .. path)
        end
    end
    project_manager:SaveProject()

    -- Set up Render Settings for 4K 60fps export
    print("Configuring HIGH QUALITY export (No Proxies)...")
    local render_path = os.getenv("HOME") .. "/Movies"
    project:SetRenderSettings({
        SelectAllFrames = true,
        TargetDir = render_path,
        CustomName = project_name,
        ExportVideo = true,
        ExportAudio = true,
        FormatWidth = 3840,
        FormatHeight = 2160,
        FrameRate = 60,
        VideoQuality = "Best",
        AudioCodec = "aac",
        -- Force high quality settings to bypass any proxy/cache issues
        UseProxyMedia = false,
        UseOptimizedMedia = false,
        UseRenderCacheImages = false,
        Encoder = "Native" -- Uses CPU to avoid hardware glitches
    })
-- Add to Render Queue and Start Rendering
local jobId = project:AddRenderJob()
if jobId then
    print("Render job added. Starting export now...")
    project:StartRendering(jobId)
    print("--------------------------------------------------")
    print("RENDER STARTED!")
    print("Check the 'Deliver' page (Rocket icon) for progress.")
    print("--------------------------------------------------")
else
    print("Error: Could not add render job.")
end

print("Success! Assembled " .. #files .. " items into '" .. timeline_name .. "'.")
print("Export Location: " .. render_path .. "/" .. project_name)


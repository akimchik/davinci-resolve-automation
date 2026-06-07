-- DaVinci Resolve Robust Highlight Script (Lua)
-- 100% License-Proof: No AI, No Hardware Acceleration checks.
-- Uses "Middle Slice" logic to find actionable episodes.

local search_dir = "/Volumes/Untitled/DCIM/100PRLNZ/"
local timestamp = os.date("%H%M%S")
local project_name = "Action_Highlights_" .. timestamp

local res = nil
if resolve ~= nil then res = resolve elseif Resolve ~= nil then res = Resolve() end
if not res then print("Error: Resolve not found") return end

local project_manager = res:GetProjectManager()

-- Create a brand new project with a unique name to avoid conflicts
print("Creating fresh project: " .. project_name)
local project = project_manager:CreateProject(project_name)
if not project then
    print("Error: Could not create project. Try restarting Resolve.")
    return
end

-- Force 60fps
print("Applying 60fps settings...")
project:SetSetting("timelineFrameRate", "60")
project:SetSetting("timelinePlaybackFrameRate", "60")
project:SetSetting("timelineResolutionWidth", "3840")
project:SetSetting("timelineResolutionHeight", "2160")

-- FORCE HIGH QUALITY (Disable Proxies/Optimized Media)
print("Forcing full resolution (Disabling Proxies)...")
project:SetSetting("perfProxyMediaMode", "0") -- 0 = Disabled
project:SetSetting("perfOptimizedMediaOn", "0") 

local mediapool = project:GetMediaPool()
local media_storage = res:GetMediaStorage()

-- Filter Today's Files
local handle = io.popen('find "' .. search_dir .. '" -type f \\( -name "*.MP4" -o -name "*.JPG" \\) -newermt "2026-06-06" | grep -v -i "lowres" | grep -v "/\\._" | sort')
local files_string = handle:read("*a")
handle:close()

local files = {}
for path in string.gmatch(files_string, "[^\r\n]+") do table.insert(files, path) end

if #files == 0 then print("No files found for today.") return end

-- Master Timeline
local timeline = mediapool:CreateEmptyTimeline("Highlights_Reel")
if not timeline then print("Error: Could not create timeline") return end

print("Processing " .. #files .. " files for Action Reel...")

for i, path in ipairs(files) do
    local clips = media_storage:AddItemListToMediaPool({path})
    if clips and clips[1] then
        local clip = clips[1]
        print(" - Processing: " .. clip:GetName() .. " [" .. clip:GetClipProperty("Resolution") .. "]")
        
        -- Logic: Take a 4-second slice from the middle of the clip (where action is highest)
        local duration = tonumber(clip:GetClipProperty("Frames")) or 0
        if duration > 300 then -- If clip is longer than 5 seconds
            local mid = math.floor(duration / 2)
            local start_frame = mid - 120 -- 2 seconds before middle (120 frames at 60fps)
            local end_frame = mid + 120   -- 2 seconds after middle
            
            -- CORRECT API METHOD: Set In/Out marks on the clip before appending
            clip:SetMarkInOut(start_frame, end_frame)
            
            print("   -> Trimming to 4s action segment.")
            mediapool:AppendToTimeline({clip})
        else
            -- For short clips or JPGs, just add them
            mediapool:AppendToTimeline({clip})
        end
    end
end

-- Render Settings (NATIVE CPU ENCODER to avoid Hardware License popup)
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
-- Start Render
local jobId = project:AddRenderJob()
if jobId then
project:StartRendering(jobId)
print("\n--------------------------------------------------")
print("SUCCESS! Action highlights assembled.")
print("RENDER STARTED at 60fps!")
print("Check the 'Deliver' page for progress.")
print("--------------------------------------------------")
else
print("Error: Could not start render.")
end
project_manager:SaveProject()

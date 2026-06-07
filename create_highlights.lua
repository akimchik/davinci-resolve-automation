-- DaVinci Resolve Action Highlights Script (Lua Version)
-- 100% License-Proof: No AI (Scene Detection), No Hardware Encoding.
-- Logic: Takes three 3-second slices from each clip (Start, Middle, End).
-- This ensures you capture the "Action" without paying for Studio.

-- 1. Load Configuration
local config_path = "/Users/lynnyk/repos/github/akimchik/davinci-resolve-automation/config.lua"
local Config = dofile(config_path)

-- 2. Setup Resolve Object
local res = nil
if resolve ~= nil then res = resolve elseif Resolve ~= nil then res = Resolve() end
if not res then print("Error: Resolve not found") return end

local project_manager = res:GetProjectManager()
local project_name = "Action_Reel_" .. os.date("%H%M%S")

-- 3. Create Project
print("Creating project: " .. project_name)
local project = project_manager:CreateProject(project_name)
if not project then return end

-- 4. FORCE 60FPS (User insists on 60.00)
print("Initializing Project at 60 fps...")
project:SetSetting("timelineResolutionWidth", tostring(Config.resolution_width))
project:SetSetting("timelineResolutionHeight", tostring(Config.resolution_height))
project:SetSetting("timelineFrameRate", "60")
project:SetSetting("timelinePlaybackFrameRate", "60")

-- Force high quality (No Proxies)
project:SetSetting("perfProxyMediaMode", "0")
project:SetSetting("perfOptimizedMediaOn", "0")

local mediapool = project:GetMediaPool()
local media_storage = res:GetMediaStorage()

-- Create Master Timeline and Set it as Current
local master_timeline = mediapool:CreateEmptyTimeline("Action_Highlights")
project:SetCurrentTimeline(master_timeline)

-- 5. Add Welcome Title Card (Text+)
local welcome_text = os.date("%B %d, %Y")
print("Adding Welcome Card: " .. welcome_text)
local titleItem = master_timeline:InsertFusionTitleIntoTimeline("Text+")
if titleItem then
    local comp = titleItem:GetFusionCompByIndex(1)
    if comp then
        local tools = comp:GetToolList(false, "TextPlus")
        if tools[1] then
            tools[1]:SetInput("StyledText", "Action Highlights\n" .. welcome_text)
            print(" - Title set successfully.")
        end
    end
end

-- 6. Filter Logic (Today's Files)
local filter_cmd = 'find "' .. Config.search_dir .. '" -type f \\( -name "*.MP4" \\) -newermt "' .. Config.filters.date_filter .. '"'
for _, pattern in ipairs(Config.filters.exclude_patterns) do
    filter_cmd = filter_cmd .. ' | grep -v -i "' .. pattern .. '"'
end
filter_cmd = filter_cmd .. ' | sort'

local handle = io.popen(filter_cmd)
local files_string = handle:read("*a")
handle:close()

local files = {}
for path in string.gmatch(files_string, "[^\r\n]+") do table.insert(files, path) end

if #files == 0 then print("No files found") return end

-- 6. Processing - The "Triple Slice" Action Method
print("Building Action Reel from " .. #files .. " files...")

for i, path in ipairs(files) do
    local clips = media_storage:AddItemListToMediaPool({path})
    if clips and clips[1] then
        local clip = clips[1]
        local total_frames = tonumber(clip:GetClipProperty("Frames")) or 0
        
        -- If clip is long enough, take 3 segments (3 seconds each)
        -- 180 frames = 3 seconds at 60fps
        if total_frames > 600 then 
            print(" - Clip " .. i .. ": Creating 3 Action Slices.")
            
            -- Slice 1: Near the start (after 2 seconds of camera turn on)
            clip:SetMarkInOut(120, 300)
            mediapool:AppendToTimeline({clip})
            
            -- Slice 2: The exact middle
            local mid = math.floor(total_frames / 2)
            clip:SetMarkInOut(mid - 90, mid + 90)
            mediapool:AppendToTimeline({clip})
            
            -- Slice 3: Near the end
            clip:SetMarkInOut(total_frames - 300, total_frames - 120)
            mediapool:AppendToTimeline({clip})
        else
            -- Short clip: Add whole thing
            mediapool:AppendToTimeline({clip})
        end
    end
end

-- 7. Render Settings (STRICTLY CPU/NATIVE TO AVOID LICENSE ERROR)
print("Configuring 60fps export (Native CPU)...")
project:SetRenderSettings({
    SelectAllFrames = true,
    TargetDir = Config.export_dir,
    CustomName = project_name,
    ExportVideo = true,
    ExportAudio = true,
    FormatWidth = 3840,
    FormatHeight = 2160,
    FrameRate = 60,
    VideoQuality = "Best",
    UseProxyMedia = false,
    Encoder = "Native" -- This is the key to bypassing the acceleration pop-up
})

-- Auto-Start Render
local jobId = project:AddRenderJob()
if jobId then 
    project:StartRendering(jobId) 
    print("\n--------------------------------------------------")
    print("SUCCESS! Action Reel Assembled.")
    print("RENDER STARTED at 60fps!")
    print("--------------------------------------------------")
end

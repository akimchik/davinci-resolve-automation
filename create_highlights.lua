-- DaVinci Resolve AI Highlight Script (Lua Version)
-- Integrated with config.lua

-- 1. Load Configuration
local config_path = "/Users/lynnyk/repos/github/akimchik/davinci-resolve-automation/config.lua"
local Config = dofile(config_path)

-- 2. Setup Resolve Object
local res = nil
if resolve ~= nil then res = resolve elseif Resolve ~= nil then res = Resolve() end
if not res then print("Error: Resolve not found") return end

local project_manager = res:GetProjectManager()
local project_name = "Highlights_" .. os.date("%H%M%S")

-- 3. Create Project
print("Creating project: " .. project_name)
local project = project_manager:CreateProject(project_name)
if not project then return end

-- 4. FORCE 60FPS
print("Initializing Project at " .. Config.frame_rate .. " fps...")
project:SetSetting("timelineResolutionWidth", tostring(Config.resolution_width))
project:SetSetting("timelineResolutionHeight", tostring(Config.resolution_height))
project:SetSetting("timelineFrameRate", Config.frame_rate)
project:SetSetting("timelinePlaybackFrameRate", Config.frame_rate)

-- Force high quality (No Proxies)
project:SetSetting("perfProxyMediaMode", "0")
project:SetSetting("perfOptimizedMediaOn", "0")

local mediapool = project:GetMediaPool()
local media_storage = res:GetMediaStorage()

-- Create Master Timeline immediately to lock the frame rate
local master_timeline = mediapool:CreateEmptyTimeline("Highlights_Reel")
if not master_timeline then
    print("Error: Could not create master timeline.")
    return
end

-- 5. Filter Logic
local filter_cmd = 'find "' .. Config.search_dir .. '" -type f \\( -name "*.MP4" -o -name "*.JPG" \\) -newermt "' .. Config.filters.date_filter .. '"'
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

-- Master Timeline
local master_timeline = mediapool:CreateEmptyTimeline("Highlights_Reel")

print("Processing " .. #files .. " files for Action Reel...")
for i, path in ipairs(files) do
    local clips = media_storage:AddItemListToMediaPool({path})
    if clips and clips[1] then
        local clip = clips[1]
        local duration = tonumber(clip:GetClipProperty("Frames")) or 0
        
        if duration > (Config.highlight_slice_duration * 60) then
            local mid = math.floor(duration / 2)
            local offset = math.floor((Config.highlight_slice_duration * 60) / 2)
            clip:SetMarkInOut(mid - offset, mid + offset)
            print(" - Clip " .. i .. ": 4s middle slice.")
        end
        mediapool:AppendToTimeline({clip})
    end
end

-- 6. Render Settings
print("Configuring export...")
project:SetRenderSettings({
    SelectAllFrames = true,
    TargetDir = Config.export_dir,
    CustomName = project_name,
    ExportVideo = true,
    ExportAudio = true,
    FormatWidth = Config.resolution_width,
    FormatHeight = Config.resolution_height,
    FrameRate = tonumber(Config.frame_rate),
    VideoQuality = Config.video_quality,
    UseProxyMedia = false,
    UseOptimizedMedia = false,
    Encoder = "Native"
})

local jobId = project:AddRenderJob()
if jobId then project:StartRendering(jobId) end

project_manager:SaveProject()
print("\n--------------------------------------------------")
print("SUCCESS! Highlights Rendering at " .. Config.frame_rate .. " fps.")
print("--------------------------------------------------")

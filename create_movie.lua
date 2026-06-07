-- DaVinci Resolve Movie Assembly Script (Lua Version)
-- Integrated with config.lua

-- 1. Load Configuration
-- Make sure to provide the absolute path to your repo folder here
local config_path = "/Users/lynnyk/repos/github/akimchik/davinci-resolve-automation/config.lua"
local Config = dofile(config_path)

-- 2. Setup Resolve Object
local res = nil
if resolve ~= nil then res = resolve elseif Resolve ~= nil then res = Resolve() end
if not res then
    print("Error: Could not find 'resolve' object.")
    return
end

local project_manager = res:GetProjectManager()
local project_name = "Full_Movie_" .. os.date("%H%M%S") -- Dynamic name to avoid existing project bugs

-- 3. Create Project
print("Creating project: " .. project_name)
local project = project_manager:CreateProject(project_name)
if not project then
    print("Error: Could not create project. Resolve might be locked.")
    return
end

-- 4. FORCE 60FPS (Critical for License and Quality)
-- We must set these BEFORE importing anything
print("Initializing Project at " .. Config.frame_rate .. " fps...")
project:SetSetting("timelineResolutionWidth", tostring(Config.resolution_width))
project:SetSetting("timelineResolutionHeight", tostring(Config.resolution_height))
project:SetSetting("timelineFrameRate", Config.frame_rate)
project:SetSetting("timelinePlaybackFrameRate", Config.frame_rate)
project:SetSetting("videoMonitorFormat", "UHD 2160p " .. Config.frame_rate)

-- Force high quality (No Proxies)
project:SetSetting("perfProxyMediaMode", "0")
project:SetSetting("perfOptimizedMediaOn", "0")

local mediapool = project:GetMediaPool()

-- Create Timeline immediately to "lock" the frame rate
local timeline = mediapool:CreateEmptyTimeline("Master_Timeline")

-- Verification Check
local actual_fps = project:GetSetting("timelineFrameRate")
local actual_playback = project:GetSetting("timelinePlaybackFrameRate")
print("Verified Settings: " .. actual_fps .. " fps / " .. actual_playback .. " playback")

-- 5. Add Welcome Title Card (Text+)
-- Use the filter date for the title
local welcome_text = os.date("%B %d, %Y")
print("Adding Welcome Card for: " .. welcome_text)

local titleItem = timeline:InsertFusionTitleIntoTimeline("Text+")
if titleItem then
    local comp = titleItem:GetFusionCompByIndex(1)
    if comp then
        local tools = comp:GetToolList(false, "TextPlus")
        if tools[1] then
            tools[1]:SetInput("StyledText", "Diving Session\n" .. welcome_text)
            print(" - Title set successfully.")
        end
    end
end

-- 6. Import Media
local media_storage = res:GetMediaStorage()

-- Filter logic from config
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

if #files == 0 then
    print("No files found for date: " .. Config.filters.date_filter)
    return
end

print("Importing " .. #files .. " files...")
for i, path in ipairs(files) do
    local clips = media_storage:AddItemListToMediaPool({path})
    if clips and clips[1] then
        print(" - Clip " .. i .. ": " .. clips[1]:GetName() .. " [" .. clips[1]:GetClipProperty("Resolution") .. "]")
        mediapool:AppendToTimeline(clips)
    end
end

-- 6. Render Settings (High Quality 60fps)
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
if jobId then
    project:StartRendering(jobId)
    print("\n--------------------------------------------------")
    print("SUCCESS! Movie Assembled and Render Started.")
    print("--------------------------------------------------")
end

project_manager:SaveProject()

-- DaVinci Resolve Movie Assembly Script (Lua Version)
-- Integrated with config.lua and Professional Overlay Logic

-- 1. Load Configuration
local config_path = "/Users/lynnyk/repos/github/akimchik/davinci-resolve-automation/config.lua"
local Config = dofile(config_path)

-- 2. Setup Resolve Objects
local res = nil
if resolve ~= nil then res = resolve elseif Resolve ~= nil then res = Resolve() end
if not res then print("Error: Resolve not found") return end

local project_manager = res:GetProjectManager()
local media_storage = res:GetMediaStorage()
local project_name = "Full_Movie_" .. os.date("%H%M%S")

-- 3. Create Project
print("Creating project: " .. project_name)
local project = project_manager:CreateProject(project_name)
if not project then return end

-- 4. FORCE 60FPS (First Pass)
project:SetSetting("timelineResolutionWidth", tostring(Config.resolution_width))
project:SetSetting("timelineResolutionHeight", tostring(Config.resolution_height))
project:SetSetting("timelineFrameRate", Config.frame_rate)
project:SetSetting("timelinePlaybackFrameRate", Config.frame_rate)

local mediapool = project:GetMediaPool()
local timeline = mediapool:CreateEmptyTimeline("Master_Timeline")

-- FORCE 60FPS (Second Pass - Lock after timeline creation)
project:SetSetting("timelineFrameRate", Config.frame_rate)
project:SetSetting("timelinePlaybackFrameRate", Config.frame_rate)

local actual_fps = project:GetSetting("timelineFrameRate")
local actual_playback = project:GetSetting("timelinePlaybackFrameRate")
print("Verified Settings: " .. actual_fps .. " fps / " .. actual_playback .. " playback")

-- 5. Identify Files
local filter_videos = 'find "' .. Config.search_dir .. '" -type f \\( -name "*.MP4" \\) -newermt "' .. Config.filters.date_filter .. '" | grep -v -i "lowres" | grep -v "/\\._" | sort'
local filter_title_jpg = 'find "' .. Config.search_dir .. '" -type f \\( -name "*.JPG" \\) -newermt "' .. Config.filters.date_filter .. '" | grep -v -i "lowres" | grep -v "/\\._" | sort | head -n 1'

local v_handle = io.popen(filter_videos)
local videos_string = v_handle:read("*a")
v_handle:close()

local j_handle = io.popen(filter_title_jpg)
local title_jpg = j_handle:read("*a"):gsub("[\r\n]", "")
j_handle:close()

local files = {}
for path in string.gmatch(videos_string, "[^\r\n]+") do table.insert(files, path) end
if #files == 0 then print("No videos found") return end

-- 6. Professional Overlay (JPG + Text)
local welcome_text = os.date("%B %d, %Y")
if title_jpg ~= "" then
    print("Overlaying Title on: " .. title_jpg)
    local jpg_clips = media_storage:AddItemListToMediaPool({title_jpg})
    if jpg_clips and jpg_clips[1] then
        -- Explicitly place JPG at Frame 0
        mediapool:AppendToTimeline({{mediaPoolItem = jpg_clips[1], recordFrame = 0}})
        
        -- Add Text+ and move to Frame 0
        local titleItem = timeline:InsertFusionTitleIntoTimeline("Text+")
        if titleItem then
            -- Note: InsertFusionTitle appends to playhead, so we move it
            local start_tc = timeline:GetStartFrame()
            timeline:SetCurrentTimecode(start_tc)
            
            local comp = titleItem:GetFusionCompByIndex(1)
            if comp then
                local tools = comp:GetToolList(false, "TextPlus")
                if tools[1] then
                    tools[1]:SetInput("StyledText", "Diving Session\n" .. welcome_text)
                    print(" - Overlay successful.")
                end
            end
        end
    end
end

-- 7. Import Videos
print("Importing " .. #files .. " videos...")
for i, path in ipairs(files) do
    local clips = media_storage:AddItemListToMediaPool({path})
    if clips then mediapool:AppendToTimeline(clips) end
end

-- 8. Render Settings
project:SetRenderSettings({
    SelectAllFrames = true,
    TargetDir = Config.export_dir,
    CustomName = project_name,
    ExportVideo = true,
    ExportAudio = true,
    FormatWidth = Config.resolution_width,
    FormatHeight = Config.resolution_height,
    FrameRate = 60,
    VideoQuality = "Best",
    Encoder = "Native"
})

local jobId = project:AddRenderJob()
if jobId then project:StartRendering(jobId) end

project_manager:SaveProject()
print("SUCCESS! Assembly and Render Started.")

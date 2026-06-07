-- DaVinci Resolve Action Highlights Script (Lua Version)
-- Integrated with config.lua and Professional Overlay Logic

-- 1. Load Configuration
local config_path = "/Users/lynnyk/repos/github/akimchik/davinci-resolve-automation/config.lua"
local Config = dofile(config_path)

-- 2. Setup Resolve Object
local res = nil
if resolve ~= nil then res = resolve elseif Resolve ~= nil then res = Resolve() end
if not res then print("Error: Resolve not found") return end

local project_manager = res:GetProjectManager()
local media_storage = res:GetMediaStorage()
local project_name = "Action_Reel_" .. os.date("%H%M%S")

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
local master_timeline = mediapool:CreateEmptyTimeline("Action_Highlights")
project:SetCurrentTimeline(master_timeline)

-- FORCE 60FPS (Second Pass - Lock after timeline creation)
project:SetSetting("timelineFrameRate", Config.frame_rate)
project:SetSetting("timelinePlaybackFrameRate", Config.frame_rate)

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
        res:OpenPage("edit")
        
        -- 1. Add JPG to Track 1
        mediapool:AppendToTimeline(jpg_clips)
        
        -- 2. LOCK Track 1 and reset playhead
        master_timeline:SetTrackLock("video", 1, true)
        master_timeline:SetCurrentTimecode(master_timeline:GetStartFrame())
        print(" - Video Track 1 locked for overlay.")
        
        -- 3. Add Text+ (Forces to Track 2)
        local titleItem = master_timeline:InsertFusionTitleIntoTimeline("Text+")
        if titleItem then
            local comp = titleItem:GetFusionCompByIndex(1)
            if comp then
                local tools = comp:GetToolList(false, "TextPlus")
                if tools[1] then
                    tools[1]:SetInput("StyledText", "Action Highlights\n" .. welcome_text)
                    print(" - Text set successfully on Track 2.")
                end
            end
        end
        
        -- 4. UNLOCK Track 1
        master_timeline:SetTrackLock("video", 1, false)
        -- Move playhead to END of intro (5 seconds)
        master_timeline:SetCurrentTimecode(master_timeline:GetStartFrame() + 300)
    end
end

-- 7. Processing - The "Triple Slice" Action Method
print("Building Action Reel from " .. #files .. " videos...")
for i, path in ipairs(files) do
    local clips = media_storage:AddItemListToMediaPool({path})
    if clips and clips[1] then
        local clip = clips[1]
        local total_frames = tonumber(clip:GetClipProperty("Frames")) or 0
        
        if total_frames > 600 then 
            -- Take 3 segments
            clip:SetMarkInOut(120, 300)
            mediapool:AppendToTimeline({clip})
            local mid = math.floor(total_frames / 2)
            clip:SetMarkInOut(mid - 90, mid + 90)
            mediapool:AppendToTimeline({clip})
            clip:SetMarkInOut(total_frames - 300, total_frames - 120)
            mediapool:AppendToTimeline({clip})
        else
            mediapool:AppendToTimeline({clip})
        end
    end
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
print("\n--------------------------------------------------")
print("SUCCESS! Action Reel Assembled and Rendering.")
print("--------------------------------------------------")

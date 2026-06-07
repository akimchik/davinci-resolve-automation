-- DaVinci Resolve Action Highlights Script (Lua Version)
-- Integrated with config.lua

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

-- 4. FORCE 60FPS
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

-- 5. Identify Files (22 Videos + 1 Title JPG)
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

if #files == 0 then
    print("No MP4 files found for date: " .. Config.filters.date_filter)
    return
end

print("Found " .. #files .. " video files for today.")

-- 6. Add Welcome Title Background (JPG)
local welcome_text = os.date("%B %d, %Y")
if title_jpg ~= "" then
    print("Using Title Background: " .. title_jpg)
    local title_clips = media_storage:AddItemListToMediaPool({title_jpg})
    if title_clips then
        mediapool:AppendToTimeline(title_clips)
        
        -- Add Text on top of the JPG
        local titleItem = master_timeline:InsertFusionTitleIntoTimeline("Text+")
        if titleItem then
            local comp = titleItem:GetFusionCompByIndex(1)
            if comp then
                local tools = comp:GetToolList(false, "TextPlus")
                if tools[1] then
                    tools[1]:SetInput("StyledText", "Action Highlights\n" .. welcome_text)
                    print(" - Title set successfully on JPG background.")
                end
            end
        end
    end
else
    print("No JPG found. Adding standard Welcome Card.")
    local titleItem = master_timeline:InsertFusionTitleIntoTimeline("Text+")
    if titleItem then
        local comp = titleItem:GetFusionCompByIndex(1)
        if comp then
            local tools = comp:GetToolList(false, "TextPlus")
            if tools[1] then
                tools[1]:SetInput("StyledText", "Action Highlights\n" .. welcome_text)
            end
        end
    end
end

-- 7. Processing - The "Triple Slice" Action Method
print("Building Action Reel from " .. #files .. " videos...")

for i, path in ipairs(files) do
    local clips = media_storage:AddItemListToMediaPool({path})
    if clips and clips[1] then
        local clip = clips[1]
        local clip_type = clip:GetClipProperty("Type")
        
        if clip_type == "Video" then
            local total_frames = tonumber(clip:GetClipProperty("Frames")) or 0
            
            -- If clip is long enough, take 3 segments (3 seconds each)
            -- 180 frames = 3 seconds at 60fps
            if total_frames > 600 then 
                print(" - Clip " .. i .. ": Creating 3 Action Slices.")
                
                -- Slice 1: Near the start
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
                mediapool:AppendToTimeline({clip})
            end
        else
            -- Photo/Still: Add directly
            print(" - Clip " .. i .. ": Adding Photo [" .. clip:GetName() .. "]")
            mediapool:AppendToTimeline({clip})
        end
    end
end

-- 8. Render Settings (Native CPU to avoid license error)
print("Configuring 60fps export...")
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
    Encoder = "Native"
})

-- Auto-Start Render
local jobId = project:AddRenderJob()
if jobId then 
    project:StartRendering(jobId) 
    print("\n--------------------------------------------------")
    print("SUCCESS! Action Reel Assembled with " .. #files .. " items.")
    print("RENDER STARTED at 60fps!")
    print("--------------------------------------------------")
end

project_manager:SaveProject()

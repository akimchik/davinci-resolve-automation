-- DaVinci Resolve Action Highlights Script (Lua Version)
-- Phase-Based Automation with High-Integrity Cleanup

-- ==================================================
-- PHASE 1: INITIALIZATION
-- ==================================================
local config_path = "/Users/lynnyk/repos/github/akimchik/davinci-resolve-automation/config.lua"
local Config = dofile(config_path)

res = nil
if resolve ~= nil then res = resolve elseif Resolve ~= nil then res = Resolve() end
if not res then print("Error: Resolve not found") return end

project_manager = res:GetProjectManager()
media_storage = res:GetMediaStorage()

local target_date = DIVE_DATE or Config.filters.date_filter
local project_name = "Action_Reel_" .. os.date("%H%M%S")

print("\n--- PHASE 1: INITIALIZING 4K 60FPS PROJECT ---")
print("Target Date: " .. target_date)

-- Creating project automatically closes the previous one, unlocking it for deletion
project = project_manager:CreateProject(project_name)
if not project then return end

project:SetSetting("timelineResolutionWidth", tostring(Config.resolution_width))
project:SetSetting("timelineResolutionHeight", tostring(Config.resolution_height))
project:SetSetting("timelineFrameRate", Config.frame_rate)
project:SetSetting("timelinePlaybackFrameRate", Config.frame_rate)

mediapool = project:GetMediaPool()
master_timeline = mediapool:CreateEmptyTimeline("Action_Highlights")
project:SetCurrentTimeline(master_timeline)

-- Re-apply to lock
project:SetSetting("timelineFrameRate", Config.frame_rate)
project:SetSetting("timelinePlaybackFrameRate", Config.frame_rate)
print(" - Settings Locked: " .. tostring(project:GetSetting("timelineFrameRate") or "Unknown") .. " fps")

-- ==================================================
-- PHASE 2: WORKSPACE CLEANUP
-- ==================================================
print("\n--- PHASE 2: WORKSPACE CLEANUP ---")
local projects = project_manager:GetProjectListInCurrentFolder()
if projects then
    for _, name in ipairs(projects) do
        -- Delete old automation projects that are now "unlocked"
        local is_match = name:match("^Full_Movie_") or name:match("^Action_Reel_") or name == "Cleanup_Buffer"
        if name ~= project_name and is_match then
            if project_manager:DeleteProject(name) then print(" - Deleted old project: " .. name) end
        end
    end
end

-- ==================================================
-- PHASE 3: MEDIA DISCOVERY
-- ==================================================
print("\n--- PHASE 3: DISCOVERING MEDIA ---")
local filter_videos = 'find "' .. Config.search_dir .. '" -type f \\( -name "*.MP4" \\) -newermt "' .. target_date .. '"'
filter_videos = filter_videos .. ' | grep -v -i "lowres" | grep -v "/\\._" | sort'

local filter_title_jpg = 'find "' .. Config.search_dir .. '" -type f \\( -name "*.JPG" \\) -newermt "' .. target_date .. '"'
filter_title_jpg = filter_title_jpg .. ' | grep -v -i "lowres" | grep -v "/\\._" | sort | head -n 1'

local v_handle = io.popen(filter_videos)
local videos_string = v_handle:read("*a")
v_handle:close()

local j_handle = io.popen(filter_title_jpg)
local title_jpg = j_handle:read("*a"):gsub("[\r\n]", "")
j_handle:close()

local files = {}
for path in string.gmatch(videos_string, "[^\r\n]+") do table.insert(files, path) end
if #files == 0 then print("No videos found for: " .. target_date) return end
print(" - Found " .. #files .. " high-res MP4 episodes.")

-- ==================================================
-- PHASE 4: INTRO OVERLAY
-- ==================================================
print("\n--- PHASE 4: GENERATING INTRO OVERLAY ---")
if title_jpg ~= "" then
    print(" - Using Title Background: " .. title_jpg)
    local jpg_clips = media_storage:AddItemListToMediaPool({title_jpg})
    if jpg_clips and jpg_clips[1] then
        res:OpenPage("edit")
        mediapool:AppendToTimeline(jpg_clips)
        master_timeline:SetTrackLock("video", 1, true)
        master_timeline:SetCurrentTimecode(master_timeline:GetStartFrame())
        
        local titleItem = master_timeline:InsertFusionTitleIntoTimeline("Text+")
        if titleItem then
            local comp = titleItem:GetFusionCompByIndex(1)
            if comp then
                local tools = comp:GetToolList(false, "TextPlus")
                if tools[1] then
                    tools[1]:SetInput("StyledText", "Action Highlights\n" .. target_date)
                    print("   -> Intro overlaid successfully.")
                end
            end
        end
        master_timeline:SetTrackLock("video", 1, false)
        master_timeline:SetCurrentTimecode(master_timeline:GetStartFrame() + 300)
    end
end

-- ==================================================
-- PHASE 5: ACTION HIGHLIGHT ASSEMBLY
-- ==================================================
print("\n--- PHASE 5: EXTRACTING ACTION SLICES ---")
for i, path in ipairs(files) do
    local clips = media_storage:AddItemListToMediaPool({path})
    if clips and clips[1] then
        local clip = clips[1]
        local total_frames = tonumber(clip:GetClipProperty("Frames")) or 0
        local clip_name = clip:GetName() or "Unknown"
        local clip_res = tostring(clip:GetClipProperty("Resolution") or "Unknown")
        print(" - Processing Clip " .. i .. ": " .. clip_name .. " [" .. clip_res .. "]")
        
        if total_frames > 600 then 
            print("   -> Slicing Start/Mid/End segments.")
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

-- ==================================================
-- PHASE 6: RENDER QUEUE
-- ==================================================
print("\n--- PHASE 6: CONFIGURING 4K 60FPS EXPORT ---")
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
    Encoder = "Native"
})

local jobId = project:AddRenderJob()
if jobId then 
    project:StartRendering(jobId) 
    print("\n--------------------------------------------------")
    print("SUCCESS! Action Highlights Render Started.")
    print("--------------------------------------------------")
end

project_manager:SaveProject()

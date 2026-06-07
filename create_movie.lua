-- DaVinci Resolve Movie Assembly Script (Lua Version)
-- Phase-Based Automation with Integrated Cleanup

-- ==================================================
-- PHASE 1: CONFIGURATION & CLEANUP
-- ==================================================
local config_path = "/Users/lynnyk/repos/github/akimchik/davinci-resolve-automation/config.lua"
local Config = dofile(config_path)

res = nil
if resolve ~= nil then res = resolve elseif Resolve ~= nil then res = Resolve() end
if not res then print("Error: Resolve not found") return end

project_manager = res:GetProjectManager()
media_storage = res:GetMediaStorage()

-- AUTO-CLEANUP: Wipe previous temp projects
print("\n--- PHASE 1: WORKSPACE CLEANUP ---")
-- Create and load a buffer project to "unlock" the active ones
project_manager:CreateProject("Cleanup_Buffer")
project_manager:LoadProject("Cleanup_Buffer")

local projects = project_manager:GetProjectListInCurrentFolder()
if projects then
    for _, name in ipairs(projects) do
        -- Delete old automation projects
        if name:match("^Full_Movie_") or name:match("^Action_Reel_") then
            if project_manager:DeleteProject(name) then print(" - Deleted old project: " .. name) end
        end
    end
end

-- ==================================================
-- PHASE 2: PROJECT INITIALIZATION
-- ==================================================
local target_date = DIVE_DATE or Config.filters.date_filter
local project_name = "Full_Movie_" .. os.date("%H%M%S")
print("\n--- PHASE 2: INITIALIZING 4K 60FPS PROJECT ---")
print("Target Date: " .. target_date)

project = project_manager:CreateProject(project_name)
if not project then print("Error: CreateProject failed") return end

project:SetSetting("timelineResolutionWidth", tostring(Config.resolution_width))
project:SetSetting("timelineResolutionHeight", tostring(Config.resolution_height))
project:SetSetting("timelineFrameRate", Config.frame_rate)
project:SetSetting("timelinePlaybackFrameRate", Config.frame_rate)

mediapool = project:GetMediaPool()
timeline = mediapool:CreateEmptyTimeline("Master_Timeline")

-- Lock 60fps
project:SetSetting("timelineFrameRate", Config.frame_rate)
project:SetSetting("timelinePlaybackFrameRate", Config.frame_rate)
print(" - Settings Locked: " .. project:GetSetting("timelineFrameRate") .. " fps")

-- ==================================================
-- PHASE 3: MEDIA DISCOVERY
-- ==================================================
print("\n--- PHASE 3: DISCOVERING MEDIA ---")
local filter_videos = 'find "' .. Config.search_dir .. '" -type f \\( -name "*.MP4" \\) -newermt "' .. target_date .. '" | grep -v -i "lowres" | grep -v "/\\._" | sort'
local filter_title_jpg = 'find "' .. Config.search_dir .. '" -type f \\( -name "*.JPG" \\) -newermt "' .. target_date .. '" | grep -v -i "lowres" | grep -v "/\\._" | sort | head -n 1'

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
        timeline:SetTrackLock("video", 1, true)
        timeline:SetCurrentTimecode(timeline:GetStartFrame())
        
        local titleItem = timeline:InsertFusionTitleIntoTimeline("Text+")
        if titleItem then
            local comp = titleItem:GetFusionCompByIndex(1)
            if comp then
                local tools = comp:GetToolList(false, "TextPlus")
                if tools[1] then
                    tools[1]:SetInput("StyledText", "Diving Session\n" .. target_date)
                    print("   -> Intro overlaid successfully.")
                end
            end
        end
        timeline:SetTrackLock("video", 1, false)
        timeline:SetCurrentTimecode(timeline:GetStartFrame() + 300) 
    end
end

-- ==================================================
-- PHASE 5: MOVIE ASSEMBLY
-- ==================================================
print("\n--- PHASE 5: ASSEMBLING DIVE HISTORY ---")
for i, path in ipairs(files) do
    local clips = media_storage:AddItemListToMediaPool({path})
    if clips and clips[1] then
        local clip_res = clips[1]:GetClipProperty("Resolution") or "Unknown"
        print(" - Importing Clip " .. i .. ": " .. clips[1]:GetName() .. " [" .. clip_res .. "]")
        mediapool:AppendToTimeline(clips)
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
    print("SUCCESS! Professional Movie Render Started.")
    print("--------------------------------------------------")
end

project_manager:SaveProject()

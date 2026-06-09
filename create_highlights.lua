-- DaVinci Resolve Action Highlights Script (Lua Version)
-- Phase-Based Automation with High-Integrity HUD Overlay

-- ==================================================
-- PHASE 1: INITIALIZATION & TELEMETRY GENERATION
-- ==================================================
local script_dir = debug.getinfo(1).source:match("@?(.*[/\\])") or "./"
local Config = dofile(script_dir .. "config.lua")

-- Support for CLI Overrides
local target_dive_id = nil
if arg then
    for i = 1, #arg do
        if arg[i] == "--logs_dir" and arg[i+1] then Config.logs_dir = arg[i+1] end
        if arg[i] == "--search_dir" and arg[i+1] then Config.search_dir = arg[i+1] end
        if arg[i] == "--date" and arg[i+1] then DIVE_DATE = arg[i+1] end
        if arg[i] == "--dive_id" and arg[i+1] then target_dive_id = tonumber(arg[i+1]) end
    end
end

res = nil
if _G.TEST_MODE then
    print("   [TEST MODE] Bypassing Live API")
else
    if resolve ~= nil then res = resolve elseif Resolve ~= nil then res = Resolve() end
end

if not _G.TEST_MODE and not res then print("Error: Resolve not found") return end

if not _G.TEST_MODE then
    project_manager = res:GetProjectManager()
    media_storage = res:GetMediaStorage()
end
local target_date = DIVE_DATE or Config.filters.date_filter

local year, month, day = target_date:match("(%d+)-(%d+)-(%d+)")
local target_ts = os.time({year = year, month = month, day = day})
local next_day_ts = target_ts + (24 * 3600)
local end_date = os.date("%Y-%m-%d", next_day_ts)

local project_name = "Action_Reel_HUD_" .. os.date("%H%M%S")

print("\n--- PHASE 1: GENERATING TELEMETRY ASSETS ---")
print("Date Range: " .. target_date .. " to " .. end_date)
local out_png = Config.assets_dir .. "dive_profile.png"
local out_lua = Config.assets_dir .. "telemetry_data.lua"

local py_cmd = string.format('"%s" "%s" "%s" "%s" "%s" "%s"',
    Config.python_path, Config.telemetry_script, Config.logs_dir,
    target_date, out_png, out_lua)

if target_dive_id then
    py_cmd = py_cmd .. ' --dive_id ' .. tostring(target_dive_id)
end

local py_handle = io.popen(py_cmd)
local py_output = py_handle:read("*a")
py_handle:close()
print(py_output)

local DiveTelemetry = dofile(out_lua)
if not DiveTelemetry then print("Error: Could not load telemetry data.") return end

-- ==================================================
-- PHASE 2: INITIALIZING 4K 60FPS PROJECT
-- ==================================================
print("\n--- PHASE 2: INITIALIZING 4K 60FPS PROJECT ---")
project = project_manager:CreateProject(project_name)
if not project then return end

project:SetSetting("timelineResolutionWidth", tostring(Config.resolution_width))
project:SetSetting("timelineResolutionHeight", tostring(Config.resolution_height))
project:SetSetting("timelineFrameRate", Config.frame_rate)
project:SetSetting("timelinePlaybackFrameRate", Config.frame_rate)

mediapool = project:GetMediaPool()
master_timeline = mediapool:CreateEmptyTimeline("Action_Highlights")
project:SetCurrentTimeline(master_timeline)

project:SetSetting("timelineFrameRate", Config.frame_rate)
project:SetSetting("timelinePlaybackFrameRate", Config.frame_rate)
local fps_info = tostring(project:GetSetting("timelineFrameRate") or "60")
print(" - Settings Locked: " .. fps_info .. " fps")

-- ==================================================
-- PHASE 3: WORKSPACE CLEANUP
-- ==================================================
print("\n--- PHASE 3: WORKSPACE CLEANUP ---")
local projects = project_manager:GetProjectListInCurrentFolder()
if projects then
    for _, name in ipairs(projects) do
        local is_match = name:match("^Full_Movie_") or name:match("^Action_Reel_") or name == "Cleanup_Buffer"
        if name ~= project_name and is_match then
            if project_manager:DeleteProject(name) then print(" - Deleted old project: " .. name) end
        end
    end
end

-- ==================================================
-- PHASE 4: DISCOVERING MEDIA
-- ==================================================
print("\n--- PHASE 4: DISCOVERING MEDIA ---")
local filter_videos = 'find "' .. Config.search_dir .. '" -type f \\( -name "*.MP4" \\) '
filter_videos = filter_videos .. '-newermt "' .. target_date .. '" ! -newermt "' .. end_date .. '" '
filter_videos = filter_videos .. '| grep -v -i "lowres" | grep -v "/\\._" | sort'

local filter_title_jpg = 'find "' .. Config.search_dir .. '" -type f \\( -name "*.JPG" \\) '
filter_title_jpg = filter_title_jpg .. '-newermt "' .. target_date .. '" ! -newermt "' .. end_date .. '" '
filter_title_jpg = filter_title_jpg .. '| grep -v -i "lowres" | grep -v "/\\._" | sort | head -n 1'

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
-- PHASE 5: GENERATING INTRO OVERLAY
-- ==================================================
print("\n--- PHASE 5: GENERATING INTRO OVERLAY ---")
res:OpenPage("edit")

if title_jpg ~= "" then
    local jpg_clips = media_storage:AddItemListToMediaPool({title_jpg})
    if jpg_clips and jpg_clips[1] then
        local added = mediapool:AppendToTimeline({{mediaPoolItem = jpg_clips[1], trackIndex = 1}})
        if added and added[1] then
            local comp = added[1]:AddFusionComp()
            if comp then
                local text = comp:AddTool("TextPlus")
                local merge = comp:AddTool("Merge")
                local media_in = comp:FindTool("MediaIn1")
                local media_out = comp:FindTool("MediaOut1")
                if text and merge and media_in and media_out then
                    merge.Background = media_in.Output
                    merge.Foreground = text.Output
                    media_out.Input = merge.Output
                    local welcome_text = target_date .. "\nMax Depth: "
                        .. DiveTelemetry.max_depth .. "m | Temp: " .. DiveTelemetry.min_temp .. "C"
                    text:SetInput("StyledText", "Action Highlights\n" .. welcome_text)
                    print("   -> Intro overlaid successfully.")
                end
            end
        end
    end
end

-- ==================================================
-- PHASE 6: EXTRACTING ACTION SLICES
-- ==================================================
print("\n--- PHASE 6: EXTRACTING ACTION SLICES ---")
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
            mediapool:AppendToTimeline({{mediaPoolItem = clip, trackIndex = 1}})
            local mid = math.floor(total_frames / 2)
            clip:SetMarkInOut(mid - 90, mid + 90)
            mediapool:AppendToTimeline({{mediaPoolItem = clip, trackIndex = 1}})
            clip:SetMarkInOut(total_frames - 300, total_frames - 120)
            mediapool:AppendToTimeline({{mediaPoolItem = clip, trackIndex = 1}})
        else
            mediapool:AppendToTimeline({{mediaPoolItem = clip, trackIndex = 1}})
        end
    end
end

-- ==================================================
-- PHASE 7: IMPLEMENTING DYNAMIC HUD
-- ==================================================
print("\n--- PHASE 7: IMPLEMENTING DYNAMIC HUD ---")
local hud_clips = media_storage:AddItemListToMediaPool({out_png})
if hud_clips and hud_clips[1] then
    local total_duration = master_timeline:GetEndFrame()
    master_timeline:AddTrack("video")
    master_timeline:AddTrack("video")
    mediapool:AppendToTimeline({{
        mediaPoolItem = hud_clips[1],
        startFrame = 0,
        endFrame = total_duration,
        recordFrame = 0,
        trackIndex = 2
    }})
    print(" - Graph overlay added to Track 2.")
    local hud_items_t3 = mediapool:AppendToTimeline({{
        mediaPoolItem = hud_clips[1],
        startFrame = 0,
        endFrame = total_duration,
        recordFrame = 0,
        trackIndex = 3
    }})
    if hud_items_t3 and hud_items_t3[1] then
        local comp = hud_items_t3[1]:AddFusionComp()
        if comp then
            local text_node = comp:AddTool("TextPlus")
            local dot_bg = comp:AddTool("Background")
            local dot_mask = comp:AddTool("EllipseMask")
            local merge_dot = comp:AddTool("Merge")
            local merge_text = comp:AddTool("Merge")
            local media_out = comp:FindTool("MediaOut1")
            local bg_transparent = comp:AddTool("Background")
            if text_node and merge_text and media_out and dot_bg and dot_mask and merge_dot and bg_transparent then
                bg_transparent:SetInput("Alpha", 0.0)
                dot_bg:SetInput("TopLeftRed", 1.0)
                dot_bg:SetInput("TopLeftGreen", 0.0)
                dot_bg:SetInput("TopLeftBlue", 0.0)
                dot_bg.EffectMask = dot_mask.Output
                dot_mask:SetInput("Width", 0.01)
                dot_mask:SetInput("Height", 0.01)
                merge_dot.Background = bg_transparent.Output
                merge_dot.Foreground = dot_bg.Output
                merge_text.Background = merge_dot.Output
                merge_text.Foreground = text_node.Output
                media_out.Input = merge_text.Output
                print(" - Animating HUD with " .. #DiveTelemetry.points .. " points...")
                local start_time = DiveTelemetry.points[1].t
                for _, p in ipairs(DiveTelemetry.points) do
                    local relative_sec = p.t - start_time
                    local frame = relative_sec * 60
                    if frame < total_duration then
                        text_node.StyledText[frame] = string.format("%.1fm | %.1fC", p.d, p.temp)
                        local inv_y = 1.0 - p.y
                        dot_mask.Center[frame] = { p.x, inv_y }
                        text_node.Center[frame] = { p.x, inv_y + 0.05 }
                    end
                end
                print("   -> HUD Animation complete.")
            end
        end
    end
end

-- ==================================================
-- PHASE 8: CONFIGURING 4K 60FPS EXPORT
-- ==================================================
print("\n--- PHASE 8: CONFIGURING 4K 60FPS EXPORT ---")
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
    print("SUCCESS! Action Highlights Render Started with HUD.")
    print("--------------------------------------------------")
end

project_manager:SaveProject()

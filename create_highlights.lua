-- DaVinci Resolve Action Highlights Script (Lua Version)
-- Phase-Based Automation with High-Integrity HUD Overlay

-- ==================================================
-- PHASE 1: INITIALIZATION & TELEMETRY GENERATION
-- ==================================================
local script_dir = debug.getinfo(1).source:match("@?(.*[/\\])") or "./"
local Config = dofile(script_dir .. "config.lua")
local Utils = dofile(script_dir .. "scripts/multi_dive_utils.lua")

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

print("\n--- PHASE 1: GENERATING MULTI-DIVE TELEMETRY ASSETS ---")
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
if not DiveTelemetry or not DiveTelemetry.dives then
    print("Error: Could not load multi-dive telemetry data.")
    return
end

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
if not _G.TEST_MODE then project:SetCurrentTimeline(master_timeline) end

local fps_info = tostring(project:GetSetting("timelineFrameRate") or "60")
print(" - Settings Locked: " .. fps_info .. " fps")

-- ==================================================
-- PHASE 3: WORKSPACE CLEANUP
-- ==================================================
print("\n--- PHASE 3: WORKSPACE CLEANUP ---")
local projects = project_manager:GetProjectListInCurrentFolder()
if projects then
    for _, name in ipairs(projects) do
        local is_match = name:match("^Full_Movie_") or name:match("^Action_Reel_")
        if name ~= project_name and is_match then
            project_manager:DeleteProject(name)
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
if #files == 0 then print("No videos found") return end
print(" - Found " .. #files .. " potential episodes.")

-- ==================================================
-- PHASE 5: ASSEMBLY, SLICING & HUD
-- ==================================================
print("\n--- PHASE 5: MOVIE ASSEMBLY & HUD ---")
if not _G.TEST_MODE then res:OpenPage("edit") end

if title_jpg ~= "" then
    local jpg_clips = media_storage:AddItemListToMediaPool({title_jpg})
    if jpg_clips and jpg_clips[1] then
        local added = mediapool:AppendToTimeline({{mediaPoolItem = jpg_clips[1], trackIndex = 1}})
        if added and added[1] then
            local jpg_item = added[1]
            local comp = jpg_item:AddFusionComp()
            if comp then
                local text = comp:AddTool("TextPlus")
                local merge = comp:AddTool("Merge")
                local media_in = comp:FindTool("MediaIn1")
                local media_out = comp:FindTool("MediaOut1")
                local xf = comp:AddTool("Transform")
                if text and merge and media_in and media_out and xf then
                    xf:SetInput("Size", 1.1)
                    xf.Size[jpg_item:GetDuration()] = 1.3
                    xf.Input = media_in.Output

                    merge.Background = xf.Output
                    merge.Foreground = text.Output
                    media_out.Input = merge.Output

                    local d_info = DiveTelemetry.dives[1]
                    local welcome_text = target_date .. "\nMax Depth: "
                        .. d_info.max_depth .. "m | Temp: " .. d_info.min_temp .. "C"
                    if d_info.lat ~= 0 then
                        welcome_text = welcome_text .. string.format(
                            "\nLocation: %.4f, %.4f", d_info.lat, d_info.lon)
                    end
                    text:SetInput("StyledText", "Action Highlights\n" .. welcome_text)
                    print("   -> Intro overlaid successfully.")
                end
            end
        end
    end
end

for _, path in ipairs(files) do
    local clips = media_storage:AddItemListToMediaPool({path})
    if clips and clips[1] then
        local clip = clips[1]
        local clip_date = clip:GetClipProperty("Date Created") or clip:GetClipProperty("Date")
        local clip_ts = Utils.parse_resolve_date(clip_date)

        -- Find corresponding dive
        local active_dive = nil
        for _, dive in ipairs(DiveTelemetry.dives) do
            if clip_ts and clip_ts >= (dive.start_time - 30) and clip_ts <= (dive.end_time + 30) then
                active_dive = dive
                break
            end
        end

        -- Fallback: If parsing failed or no match found, but there is only ONE dive today, assume it belongs.
        if not active_dive and #DiveTelemetry.dives == 1 then
            if not clip_ts then
                local w_msg = "   [Warning] Could not parse Date Created format: '%s'. Using Single-Dive Fallback."
                print(string.format(w_msg, tostring(clip_date)))
            end
            active_dive = DiveTelemetry.dives[1]
        end

        if active_dive then
            local clip_name = clip:GetName() or "Unknown"
            local total_frames = tonumber(clip:GetClipProperty("Frames")) or 0
            print(" - Slicing Clip: " .. clip_name .. " (Dive #" .. active_dive.dive_idx .. ")")

            -- Slicing Logic
            if total_frames > 600 then
                clip:SetMarkInOut(120, 300)
                local a1 = mediapool:AppendToTimeline({{mediaPoolItem = clip, trackIndex = 1}})
                local mid = math.floor(total_frames / 2)
                clip:SetMarkInOut(mid - 90, mid + 90)
                local a2 = mediapool:AppendToTimeline({{mediaPoolItem = clip, trackIndex = 1}})
                clip:SetMarkInOut(total_frames - 300, total_frames - 120)
                local a3 = mediapool:AppendToTimeline({{mediaPoolItem = clip, trackIndex = 1}})

                -- Inject HUD into slices
                local added_slices = {a1, a2, a3}
                for _, added in ipairs(added_slices) do
                    if added and added[1] then
                        local item = added[1]
                        if Config.underwater_lut ~= "" then item:SetLUT(1, Config.underwater_lut) end

                        local comp = item:AddFusionComp()
                        if comp then
                            local media_in = comp:FindTool("MediaIn1")
                            local media_out = comp:FindTool("MediaOut1")
                            local loader = comp:AddTool("Loader")
                            loader:SetInput("Clip", active_dive.graph_path)

                            local dot_bg = comp:AddTool("Background")
                            dot_bg:SetInput("TopLeftRed", 1.0)
                            local dot_mask = comp:AddTool("EllipseMask")
                            dot_mask:SetInput("Width", 0.01)
                            dot_mask:SetInput("Height", 0.01)
                            dot_bg.EffectMask = dot_mask.Output

                            local text_node = comp:AddTool("TextPlus")
                            local m1 = comp:AddTool("Merge")
                            local m2 = comp:AddTool("Merge")
                            local m3 = comp:AddTool("Merge")

                            m1.Background = media_in.Output
                            m1.Foreground = loader.Output
                            m2.Background = m1.Output
                            m2.Foreground = dot_bg.Output
                            m3.Background = m2.Output
                            m3.Foreground = text_node.Output
                            media_out.Input = m3.Output

                            for _, p in ipairs(active_dive.points) do
                                local rel_frame = (p.t - active_dive.start_time) * 60
                                text_node.StyledText[rel_frame] = string.format("%.1fm | %.1fC", p.d, p.temp)
                                dot_mask.Center[rel_frame] = { p.x, 1.0 - p.y }
                            end
                        end
                    end
                end
            end
        else
            print(" - Skipping Clip (No Telemetry Match): " .. clip:GetName())
        end
    end
end

if not _G.TEST_MODE then
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
        print("SUCCESS! Action Highlights Render Started with HUD.")
        print("--------------------------------------------------")
    end
    project_manager:SaveProject()
end

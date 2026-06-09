-- DaVinci Resolve Movie Assembly Script (Lua Version)
-- Phase-Based Automation with Global Multi-Dive Support
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
local project_name = "Full_Movie_Multi_HUD_" .. os.date("%H%M%S")

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
timeline = mediapool:CreateEmptyTimeline("Master_Timeline")

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
local v_handle = io.popen(filter_videos)
local videos_string = v_handle:read("*a")
v_handle:close()

local files = {}
for path in string.gmatch(videos_string, "[^\r\n]+") do table.insert(files, path) end
if #files == 0 then print("No videos found") return end
print(" - Found " .. #files .. " potential episodes.")

-- ==================================================
-- PHASE 5: MOVIE ASSEMBLY & HUD
-- ==================================================
print("\n--- PHASE 5: MOVIE ASSEMBLY & HUD ---")
if not _G.TEST_MODE then res:OpenPage("edit") end

local current_dive_idx = 0

for _, path in ipairs(files) do
    local clips = media_storage:AddItemListToMediaPool({path})
    if clips and clips[1] then
        local clip = clips[1]
        local clip_date = clip:GetClipProperty("Date Created") or clip:GetClipProperty("Date")
        local clip_ts = Utils.parse_resolve_date(clip_date)

        local active_dive = nil
        for _, dive in ipairs(DiveTelemetry.dives) do
            if clip_ts and clip_ts >= (dive.start_time - 30) and clip_ts <= (dive.end_time + 30) then
                active_dive = dive
                break
            end
        end

        if not active_dive and #DiveTelemetry.dives == 1 then
            active_dive = DiveTelemetry.dives[1]
        end

        if active_dive then
            if active_dive.dive_idx ~= current_dive_idx then
                current_dive_idx = active_dive.dive_idx
                print("\n   >>> SESSION START: Dive #" .. current_dive_idx)
            end

            print(" - Processing Clip: " .. clip:GetName() .. " (Dive #" .. current_dive_idx .. ")")
            local added = mediapool:AppendToTimeline({{mediaPoolItem = clip, trackIndex = 1}})
            if added and added[1] then
                local item = added[1]
                if Config.underwater_lut ~= "" then item:SetLUT(1, Config.underwater_lut) end

                -- Inject HUD: Single-Track Fusion Injection
                local comp = item:AddFusionComp()
                if comp then
                    local media_in = comp:FindTool("MediaIn1")
                    local media_out = comp:FindTool("MediaOut1")
                    local text_node = comp:AddTool("TextPlus")
                    local merge = comp:AddTool("Merge")

                    if media_in and media_out and text_node and merge then
                        -- Position Top-Right (5% from edge)
                        text_node:SetInput("Center", { 0.95, 0.95 })
                        text_node:SetInput("Size", 0.04)

                        merge.Background = media_in.Output
                        merge.Foreground = text_node.Output
                        media_out.Input = merge.Output

                        local clip_start_epoch = clip_ts or active_dive.start_time
                        local duration_frames = item:GetDuration()

                        -- Surgical Performance Loop
                        for _, p in ipairs(active_dive.points) do
                            local local_frame = (p.t - clip_start_epoch) * 60
                            if local_frame >= 0 and local_frame < duration_frames then
                                text_node.StyledText[local_frame] = string.format("%.1fm | %.1fC", p.d, p.temp)
                            end
                        end
                    end
                end
            end
        else
            print(" - Skipping Clip (No Telemetry): " .. clip:GetName())
        end
    end
end

if not _G.TEST_MODE then
    print("\n--- PHASE 7: CONFIGURING 4K 60FPS EXPORT ---")
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
end

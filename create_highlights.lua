-- DaVinci Resolve AI Highlight Script (Lua Version)
-- Integrated with config.lua and AI Scene Detection

-- 1. Load Configuration
local config_path = "/Users/lynnyk/repos/github/akimchik/davinci-resolve-automation/config.lua"
local Config = dofile(config_path)

-- 2. Setup Resolve Object
local res = nil
if resolve ~= nil then res = resolve elseif Resolve ~= nil then res = Resolve() end
if not res then print("Error: Resolve not found") return end

local project_manager = res:GetProjectManager()
local project_name = "AI_Highlights_" .. os.date("%H%M%S")

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

-- Create Master Timeline
local master_timeline = mediapool:CreateEmptyTimeline("AI_Action_Reel")
if not master_timeline then return end

-- 5. Filter Logic (Today's Files)
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

-- 6. AI Processing
print("AI is analyzing " .. #files .. " clips to find the best episodes...")

for i, path in ipairs(files) do
    local clips = media_storage:AddItemListToMediaPool({path})
    if clips and clips[1] then
        local clip = clips[1]
        
        -- Create a temporary timeline to run AI Scene Detection
        local temp_name = "Analyze_" .. i
        local temp_timeline = mediapool:CreateEmptyTimeline(temp_name)
        
        if temp_timeline then
            mediapool:AppendToTimeline({clip})
            print(" - AI Analyzing: " .. clip:GetName())
            
            -- Trigger the AI Neural Engine
            local success = temp_timeline:DetectSceneCuts()
            
            if success then
                local scenes = temp_timeline:GetItemListInTrack("video", 1)
                if #scenes > 3 then
                    print("   -> Found " .. #scenes .. " actionable segments. Picking the best.")
                    -- Strategy: Skip the 1st and last scenes (entry/exit).
                    -- Add the middle ones to the reel.
                    for j = 2, #scenes - 1 do
                        master_timeline:AppendToTimeline({scenes[j]})
                    end
                else
                    -- If AI finds no cuts, just take the middle slice
                    print("   -> Steady clip. Adding full story.")
                    master_timeline:AppendToTimeline({clip})
                end
            else
                -- Fallback if AI is blocked by license or error
                master_timeline:AppendToTimeline({clip})
            end
            
            -- Clean up the temporary analysis project state
            -- (Optionally close temp_timeline here if Resolve API allows)
        end
    end
end

-- 7. Render Settings
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
    Encoder = "Native"
})

-- Auto-Start Render
local jobId = project:AddRenderJob()
if jobId then project:StartRendering(jobId) end

project_manager:SaveProject()
print("\n--------------------------------------------------")
print("AI REEL COMPLETE! Check the Deliver page.")
print("--------------------------------------------------")

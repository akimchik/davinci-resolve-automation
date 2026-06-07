-- Telemetry Parser Module for DaVinci Resolve Automation
-- Extracts time-series data (Depth, Temp, GPS) from camera CSV logs

local TelemetryParser = {}

-- Utility to split CSV line
function TelemetryParser.split(inputstr, sep)
    if sep == nil then sep = "," end
    local t = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

function TelemetryParser.get_dive_stats(logs_dir, target_date)
    print("   -> Parsing logs in: " .. logs_dir)
    -- Filter logs for the specific date
    local cmd = 'grep "' .. target_date .. '" ' .. logs_dir .. '*.csv 2>/dev/null'
    local handle = io.popen(cmd)
    local lines = handle:read("*a")
    handle:close()
    local data = {
        max_depth = 0,
        min_temp = 100,
        avg_temp = 0,
        points = {}, -- Time-series points
        count = 0
    }
    local temp_sum = 0
    for line in string.gmatch(lines, "[^\r\n]+") do
        -- Skip the file prefix from grep (e.g. LOG17.csv:...)
        local clean_line = line:match(":(.*)") or line
        local fields = TelemetryParser.split(clean_line)
        if #fields >= 3 then
            local temp = tonumber(fields[2])
            local depth = tonumber(fields[3])
            local timestamp = fields[23] -- ISO8601
            if depth and temp then
                data.count = data.count + 1
                if depth > data.max_depth then data.max_depth = depth end
                if temp < data.min_temp then data.min_temp = temp end
                temp_sum = temp_sum + temp
                -- Store every 10th point for performance (summary graph)
                if data.count % 10 == 0 then
                    table.insert(data.points, {time = timestamp, d = depth, t = temp})
                end
            end
        end
    end
    if data.count > 0 then
        data.avg_temp = temp_sum / data.count
    else
        data.min_temp = 0
    end
    return data
end

return TelemetryParser

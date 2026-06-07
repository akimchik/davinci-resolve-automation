-- Telemetry Parser Module for DaVinci Resolve Automation
-- Extracts time-series data (Depth, Temp, GPS) from camera CSV logs

local TelemetryParser = {}

-- Professional CSV splitter that handles empty fields (e.g. ,,,)
function TelemetryParser.split(inputstr)
    local t = {}
    -- Add trailing comma to catch the last empty field if necessary
    local s = inputstr .. ","
    for field in s:gmatch("([^,]*),") do
        table.insert(t, field)
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
        max_temp = 0,
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

        -- Column Mapping based on CSV Header:
        -- 1: Epoch, 2: Temp, 3: Depth, ..., 23: ISO8601
        if #fields >= 23 then
            local temp = tonumber(fields[2])
            local depth = tonumber(fields[3])
            local iso_time = fields[23]

            if depth and temp then
                data.count = data.count + 1
                if depth > data.max_depth then data.max_depth = depth end
                if temp < data.min_temp then data.min_temp = temp end
                if temp > data.max_temp then data.max_temp = temp end
                temp_sum = temp_sum + temp

                -- Store every 10th point for performance (summary graph)
                if data.count % 10 == 0 then
                    table.insert(data.points, {time = iso_time, d = depth, t = temp})
                end
            end
        end
    end

    if data.count > 0 then
        data.avg_temp = temp_sum / data.count
    else
        data.min_temp = 0
        data.max_temp = 0
    end

    return data
end

return TelemetryParser

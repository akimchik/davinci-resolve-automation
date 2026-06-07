-- Test Driver for Telemetry Parser
-- Run this from terminal: lua tests/test_parser.lua

local script_dir = "./"
local parser_path = script_dir .. "telemetry_parser.lua"
local config_path = script_dir .. "config.lua"

-- 1. Load Modules
local TelemetryParser = dofile(parser_path)
local Config = dofile(config_path)

-- 2. Configuration for Test
local test_date = "2026-06-07"
local logs_dir = Config.logs_dir

print("==================================================")
print("TESTING TELEMETRY PARSER")
print("Target Date: " .. test_date)
print("Logs Dir:    " .. logs_dir)
print("==================================================\n")

-- 3. Run Parser
local data = TelemetryParser.get_dive_stats(logs_dir, test_date)

-- 4. Report Results
if data.count > 0 then
    print("SUCCESS: Data extracted successfully.")
    print(" - Total Rows Scanned: " .. data.count)
    print(" - Max Depth Found:    " .. data.max_depth .. " m")
    print(" - Max Temperature:    " .. data.max_temp .. " °C")
    print(" - Min Temperature:    " .. data.min_temp .. " °C")
    print(" - Avg Temperature:    " .. string.format("%.2f", data.avg_temp) .. " °C")
    print(" - Data Points (10s):  " .. #data.points)

    -- Print first 5 data points as sample
    print("\nSample Data Points (Time | Depth | Temp):")
    for i = 1, math.min(5, #data.points) do
        local p = data.points[i]
        local time_str = p.time or "Unknown"
        print(string.format("   [%d] %s | %.1fm | %.1f°C", i, time_str, p.d, p.t))
    end
else
    print("FAILURE: No data found for " .. test_date)
    print("Check if Config.logs_dir is correct and contains CSV files.")
end
print("\n==================================================")

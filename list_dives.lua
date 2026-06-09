-- DaVinci Resolve Utility: List Dive Sessions
-- Run this in the console to preview detected dives before rendering.

local script_dir = debug.getinfo(1).source:match("@?(.*[/\\])") or "./"
local Config = dofile(script_dir .. "config.lua")

local target_date = DIVE_DATE or Config.filters.date_filter
if arg then
    for i = 1, #arg do
        if arg[i] == "--date" and arg[i+1] then target_date = arg[i+1] end
        if arg[i] == "--logs_dir" and arg[i+1] then Config.logs_dir = arg[i+1] end
    end
end

print("\n==================================================")
print("  DIVE SESSION PREVIEW: " .. target_date)
print("==================================================")

local py_cmd = string.format('"%s" "%s" "%s" "%s" --list_only',
    Config.python_path, Config.telemetry_script, Config.logs_dir, target_date)

local py_handle = io.popen(py_cmd)
if py_handle then
    local py_output = py_handle:read("*a")
    py_handle:close()
    print(py_output)
else
    print("Error: Could not execute Python engine.")
end

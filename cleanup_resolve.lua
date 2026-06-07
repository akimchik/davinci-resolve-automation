-- DaVinci Resolve Project Cleanup Script (Lua)
-- Deletes the projects created during this session.

local res = nil
if resolve ~= nil then
    res = resolve
elseif Resolve ~= nil then
    res = Resolve()
end

if not res then
    print("Error: Could not find 'resolve' object.")
    return
end

local project_manager = res:GetProjectManager()

-- Load a temporary empty project to "kick" the user out of the ones we want to delete
project_manager:CreateProject("Cleanup_Buffer")
project_manager:LoadProject("Cleanup_Buffer")

-- Function to safely delete
function safe_delete(name)
    local success = project_manager:DeleteProject(name)
    if success then
        print("Successfully deleted: " .. name)
    else
        print("Failed to delete: " .. name .. " (might be open or not exist).")
    end
end

-- Let's see what is actually in the folder
print("Existing projects in current folder:")
local projects = project_manager:GetProjectListInCurrentFolder()
if projects then
    for _, p_name in ipairs(projects) do
        print(" - " .. p_name)
    end
end

-- List of project names to clean up
local targets = {
    "Today_Action_Highlights",
    "Dive06.06.2026",
    "Daily_Assembled_Lua",
    "Daily_Movie_Assembled",
    "Daily_Movie",
    "Daily_Assembled_" .. os.date("%Y%m%d")
}

print("\nStarting cleanup...")
for _, name in ipairs(targets) do
    safe_delete(name)
end

print("Cleanup complete. You can now run the assembly script fresh.")

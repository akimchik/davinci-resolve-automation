-- DaVinci Resolve Project Cleanup Script (Lua)
-- Integrated with config.lua

-- 1. Load Configuration
local config_path = "/Users/lynnyk/repos/github/akimchik/davinci-resolve-automation/config.lua"
local Config = dofile(config_path)

local res = nil
if resolve ~= nil then res = resolve elseif Resolve ~= nil then res = Resolve() end
if not res then return end

local project_manager = res:GetProjectManager()

-- Load a temporary empty project to unlock others
project_manager:CreateProject("Cleanup_Buffer")
project_manager:LoadProject("Cleanup_Buffer")

local projects = project_manager:GetProjectListInCurrentFolder()
if projects then
    for _, name in ipairs(projects) do
        -- Delete everything EXCEPT the current buffer
        if name ~= "Cleanup_Buffer" then
            if project_manager:DeleteProject(name) then
                print("Deleted: " .. name)
            end
        end
    end
end

print("Cleanup complete.")

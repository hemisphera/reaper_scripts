local scriptDir = (debug.getinfo(1).source:gsub("^@", ""):match("(.*[/\\])")) or "."
package.path = package.path .. ";" .. scriptDir .. "?.lua"
local settings = require("settings")

System = {}

function System:SplitString(str, delimiter)
    local parts = {}
    for part in str:gmatch("([^" .. delimiter .. "]*)") do
        if part ~= "" then
            table.insert(parts, part)
        end
    end
    return parts
end

function System:LogDebug(msg)
    if (not settings.Debug) then return end
    reaper.ShowConsoleMsg((msg or "") .. "\n")
end

return System

local scriptDir = (debug.getinfo(1).source:gsub("^@", ""):match("(.*[/\\])")) or "."
package.path = package.path .. ";" .. scriptDir .. "?.lua"
local state = require("state")
local system = require("system")

system:LogDebug("Looper script started")
state:Initialize()
function Loop()
    if state:Tick() then
        reaper.defer(Loop)
    else
        system:LogDebug("Looper exited")
    end
end

Loop()

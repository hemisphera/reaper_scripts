local scriptDir = (debug.getinfo(1).source:gsub("^@", ""):match("(.*[/\\])")) or "."
package.path = package.path .. ";" .. scriptDir .. "?.lua"
local state = require("state")

state:Initialize()
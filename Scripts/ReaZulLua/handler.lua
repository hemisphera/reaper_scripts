local scriptDir = (debug.getinfo(1).source:gsub("^@", ""):match("(.*[/\\])")) or "."
package.path = package.path .. ";" .. scriptDir .. "?.lua"
local functions = require("functions")
local system = require("system")
local settings = require("settings")

Handler = {
    PlayState = 0
}

function Handler:OnSelectTrack(trackObject)
    if (trackObject == nil) then return end
    system:LogDebug("Selecting track " .. trackObject['name'])
    functions:SetOnlyTrackSelected(trackObject['track'])
end

function Handler:OnActiveAreaChanged(oldArea, newArea)
    if (oldArea == nil) then return end
end

function Handler:OnUpcomingAreaChanged(oldArea, newArea)
    if (newArea ~= nil) then
        functions:SetOnlyItemSelected(newArea['item'])
        if (settings.AutoSelectRecordingAreas) then
            self:OnSelectTrack(newArea['track'])
        end
    end

    if (self.PlayState == 1) and (newArea ~= nil) then
        system:LogDebug("Starting recording for " .. newArea['name'])
        functions:ToggleRecordingAtNextMeasure()
    end

    if (self.PlayState == 5) and (newArea == nil) then
        system:LogDebug("Stopping recording for " .. oldArea['name'])
        functions:ToggleRecordingAtNextMeasure()
        -- duplicate MIDI once shortly before finishing recording.
        -- ensure looping is seamless.
        -- it is copied again on finish to capture any last notes.
        if (oldArea['isMidi']) then
            self:DuplicateMidiData(oldArea)
        end
    end
end

function Handler:OnPlayStateChanged(oldState, newState)
    self.PlayState = newState
    system:LogDebug("Playstate: " .. tostring(oldState) .. " -> " .. tostring(newState))
end

function Handler:OnFinishRecording(area)
    system:LogDebug("Finished recording of " .. area['name'])
    if (area['isMidi']) then
        self:DuplicateMidiData(area)
    else
        self:DuplicateAudio(area)
    end
end

function Handler:DuplicateMidiData(area)
    system:LogDebug("Duplicating MIDI data for " .. area['name'])
    for i = 1, #area['childAreas'] do
        functions:CopyMidiItems(area['item'], area['childAreas'][i]['item'])
    end
end

function Handler:DuplicateAudio(area)
    system:LogDebug("Duplicating audio data")

    local editCursorPos = reaper.GetCursorPosition()

    functions:CropToActiveTake()
    functions:SetLoopSource()

    for i = 1, #area['childAreas'] do
        functions:CopyAudioItem(area, area['childAreas'][i])
    end

    -- restore original take name
    local take = reaper.GetActiveTake(area['item'])
    reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "record:" .. area['name'], true)

    reaper.SetEditCurPos(editCursorPos, false, false)
end

function Handler:CleanSingleArea(area)
    if (area == nil) then return end

    local trackObj = area['track']
    local track = trackObj['track']

    if (area['type'] == 'loop') then
        functions:DeleteAllMidiEvents(area['item'])
        return
    end

    if (area['type'] == 'audioloop') then
        reaper.DeleteTrackMediaItem(track, area['item'])
        return
    end

    if (area['type'] == 'record') then
        if (area['isMidi']) then
            functions:DeleteAllMidiEvents(area['item'])
        else
            local editCursorPos = reaper.GetCursorPosition()
            reaper.DeleteTrackMediaItem(track, area['item'])
            reaper.SetEditCurPos(area['start'], false, false)
            reaper.GetSet_LoopTimeRange(true, false, area['start'], area['end'], false)
            functions:SetOnlyTrackSelected(track)
            reaper.Main_OnCommand(40214, 0) -- create midi item
            area['item'] = functions:GetSelectedMediaItem()
            local take = reaper.GetActiveTake(area['item'])
            reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "record:" .. area['name'], true)
            system:LogDebug("Recreated recording area " .. area['name'])
            reaper.GetSet_LoopTimeRange(true, false, 0, 0, false)
            reaper.SetEditCurPos(editCursorPos, false, false)
        end
    end
end

return Handler

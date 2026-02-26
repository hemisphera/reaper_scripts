Functions = {}

function Functions:SetOnlyItemSelected(item)
    local titemCount = reaper.CountMediaItems(0)
    for i = 0, titemCount - 1 do
        local otherItem = reaper.GetMediaItem(0, i)
        if reaper.IsMediaItemSelected(otherItem) then
            reaper.SetMediaItemSelected(otherItem, false)
        end
    end
    reaper.SetMediaItemSelected(item, true)
end

function Functions:SetOnlyTrackSelected(track)
    reaper.SetOnlyTrackSelected(track)
end

function Functions:ToggleRecordingAtNextMeasure()
    reaper.Main_OnCommand(40003, 0)
end

function Functions:DeleteAllMidiEvents(item)
    local take = reaper.GetActiveTake(item)
    if (take == nil) then return end

    local attempts = 3
    while attempts > 0 do
        attempts = attempts - 1
        local numEvents = reaper.MIDI_CountEvts(take)
        for _ = 0, numEvents - 1 do
            reaper.MIDI_DeleteEvt(take, 0)
        end
    end
end

function Functions:CopyMidiItems(fromItem, toItem)
    local fromTake = reaper.GetActiveTake(fromItem)
    local toTake = reaper.GetActiveTake(toItem)

    if (fromTake == nil) or (toTake == nil) then return end

    local _, recordMIDI = reaper.MIDI_GetAllEvts(fromTake)
    reaper.MIDI_SetAllEvts(toTake, recordMIDI)
end

function Functions:CropToActiveTake()
    reaper.Main_OnCommand(40131, 0)
end

function Functions:SetLoopSource()
    reaper.Main_OnCommand(40547, 0)
end

function Functions:GetSelectedMediaItem()
    local numItems = reaper.CountMediaItems(0)
    for i = 0, numItems - 1 do
        local item = reaper.GetMediaItem(0, i)
        if reaper.IsMediaItemSelected(item) then
            return item
        end
    end
    return nil
end

function Functions:CopyAudioItem(fromArea, toArea)
    if (not toArea['isLoop']) then return end
    Functions:SetOnlyItemSelected(fromArea['item'])

    reaper.Main_OnCommand(40698, 0) -- Copy items
    reaper.SetEditCurPos(toArea['start'], false, false)
    reaper.Main_OnCommand(42398, 0) -- Paste items

    -- adjust length of pasted item
    local item = Functions:GetSelectedMediaItem()
    reaper.SetMediaItemInfo_Value(item, "D_LENGTH", toArea['end'] - toArea['start'])

    -- set new take name
    local newTake = reaper.GetActiveTake(item)
    reaper.GetSetMediaItemTakeInfo_String(newTake, "P_NAME", "audioloop:" .. fromArea['name'], true)
    return item
end

return Functions

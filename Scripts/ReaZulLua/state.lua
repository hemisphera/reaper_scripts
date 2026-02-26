local scriptDir = (debug.getinfo(1).source:gsub("^@", ""):match("(.*[/\\])")) or "."
package.path = package.path .. ";" .. scriptDir .. "?.lua"
local system = require("system")
local settings = require("settings")


local function GetSongContainerTrackIndex()
    local numTracks = reaper.GetNumTracks()
    for trackIdx = 0, numTracks - 1 do
        local track = reaper.GetTrack(0, trackIdx)
        local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if (name == "Songs") then
            return trackIdx
        end
    end
    return nil
end


GlobalState = {
    SongContainerTrackIndex = 0,
    PlayState = 0,
    TrackSelector = nil,
    ActiveArea = nil,
    UpcomingArea = nil,
    ActiveRecordingArea = nil,
    MinRuntime = 0,
    Region = nil,
    Tracks = nil,
    Handler = nil
}


function GlobalState:LoadTrackSelectors(region)
    local switchers = {}
    for i = 1, #region['tracks'] do
        local trackObj = region['tracks'][i]
        self:LoadTrackSelectorsForTrack(region, trackObj, switchers)
    end
    return switchers
end

function GlobalState:LoadTrackSelectorsForTrack(region, trackObj, switchers)
    local track = trackObj['track']
    local itemCount = reaper.GetTrackNumMediaItems(track)
    for i = 0, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        if (itemStart >= region['start']) and (itemStart <= region['end']) then
            local take = reaper.GetActiveTake(item)
            if (take ~= nil) then
                local _, takeName = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                if (takeName == 'select') then
                    local switcher = {}
                    switcher['start'] = itemStart
                    switcher['trackObj'] = trackObj
                    table.insert(switchers, switcher)
                end
            end
        end
    end
end

function GlobalState:LoadChildAreas(region, trackObj, name)
    local track = trackObj['track']
    local loopAreas = {}
    local itemCount = reaper.GetTrackNumMediaItems(track)
    for i = 0, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        if (itemStart >= region['start']) and (itemStart <= region['end']) then
            local take = reaper.GetActiveTake(item)
            local _, item_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            local parts = system:SplitString(item_name, ':')
            local isChildArea = parts[1] == 'loop' or parts[1] == 'audioloop'
            if (isChildArea) and (parts[2] == name) then
                local loopArea = {}
                loopArea['name'] = parts[2]
                loopArea['start'] = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                loopArea['end'] = loopArea['start'] + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                loopArea['track'] = trackObj
                loopArea['type'] = string.lower(parts[1])
                loopArea['item'] = item
                loopArea['isLoop'] = parts[1] == 'loop'
                table.insert(loopAreas, loopArea)
            end
        end
    end
    return loopAreas
end

function GlobalState:LoadRecordingAreasForTrack(region, trackObj, areas)
    local track = trackObj['track']
    local itemCount = reaper.GetTrackNumMediaItems(track)
    for i = 0, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        if (itemStart >= region['start']) and (itemStart <= region['end']) then
            local itemEnd = itemStart + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local take = reaper.GetActiveTake(item)
            if (take ~= nil) then
                local _, item_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                local parts = system:SplitString(item_name, ':')
                if (parts[1] == 'record') then
                    local recordArea = {}
                    recordArea['name'] = parts[2]
                    recordArea['start'] = itemStart
                    recordArea['end'] = itemEnd
                    recordArea['track'] = trackObj
                    recordArea['item'] = item
                    recordArea['type'] = string.lower(parts[1])
                    recordArea['childAreas'] = self:LoadChildAreas(region, trackObj, recordArea['name'])
                    recordArea['isMidi'] = reaper.GetMediaTrackInfo_Value(track, 'I_RECMODE') >= 7
                    table.insert(areas, recordArea)
                    system:LogDebug("Loaded area " .. parts[2])
                end
            end
        end
    end
end

function GlobalState:LoadRegionTracks(regionName)
    local parentIdx = self.SongContainerTrackIndex
    local numTracks = reaper.GetNumTracks()
    local result = {}
    local currDepth = 0
    local isInRegion = false
    local parentItem = nil
    for trackIdx = parentIdx + 1, numTracks - 1 do
        local track = reaper.GetTrack(0, trackIdx)
        local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        local depthChange = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        local item = {}

        if (currDepth == 0) then
            isInRegion = name == regionName
        end

        if (isInRegion) then
            item['name'] = name
            item['parent'] = parentItem
            item['index'] = trackIdx
            item['track'] = track
            item['activeItem'] = nil
            table.insert(result, item)

            system:LogDebug("Loaded track " .. name);
            if (depthChange > 0) then
                parentItem = item
            end
            if (depthChange < 0) then
                for _ = 1, -depthChange do
                    if (parentItem ~= nil) then
                        parentItem = parentItem['parent']
                    end
                end
            end
        end
        currDepth = currDepth + depthChange
        if (currDepth < 0) then break end
    end
    return result
end

function GlobalState:LoadRecordingAreas(region)
    local areas = {}
    for i = 1, #region['tracks'] do
        local trackObj = region['tracks'][i]
        system:LogDebug("Loading areas from track " .. tostring(trackObj['name']))
        self:LoadRecordingAreasForTrack(region, trackObj, areas)
    end
    return areas
end

function GlobalState:LoadRegion(regionIdx, full)
    if (full == nil) then full = true end
    if (regionIdx == nil) then return nil end

    local _, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers3(0, regionIdx)
    if ((not isrgn) or (markrgnindexnumber < 0)) then
        return nil
    end

    local result = {}
    result['index'] = regionIdx
    result['name'] = name
    result['start'] = pos
    result['end'] = rgnend
    if (full) then
        result['tracks'] = self:LoadRegionTracks(name)
        system:LogDebug("Loaded " .. tostring(#result['tracks']) .. " tracks")
        result['areas'] = self:LoadRecordingAreas(result)
        system:LogDebug("Loaded " .. tostring(#result['areas']) .. " areas")
        result['switchers'] = self:LoadTrackSelectors(result)
        system:LogDebug("Loaded " .. tostring(#result['switchers']) .. " selectors")
    end
    return result
end

function GlobalState:EnumerateRegions()
    local regions = {}
    local numMarkers = reaper.CountProjectMarkers(0)
    for i = 0, numMarkers - 1 do
        local region = self:LoadRegion(i, false)
        if (region ~= nil) then
            system:LogDebug("Detected region " .. region['name'])
            table.insert(regions, region)
        end
    end
    return regions
end

function GlobalState:GetCurrentRegion()
    local regions = self:EnumerateRegions()
    local pos = self:GetPosition()
    local _, regionIdx = reaper.GetLastMarkerAndCurRegion(0, pos)
    return self:LoadRegion(regionIdx, true)
    --[[
    local pos = self:GetPosition()
    local _, regionIdx = reaper.GetLastMarkerAndCurRegion(0, pos)
    for i = 1, #regions do
        if (regions[i]['index'] == regionIdx) then
            return regions[i]
        end
    end
    return nil
    ]]
end

function GlobalState:GetLastTrackSelector()
    local result = nil
    for i = 1, #self.Region['switchers'] do
        local switcher = self.Region['switchers'][i]
        if (switcher['start'] <= self:GetPosition()) then
            if (result == nil) or (switcher['start'] > result['start']) then
                result = switcher
            end
        end
    end
    return result
end

function GlobalState:HandleTrackSelector()
    local selector = self:GetLastTrackSelector()
    if (selector ~= self.TrackSelector) then
        self.TrackSelector = selector
        if (selector ~= nil) then
            self.Handler:OnSelectTrack(selector['trackObj'])
        end
    end
end

function GlobalState:GetActiveArea(playpos)
    if (self.Region == nil) then return nil end
    for i = 1, #self.Region['areas'] do
        local area = self.Region['areas'][i]
        local isAreaActive = (playpos >= area['start']) and (playpos <= area['end'])
        if (isAreaActive) then
            return area
        end
    end
    return nil
end

function GlobalState:UpdateAreas()
    if (self.Region == nil) then return end
    local pos = self:GetPosition()
    local bpm = reaper.TimeMap2_GetDividedBpmAtTime(0, pos)
    local lookahead = 60.0 / bpm * settings.LookaheadBeats

    self:SetActiveArea('upcoming', self:GetActiveArea(pos + lookahead))
    self:SetActiveArea('active', self:GetActiveArea(pos))
end

function GlobalState:SetActiveArea(type, area)
    if (type == 'active') then
        if (self.ActiveArea ~= area) then
            local sourceName = tostring(self.ActiveArea ~= nil and self.ActiveArea['name'] or "none")
            local targetName = tostring(area ~= nil and area['name'] or "none")
            system:LogDebug("Active area: " .. sourceName .. " -> " .. targetName)
            self.Handler:OnActiveAreaChanged(self.ActiveArea, area)
            self.ActiveArea = area
        end
    end
    if (type == 'upcoming') then
        if (self.UpcomingArea ~= area) then
            local sourceName = tostring(self.ActiveArea ~= nil and self.ActiveArea['name'] or "none")
            local targetName = tostring(area ~= nil and area['name'] or "none")
            system:LogDebug("Upcoming area: " .. sourceName .. " -> " .. targetName)
            self.Handler:OnUpcomingAreaChanged(self.ActiveArea, area)
            self.UpcomingArea = area
        end
    end
end

function GlobalState:GetPosition()
    local pos = reaper.GetCursorPosition()
    local playState = reaper.GetPlayState()
    local isPlaying = playState & 1 == 1
    if (isPlaying) then
        pos = reaper.GetPlayPosition()
    end
    return pos
end

function GlobalState:Initialize(skipClean)
    self.SongContainerTrackIndex = GetSongContainerTrackIndex()
    self.PlayState = 0
    self.TrackSelector = nil
    self.ActiveArea = nil
    self.RecordingArea = nil
    self.UpcomingArea = nil
    self.MinRuntime = os.time() + 5
    self.Region = self:GetCurrentRegion()
    self.Handler = require("handler")

    if (not skipClean) then
        self:CleanAreas(self.Region['areas'], self:GetPosition())
    end

    system:LogDebug("Loaded region " .. self.Region['name'])
end

function GlobalState:CleanAreas(areas, pos)
    if (areas == nil) then return end
    for i = 1, #areas do
        local area = areas[i]
        if (area['start'] > pos) then
            self.Handler:CleanSingleArea(area)
            self:CleanAreas(area['childAreas'], pos)
        end
    end
end

function GlobalState:UpdateTracksState()
    if (self.Region == nil) then return end
    local regionName = self.Region['name']

    local parentIdx = self.SongContainerTrackIndex
    local numTracks = reaper.GetNumTracks()
    local isInRegion = false
    local currDepth = 0

    for trackIdx = parentIdx + 1, numTracks - 1 do
        local track = reaper.GetTrack(0, trackIdx)
        local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        local depthChange = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        if (currDepth == 0) then
            isInRegion = name == regionName
        end

        if (isInRegion) then
            reaper.SetMediaTrackInfo_Value(track, "B_MUTE", 0.0)
            reaper.SetMediaTrackInfo_Value(track, "I_FXEN", 1.0)
            reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1.0)
        else
            reaper.SetMediaTrackInfo_Value(track, "B_MUTE", 1.0)
            reaper.SetMediaTrackInfo_Value(track, "I_FXEN", 0.0)
            reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0.0)
        end
        currDepth = currDepth + depthChange
        if (currDepth < 0) then break end
    end
    reaper.TrackList_AdjustWindows(false)
end

function GlobalState:FocusRegion()
    reaper.GetSet_LoopTimeRange(true, false, self.Region['start'], self.Region['end'], false)
    reaper.Main_OnCommand(40031, 0) -- zoom to time selection
    reaper.GetSet_LoopTimeRange(true, false, 0, 0, false)
    reaper.SetEditCurPos(self.Region['start'], false, false)
end

function GlobalState:Tick()
    if (self.Region == nil) then return false end
    local playpos = self:GetPosition()

    local newPlayState = reaper.GetPlayState()
    if (newPlayState ~= self.PlayState) then
        local oldPlayState = self.PlayState
        self.Handler:OnPlayStateChanged(self.PlayState, newPlayState)
        self.PlayState = newPlayState

        if (newPlayState == 5) and (oldPlayState == 1) then
            system:LogDebug("Now recording area " .. self.UpcomingArea['name'])
            self.RecordingArea = self.UpcomingArea
        end

        if (oldPlayState == 5) and (newPlayState == 1) and (self.RecordingArea ~= nil) then
            system:LogDebug("Finishing recording of area " .. self.RecordingArea['name'])
            self.Handler:OnFinishRecording(self.RecordingArea)
            self.RecordingArea = nil
        end
    end

    if (playpos >= self.Region['end']) and (self.PlayState > 0) then
        reaper.Main_OnCommand(40328, 0)
        return false
    end

    self:UpdateAreas()
    self:HandleTrackSelector()

    return
        (os.time() < self.MinRuntime) or
        (self.PlayState > 0)
end

return GlobalState

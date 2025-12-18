function MuteFXBlock()

  local selectedTrack = reaper.GetSelectedTrack(0, 0)
  local selectedTrackNumber = reaper.GetMediaTrackInfo_Value(selectedTrack, 'IP_TRACKNUMBER')
   
  if ((selectedTrackNumber <= 19) and (selectedTrackNumber >= 10)) then
    trackStart = 10
  end
  
  if ((selectedTrackNumber <= 29) and (selectedTrackNumber >= 20)) then
    trackStart = 20
  end

  local trackEnd = trackStart + 10
  for i = trackStart, trackEnd - 1 do
    local track = reaper.GetTrack(0, i - 1)
    
    local peak0 = reaper.Track_GetPeakInfo(track, 0)
    local peak1 = reaper.Track_GetPeakInfo(track, 1)
    local isIdle = (peak0 <= 0.1) and (peak1 <= 0.1)
    if (isIdle) then
      reaper.SetMediaTrackInfo_Value(track, 'B_MUTE', 1)
    end

    local _, name = reaper.GetTrackName(track)
    local isArmed = reaper.GetMediaTrackInfo_Value(track, 'I_RECARM') == 1.0
    if (isArmed) then
      reaper.SetMediaTrackInfo_Value(track, 'I_RECARM', 0.0)
    end
  end
  local track = reaper.GetSelectedTrack(0, 0)
  reaper.SetMediaTrackInfo_Value(track, 'I_RECARM', 1.0)
  reaper.SetMediaTrackInfo_Value(track, 'B_MUTE', 0)
end

MuteFXBlock();
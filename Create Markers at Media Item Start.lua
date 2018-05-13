-- remove all existing markers
rv, markerCount = reaper.CountProjectMarkers(0)
for i = 0, markerCount - 1, 1 do
  reaper.DeleteProjectMarker(0, i, false)
end;

-- insert new markers
selectedTrackCount = reaper.CountSelectedTracks(0)
for i = 0, selectedTrackCount - 1, 1 do
  track = reaper.GetSelectedTrack(0, i)
  ok, trackName = reaper.GetTrackName(track, "")
  mediaItemCount = reaper.GetTrackNumMediaItems(track)
  for j = 0, mediaItemCount - 1, 1 do
    mediaItem = reaper.GetTrackMediaItem(track, j)
    take = reaper.GetActiveTake(mediaItem)
    source = reaper.GetMediaItemTake_Source(take)
    pos = reaper.GetMediaItemInfo_Value(mediaItem, "D_POSITION")
    filename = reaper.GetMediaSourceFileName(source, "")
    filename = filename:match(".*\\(.-)%.+")
    mediaItemType = reaper.GetMediaSourceType(source, "")
    --if mediaItemType ~= "MIDI" then
      reaper.AddProjectMarker(0, false, pos, 0, filename, -1)
    --end
  end
end;


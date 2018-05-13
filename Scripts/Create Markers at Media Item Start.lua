-- remove all existing markers
-- A repeat loop seems to be required here because all markers are only correctly removed
-- after a second iteration
repeat
	rv, markerCount = reaper.CountProjectMarkers(0)
	if (markerCount ~= 0) then
		for i = 0, markerCount - 1, 1 do
			reaper.DeleteProjectMarkerByIndex(0, i, false)
			reaper.ShowConsoleMsg(string.format("Marker index %s removed\n", i + 1))
		end
	end
until markerCount == 0

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
		mediaItemType = reaper.GetMediaSourceType(source, "")
		if (mediaItemType ~= nil) then
			pos = reaper.GetMediaItemInfo_Value(mediaItem, "D_POSITION")
			filename = reaper.GetMediaSourceFileName(source, "")
			filename = filename:match(".*\\(.-)%.+")
			reaper.AddProjectMarker(0, false, pos, 0, filename, -1)
		end
	end
end;

-- count current markers and show a message box
rv, markerCount = reaper.CountProjectMarkers(0)
reaper.ShowMessageBox(string.format("%s markers added.", markerCount), "Message", 0)
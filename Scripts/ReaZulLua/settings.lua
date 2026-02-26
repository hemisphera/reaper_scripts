Settings = {}

-- Debug mode enabled? (true/false)
-- When enabled, debug information will be written to REAPERs console.
Settings.Debug = false

-- Number of beats to look ahead for upcoming recording start/stop triggers
-- Defaults to 1 beat. Should not result in more than a measure, as it will interfere with start/stop timing actions.
-- Calculated based on the project tempo.
Settings.LookaheadBeats = 1

-- Will cause recordindg areas to automatically trigger its track to be selected without requiring a dedicated track selector.
Settings.AutoSelectRecordingAreas = true

return Settings

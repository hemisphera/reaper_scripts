local WINDOW_TITLE = "Selected Track Parameters"
local WINDOW_W = 900
local WINDOW_H = 420
local AUTO_DOCK_LEFT_OF_TCP = true
local MAX_PARAMS = 8
local MAX_ACTIVE_ENVELOPES_PER_TRACK = 8
local REFRESH_INTERVAL = 0.10

local params = {}
local last_refresh = 0

local function get_left_docker_index()
	for docker_idx = 0, 15 do
		if reaper.DockGetPosition(docker_idx) == 1 then
			return docker_idx
		end
	end
	return nil
end

local function dock_window_left_of_tcp()
	if not AUTO_DOCK_LEFT_OF_TCP then
		return
	end

	local left_docker_idx = get_left_docker_index()
	if left_docker_idx == nil then
		return
	end

	local target_dock_state = 1 + left_docker_idx * 256
	local current_dock_state = gfx.dock(-1)

	if current_dock_state ~= target_dock_state then
		gfx.dock(target_dock_state)
	end
end

local function clamp01(value)
	if value < 0 then
		return 0
	end
	if value > 1 then
		return 1
	end
	return value
end

local function normalize(value, minval, maxval)
	if maxval <= minval then
		return 0
	end
	return clamp01((value - minval) / (maxval - minval))
end

local function get_track_name(track)
	local _, name = reaper.GetTrackName(track, "")
	if name == "" then
		return "(Unnamed Track)"
	end
	return name
end

local function get_selected_track_title()
	local selected_tracks = reaper.CountSelectedTracks(0)
	if selected_tracks == 0 then
		return "No track selected"
	end

	local first_track = reaper.GetSelectedTrack(0, 0)
	local first_name = get_track_name(first_track)

	if selected_tracks == 1 then
		return first_name
	end

	return string.format("%s (+%d)", first_name, selected_tracks - 1)
end

local function get_param_alias(track, fx_idx, param_idx)
	local ok, aliased_name = reaper.TrackFX_GetNamedConfigParm(track, fx_idx, string.format("param.%d.aliased_name", param_idx))
	if ok and aliased_name ~= "" then
		return aliased_name
	end

	ok, aliased_name = reaper.TrackFX_GetNamedConfigParm(track, fx_idx, string.format("param.%d.container_map.aliased_name", param_idx))
	if ok and aliased_name ~= "" then
		return aliased_name
	end

	local _, param_name = reaper.TrackFX_GetParamName(track, fx_idx, param_idx, "")
	if param_name == "" then
		param_name = "(Unnamed Parameter)"
	end
	return param_name
end

local function get_envelope_name(env)
	local _, name = reaper.GetEnvelopeName(env, "")
	if name == "" then
		return "(Unnamed Envelope)"
	end
	return name
end

local function is_envelope_active(env)
	local _, active = reaper.GetSetEnvelopeInfo_String(env, "ACTIVE", "", false)
	return active == "1"
end

local function collect_active_envelopes(limit)
	local results = {}
	local selected_tracks = reaper.CountSelectedTracks(0)

	for track_index = 0, selected_tracks - 1 do
		local track = reaper.GetSelectedTrack(0, track_index)
		if track ~= nil then
			local env_count = reaper.CountTrackEnvelopes(track)
			local per_track_count = 0

			for env_idx = 0, env_count - 1 do
				if per_track_count >= MAX_ACTIVE_ENVELOPES_PER_TRACK then
					break
				end

				local env = reaper.GetTrackEnvelope(track, env_idx)
				if env ~= nil and is_envelope_active(env) then
					local _, fx_idx, param_idx = reaper.Envelope_GetParentTrack(env)
					local label = get_envelope_name(env)
					local norm = 0

					if fx_idx >= 0 and param_idx >= 0 and reaper.TrackFX_GetEnabled(track, fx_idx) then
						local value, minval, maxval = reaper.TrackFX_GetParam(track, fx_idx, param_idx)
						label = get_param_alias(track, fx_idx, param_idx)
						norm = normalize(value, minval, maxval)
					else
						local _, value = reaper.Envelope_Evaluate(env, reaper.GetCursorPosition(), 0, 0)
						norm = clamp01(value)
					end

					results[#results + 1] = {
						label = label,
						norm = norm
					}

					per_track_count = per_track_count + 1

					if #results >= limit then
						return results
					end
				end
			end
		end
	end

	return results
end

local function draw_text(x, y, r, g, b, a, text)
	gfx.set(r, g, b, a)
	gfx.x = x
	gfx.y = y
	gfx.drawstr(text)
end

local function draw_gauge(x, y, w, h, value_norm)
	local fill_w = math.floor(w * clamp01(value_norm))

	gfx.set(0.20, 0.20, 0.22, 1)
	gfx.rect(x, y, w, h, true)

	if fill_w > 0 then
		gfx.set(0.25, 0.70, 0.95, 1)
		gfx.rect(x, y, fill_w, h, true)
	end

	gfx.set(0.05, 0.05, 0.05, 1)
	gfx.rect(x, y, w, h, false)
end

local function draw_ui()
	gfx.set(0.10, 0.10, 0.11, 1)
	gfx.rect(0, 0, gfx.w, gfx.h, true)

	local title = get_selected_track_title()
	gfx.setfont(1, "Arial", 24)
	local title_w, title_h = gfx.measurestr(title)
	draw_text((gfx.w - title_w) * 0.5, 12, 0.95, 0.95, 0.95, 1, title)

	gfx.setfont(1, "Arial", 20)

	if #params == 0 then
		draw_text(16, 16 + title_h + 12, 0.90, 0.80, 0.50, 1, "No active envelopes.")
		return
	end

	local top = 52
	local row_h = 46
	local left = 16
	local gauge_x = left
	local gauge_w = gfx.w - 32
	local gauge_h = 34

	for i = 1, #params do
		local p = params[i]
		local y = top + (i - 1) * row_h

		draw_gauge(gauge_x, y, gauge_w, gauge_h, p.norm)
		local text_w, text_h = gfx.measurestr(p.label)
		local tx = gauge_x + (gauge_w - text_w) * 0.5
		local ty = y + (gauge_h - text_h) * 0.5
		draw_text(tx, ty, 0.98, 0.98, 0.98, 1, p.label)
	end
end

local function refresh_params_if_needed(force)
	local now = reaper.time_precise()
	if force or (now - last_refresh) >= REFRESH_INTERVAL then
		params = collect_active_envelopes(MAX_PARAMS)
		last_refresh = now
	end
end

local function run()
	if gfx.getchar() < 0 then
		return
	end

	refresh_params_if_needed(false)
	draw_ui()
	reaper.defer(run)
end

gfx.init(WINDOW_TITLE, WINDOW_W, WINDOW_H)
dock_window_left_of_tcp()
refresh_params_if_needed(true)
run()

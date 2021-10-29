-- This script is a part of 'RJS Sampling Suite' designed to automate tasks related to sample instrument creation.
-- Running the script returns "vertically" arranged items back onto the first track and removes the tracks created for the "vertical view".
--
-- Copyright (C) 2021 Risto Sipola
-- 'RJS Sampling Suite' script collection is licensed under the GNU General Public License v3.0: See LICENSE.txt
--
-- How to use:
--            1. Run the script.
--            2. The items are returned to their original places on the first track.
--
-- author: Risto Sipola

function take_position_info(item)
	local retval, notes = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
	local position
	if notes ~= nil and notes ~= "" then
		local original_notes = notes
		local sub_strings = {}
		local sub_strings_idx = 0
		local comma_idx = 0
		local digit_counter = 0
		
		while comma_idx ~= nil do
			comma_idx = string.find(notes, ",", 1) 
			if comma_idx ~= nil then
				sub_strings_idx = sub_strings_idx + 1
				sub_strings[sub_strings_idx] = string.sub(notes, 1, comma_idx)  
				notes = string.gsub(notes, sub_strings[sub_strings_idx], "")			
			else
				if notes ~= nil then
					sub_strings_idx = sub_strings_idx + 1
					sub_strings[sub_strings_idx] = notes
				end
			end
		end
		local identifier_found = false
		for i = 1, sub_strings_idx, 1 do
			for word in string.gmatch(sub_strings[i], "%a+") do 
				if string.find(word, "position") ~= nil then
					identifier_found = true
					break;
				end
			end
			if identifier_found then
				-- read the position
				for word in string.gmatch(sub_strings[i], "%d+") do 
					position = tonumber(word) / 100000.0
				end
				-- erase position info from the notes
				local comma_i = string.find(sub_strings[i], ",", 1)
				if comma_i ~= nil and comma_i ~= 1 then
					notes = string.gsub(original_notes, sub_strings[i], "")
				elseif comma_i ~= nil and comma_i == 1 then
					notes = string.gsub(original_notes, sub_strings[i], "")
				else
					notes = string.gsub(original_notes, sub_strings[i], "")
				end
				-- comma
				local last_char = string.sub(notes, -1)
				if last_char == "," then
					local rev = string.reverse(notes)
					rev = string.sub(rev, 2)					
					notes = string.reverse(rev)
				end
				break
			end
		end
		if not identifier_found then
			notes = original_notes..""
		end
		reaper.GetSetMediaItemInfo_String(item, "P_NOTES", notes, true)
	end
	return position
end

function move_back_to_original_track(item)

	local position = take_position_info(item)
	if position ~= nil and position >= 0.0 then
		reaper.MoveMediaItemToTrack(item, reaper.GetTrack(0, 0))
		reaper.SetMediaItemPosition(item, position, false)
	end
end

function main()
	local track_count = reaper.GetNumTracks()
	local loop_count = 0
	local ignore_count = 0
	
	if track_count > 0 then
		reaper.Undo_BeginBlock()
		while track_count > 0 and loop_count < 1000 do
			local track = reaper.GetTrack(0, track_count - 1)
			local retval, tr_name = reaper.GetTrackName(track)
			if tr_name == "Vertical View" then
				local item_count = reaper.CountTrackMediaItems(track)
				if item_count > 0 then
					local item = reaper.GetTrackMediaItem(track, 0) 
					move_back_to_original_track(item)
					item_count = reaper.CountTrackMediaItems(track)
					if item_count == 0 then
						reaper.DeleteTrack(track)
					else
						ignore_count = ignore_count + 1
					end
				end
			else
				ignore_count = ignore_count + 1
			end
			loop_count = loop_count + 1
			track_count = reaper.GetNumTracks() - ignore_count
		end
		-- delete markers
		local marker_code = 2000
		reaper.DeleteProjectMarker(0, marker_code + 0, false)
		reaper.DeleteProjectMarker(0, marker_code + 1, false)
		reaper.DeleteProjectMarker(0, marker_code + 2, false)
		reaper.DeleteProjectMarker(0, marker_code + 3, false)
		reaper.DeleteProjectMarker(0, marker_code + 4, false)
		-- auto-zoom
		track_count = reaper.GetNumTracks()
		local zoom
		for i = 0, track_count - 1, 1 do
			local track = reaper.GetTrack(0, i)
			local retval, tr_name = reaper.GetTrackName(track)
			if string.find(tr_name, "zoom") ~= nil then
				for word in string.gmatch(tr_name, "%d+") do 
					zoom = tonumber(word) / 100000.0
				end
				reaper.DeleteTrack(track)
				break;
			end
		end
		if zoom ~= nil then
			local current_zoom_level = reaper.GetHZoomLevel() -- seconds visible
			local target_zoom = zoom
			if current_zoom_level < target_zoom then
				while current_zoom_level < target_zoom do
					reaper.adjustZoom(2, 0, true, -1)
					current_zoom_level = reaper.GetHZoomLevel()
				end
				while current_zoom_level > target_zoom do
					reaper.adjustZoom(-0.15, 0, true, -1)
					current_zoom_level = reaper.GetHZoomLevel()
				end
				while current_zoom_level < target_zoom do
					reaper.adjustZoom(0.01, 0, true, -1)
					current_zoom_level = reaper.GetHZoomLevel()
				end
			else
			while current_zoom_level > target_zoom do
					reaper.adjustZoom(-2, 0, true, -1)
					current_zoom_level = reaper.GetHZoomLevel()
				end
				while current_zoom_level < target_zoom do
					reaper.adjustZoom(0.15, 0, true, -1)
					current_zoom_level = reaper.GetHZoomLevel()
				end
				while current_zoom_level > target_zoom do
					reaper.adjustZoom(-0.01, 0, true, -1)
					current_zoom_level = reaper.GetHZoomLevel()
				end
			end
		end
		--
		reaper.UpdateArrange()
		reaper.Undo_EndBlock("Exit Vertical View", 0)
	end
end

main()
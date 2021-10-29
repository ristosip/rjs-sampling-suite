-- This script is a part of 'RJS Sampling Suite' designed to automate tasks related to sample instrument creation.
-- Running the script arranges the items on the first track onto separate tracks where the timing differences of the items can be observed.
--
-- Copyright (C) 2021 Risto Sipola
-- 'RJS Sampling Suite' script collection is licensed under the GNU General Public License v3.0: See LICENSE.txt
--
-- How to use:
--            1. Run the script.
--            2. The items are now arranged vertically.
--
-- Purposes of the "vertical view":
--                                - To observe the differences between the start times of the samples.
--                                - To make it possible to apply an action to all of the items/samples at the same time. For example: Setting loop points (using DS Instrument Builder Kit). 
--
-- author: Risto Sipola

-- Default Settings--
---------------------
default_position = 10.0 -- position of the items in seconds
default_want_grid_markers = true
default_grid_marker1_pos = 0.001
default_grid_marker2_pos = 0.003
default_grid_marker3_pos = 0.005
default_grid_marker4_pos = 0.010

default_want_auto_zoom = true
default_auto_zoom = 10 -- pixels per millisecond

---------------------
---------------------

function replace_notes_pos_info(notes, new_pos_info)
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
			local comma_i = string.find(sub_strings[i], ",", 1)
			if comma_i ~= nil and comma_i ~= 1 then
				notes = string.gsub(original_notes, sub_strings[i], new_pos_info..",")
			elseif comma_i ~= nil and comma_i == 1 then
				notes = string.gsub(original_notes, sub_strings[i], ","..new_pos_info)
			else
				notes = string.gsub(original_notes, sub_strings[i], new_pos_info)
			end
			break
		end
	end
	if not identifier_found then
		notes = original_notes..","..new_pos_info
	end
		
	return notes
end

function move_item_to_new_track(item)
	local item_pos = math.floor(reaper.GetMediaItemInfo_Value(item, "D_POSITION") * 100000)
	local retval, item_notes = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
	local new_notes = ""
	local pos_info = " position "..item_pos
	if item_notes ~= nil and item_notes ~= "" then
		new_notes = replace_notes_pos_info(item_notes, pos_info)
	else
		new_notes = pos_info			
	end
	reaper.GetSetMediaItemInfo_String(item, "P_NOTES", new_notes, true)
	
	reaper.InsertTrackAtIndex(reaper.GetNumTracks(), false)
	local new_track = reaper.GetTrack(0, reaper.GetNumTracks() - 1)
	reaper.GetSetMediaTrackInfo_String(new_track, "P_NAME", "Vertical View", true)
	
	reaper.MoveMediaItemToTrack(item, new_track)
	reaper.SetMediaItemPosition(item, default_position, false)
end

function main()
	local track = reaper.GetTrack(0, 0)
	local item_count = reaper.CountTrackMediaItems(track)
	local loop_count = 0
	
	if item_count > 0 then	
		reaper.Undo_BeginBlock()
		while item_count > 0 and loop_count < 1000 do			
			local item = reaper.GetTrackMediaItem(track, 0)
			if item ~= nil then
				move_item_to_new_track(item)
			end
			item_count = reaper.CountTrackMediaItems(track)
			loop_count = loop_count + 1
		end
		if default_want_grid_markers then
			--markers
			local marker_code = 2000
			reaper.AddProjectMarker(0, false, default_position, 0, "", marker_code + 0)
			reaper.AddProjectMarker(0, false, default_position + default_grid_marker1_pos, 0, "", marker_code + 1)
			reaper.AddProjectMarker(0, false, default_position + default_grid_marker2_pos, 0, "", marker_code + 2)
			reaper.AddProjectMarker(0, false, default_position + default_grid_marker3_pos, 0, "", marker_code + 3)
			reaper.AddProjectMarker(0, false, default_position + default_grid_marker4_pos, 0, "", marker_code + 4)
		end
		if default_want_auto_zoom then
			reaper.SetEditCurPos(default_position, true, false)
			local current_zoom_level = reaper.GetHZoomLevel() -- seconds visible
			-- store current zoom
			reaper.InsertTrackAtIndex(reaper.GetNumTracks(), false)
			local new_track = reaper.GetTrack(0, reaper.GetNumTracks() - 1)
			reaper.GetSetMediaTrackInfo_String(new_track, "P_NAME", "zoom "..math.floor(current_zoom_level * 100000.0), true)
			--
			local target_zoom = default_auto_zoom * 1000
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
		reaper.UpdateArrange()
		reaper.Undo_EndBlock("Enter Vertical View", 0)
	end	
end

main()
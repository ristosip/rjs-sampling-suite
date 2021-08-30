-- This script is a part of 'RJS Sampling Suite' designed to automate tasks related to sample instrument creation.
-- Running the script updates the midi note labelling of the samples.
--
-- Copyright (C) 2021 Risto Sipola
-- 'RJS Sampling Suite' script collection is licensed under the GNU General Public License v3.0: See LICENSE.txt
--
-- author: Risto Sipola

function update_group_member_items(item, note)
	local item_count = reaper.CountTrackMediaItems(reaper.GetMediaItem_Track(item))
	local group_id = reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
	
	if group_id ~= 0 then
		for i = reaper.CountMediaItems(0) - 1, 0, -1 do
			local temp_item = reaper.GetMediaItem(0, i)
			local temp_id = reaper.GetMediaItemInfo_Value(temp_item, "I_GROUPID")
			if temp_id == group_id and temp_item ~= item then
				reaper.SetMediaItemInfo_Value(temp_item, "I_CUSTOMCOLOR", reaper.ColorToNative(note, math.abs(math.floor((255 - (note%12)/12 * 255))),math.floor((note%12)/12 * 255/2))|0x1000000)
				reaper.UpdateArrange()
			end			
		end		
	end	
end

function update_sample_info()

	local num_tracks = reaper.CountTracks(0)
	if num_tracks > 1 then
		local sample_track = reaper.GetTrack(0, 0)
		local track
		local tuning_tr_found = false
		
		for i = 1, num_tracks - 1, 1 do
			
			track = reaper.GetTrack(0, i)
			local retval, tr_name = reaper.GetTrackName(track)
			
			if tr_name == "Tuning Aid" then
				tuning_tr_found = true
				break;
			end	
		end
	
		if tuning_tr_found == true then

			local num_samples = reaper.CountTrackMediaItems(sample_track)
			local num_midi_items = reaper.CountTrackMediaItems(track)
			
			for i = 0, num_samples - 1, 1 do
				local sample = reaper.GetTrackMediaItem(sample_track, i)
				local sample_pos = reaper.GetMediaItemInfo_Value(sample, "D_POSITION")
				local sample_len = reaper.GetMediaItemInfo_Value(sample, "D_LENGTH")
				local midi_item_match
				for j = 0, num_midi_items, 1 do
					local temp_item = reaper.GetTrackMediaItem(track, j)
					local temp_pos = reaper.GetMediaItemInfo_Value(temp_item, "D_POSITION")
					local temp_len = reaper.GetMediaItemInfo_Value(temp_item, "D_LENGTH")
					if temp_pos < (sample_pos + sample_len) and (temp_pos + temp_len) > sample_pos then
						midi_item_match = temp_item
						break;
					end
				end
				if midi_item_match ~= nil then
					r, g, b = reaper.ColorFromNative(reaper.GetMediaItemInfo_Value(sample, 'I_CUSTOMCOLOR'))
					local note_value = r
					local retval, s, m, st, en, ch, pitch, vel = reaper.MIDI_GetNote(reaper.GetTake(midi_item_match, 0), 0)
					local midi_note = pitch

					if midi_note ~= note_value then
						reaper.SetMediaItemInfo_Value(sample, "I_CUSTOMCOLOR", reaper.ColorToNative(midi_note, math.abs(math.floor((255 - (midi_note%12)/12 * 255))),math.floor((midi_note%12)/12 * 255/2))|0x1000000)
						reaper.UpdateArrange()
						update_group_member_items(sample, midi_note)
					end	
				end
			end
		end
	end
end

update_sample_info()

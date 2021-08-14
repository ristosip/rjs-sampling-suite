-- This script is a part of 'Sampling Suite' designed to automate tasks related to sample instrument creation.
-- Running the script changes the pitch of the selected samples by 1 cent.
-- author: Risto Sipola

function update_group_member_items(item, pitch)
	local item_count = reaper.CountTrackMediaItems(reaper.GetMediaItem_Track(item))
	local group_id = reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
	
	if group_id ~= 0 then
		for i = reaper.CountMediaItems(0) - 1, 0, -1 do
			local temp_item = reaper.GetMediaItem(0, i)
			local temp_id = reaper.GetMediaItemInfo_Value(temp_item, "I_GROUPID")
			if temp_id == group_id and temp_item ~= item then
				reaper.SetMediaItemTakeInfo_Value(reaper.GetTake(temp_item, 0), "D_PITCH", pitch)
				reaper.UpdateItemInProject(temp_item)
			end			
		end		
	end	
end

function tune_selected_samples_down(cents)
	
	local pitch_shift = -1 * cents / 100
	local num_tracks = reaper.CountTracks(0)
	if num_tracks > 0 then
		local sample_track = reaper.GetTrack(0, 0)
		local num_samples = reaper.CountTrackMediaItems(sample_track)
			
		for i = 0, num_samples - 1, 1 do
			local sample = reaper.GetTrackMediaItem(sample_track, i)
			if reaper.IsMediaItemSelected(sample) then
				local current_value = reaper.GetMediaItemTakeInfo_Value(reaper.GetTake(sample, 0), "D_PITCH")
				reaper.SetMediaItemTakeInfo_Value(reaper.GetTake(sample, 0), "D_PITCH", current_value + pitch_shift)
				reaper.UpdateItemInProject(sample)	
				update_group_member_items(sample, current_value + pitch_shift)				
			end
		end
	end
end

function main()
	tune_selected_samples_down(1)
end

main()
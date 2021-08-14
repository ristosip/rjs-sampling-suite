-- This script is a part of 'Sampling Suite' designed to automate tasks related to sample instrument creation.
-- Running the script moves the samples to the beginning of the track with an even spacing between the samples.
-- This is a convenience script and running it is optional. It doesn't add anything to the automated processes.
-- author: Risto Sipola

function update_group_member_items(item, pos)
	local item_count = reaper.CountTrackMediaItems(reaper.GetMediaItem_Track(item))
	local group_id = reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
	
	if group_id ~= 0 then
		for i = reaper.CountMediaItems(0) - 1, 0, -1 do
			local temp_item = reaper.GetMediaItem(0, i)
			local temp_id = reaper.GetMediaItemInfo_Value(temp_item, "I_GROUPID")
			if temp_id == group_id and temp_item ~= item then
				reaper.SetMediaItemPosition(temp_item, pos, true)
			end			
		end		
	end	
end

function line_up_items()

	if reaper.CountSelectedTracks(0) == 1 then

		local track = reaper.GetSelectedTrack(0, 0)
		local item_count = reaper.CountTrackMediaItems(track)
		local pos_offset = 0.0
		
		if item_count > 0 then
			for i = 0, item_count - 1, 1 do
				local item = reaper.GetTrackMediaItem(track, i)
				local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
				reaper.SetMediaItemPosition(item, pos_offset, true)
				update_group_member_items(item, pos_offset)
				pos_offset = pos_offset + 0.5 + item_length
			end			
		end
	end
end

line_up_items()

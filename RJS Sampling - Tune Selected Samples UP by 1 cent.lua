-- This script is a part of 'RJS Sampling Suite' designed to automate tasks related to sample instrument creation.
-- Running the script changes the pitch of the selected samples by 1 cent.
-- author: Risto Sipola

--------------------------------------------------------------------------------------------------------
default_tune_mode = "rate" -- change this to change the default behavior of the script. "rate" or "pitch".
---------------------------------------------------------------------------------------------------------

linear_cent_approximation = 0.0005946 --https://en.wikipedia.org/wiki/Cent_(music)#Piecewise_linear_approximation
one_cent_up_factor = (1 + linear_cent_approximation)

function update_group_member_items(item, value, tune_mode)
	local item_count = reaper.CountTrackMediaItems(reaper.GetMediaItem_Track(item))
	local group_id = reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
	
	if group_id ~= 0 then
		for i = reaper.CountMediaItems(0) - 1, 0, -1 do
			local temp_item = reaper.GetMediaItem(0, i)
			local temp_id = reaper.GetMediaItemInfo_Value(temp_item, "I_GROUPID")
			if temp_id == group_id and temp_item ~= item then
				if tune_mode == "pitch" then
					reaper.SetMediaItemTakeInfo_Value(reaper.GetTake(temp_item, 0), "D_PITCH", value)
					reaper.UpdateItemInProject(temp_item)
				else
					reaper.SetMediaItemTakeInfo_Value(reaper.GetTake(temp_item, 0), "D_PLAYRATE", value)
					reaper.UpdateItemInProject(temp_item)
				end
			end			
		end		
	end	
end

function tune_selected_samples_up(cents, tune_mode)
			
	local pitch_shift = cents / 100
	local num_tracks = reaper.CountTracks(0)
	if num_tracks > 0 then
		local sample_track = reaper.GetTrack(0, 0)
		local num_samples = reaper.CountTrackMediaItems(sample_track)
			
		for i = 0, num_samples - 1, 1 do
			local sample = reaper.GetTrackMediaItem(sample_track, i)
			if reaper.IsMediaItemSelected(sample) then
				if tune_mode == "pitch" then
					local current_value = reaper.GetMediaItemTakeInfo_Value(reaper.GetTake(sample, 0), "D_PITCH")
					reaper.SetMediaItemTakeInfo_Value(reaper.GetTake(sample, 0), "D_PITCH", current_value + pitch_shift)
					reaper.UpdateItemInProject(sample)	
					update_group_member_items(sample, current_value + pitch_shift, tune_mode)	
				else
					local current_value = reaper.GetMediaItemTakeInfo_Value(reaper.GetTake(sample, 0), "D_PLAYRATE")
					reaper.SetMediaItemTakeInfo_Value(reaper.GetTake(sample, 0), "D_PLAYRATE", current_value * one_cent_up_factor)
					reaper.UpdateItemInProject(sample)	
					update_group_member_items(sample, current_value * one_cent_up_factor, tune_mode)
				end
			end
		end
	end
end

function main()

	local retval, num_markers, num_regions = reaper.CountProjectMarkers(0)
	local tune_mode = default_tune_mode

	for j = num_markers - 1, 0, -1 do
		local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(j)
		local identifier_found = false
		for word in string.gmatch(name, "%a+") do 
			if word == "tune" then
				identifier_found = true
				break;
			end
		end
		if identifier_found then
			for word in string.gmatch(name, "%a+") do 
			if word == "rate" then
				tune_mode = "rate"
				break;
			end
			if word == "pitch" then
				tune_mode = "pitch"
				break;
			end
		end
			break;
		end
	end

	tune_selected_samples_up(1, tune_mode)
end

main()

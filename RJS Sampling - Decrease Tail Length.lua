-- This script is a part of 'RJS Sampling Suite' designed to automate tasks related to sample instrument creation.
-- Running the script adjusts the ending point of the sample.
-- 'Chop Samples' script should be run before running this script as it links the samples and the cut out pieces that this script adjusts.
-- The script always adjusts the sample, meaning 'tail length' refers to the 'tail length' of the sample, not the cut out piece!
-- How to use: select a sample on the first track or a cut out item on the 'Cut-outs' track and run the script. It's possible to select multiple samples. 
-- author: Risto Sipola

function update_group_member_items(item, amount)
	local item_count = reaper.CountTrackMediaItems(reaper.GetMediaItem_Track(item))
	local group_id = reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
	
	if group_id ~= 0 then
		for i = reaper.CountMediaItems(0) - 1, 0, -1 do
			local temp_item = reaper.GetMediaItem(0, i)
			local temp_id = reaper.GetMediaItemInfo_Value(temp_item, "I_GROUPID")
			if temp_id == group_id and temp_item ~= item then
				reaper.SetMediaItemLength(temp_item, reaper.GetMediaItemInfo_Value(temp_item, "D_LENGTH") - amount, true) 
			end			
		end		
	end	
end

function decrease_tail_length(item, amount)
    
  if item ~= nil then
           
    local sel_item_track = reaper.GetMediaItemInfo_Value(item, "P_TRACK")    
    local retval, notes = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
    local track
    
    if sel_item_track == reaper.GetTrack(0, 0) then
		local track_count = reaper.CountTracks(0)
		for i = 1, track_count - 1, 1 do
			temp_track = reaper.GetTrack(0, i)
			retval, tr_name = reaper.GetTrackName(temp_track)
			if tr_name == "Cut-Outs" then
				track = temp_track
				break;
			end
		end
    else
      track = reaper.GetTrack(0, 0)
    end

	if track == nil then
		return -1
	end

    local item_count = reaper.CountTrackMediaItems(track)
    
    for i = 0, item_count - 1, 1 do

      local target_item = reaper.GetTrackMediaItem(track, i)
      local retvalue, target_i_notes = reaper.GetSetMediaItemInfo_String(target_item, "P_NOTES", "", false)
      local notes_numbercodes = {}
      local par_indx = 1;

      for word in string.gmatch(notes, "%d+") do 
        notes_numbercodes[par_indx] = word
        par_indx = par_indx + 1
      end
      
      for word in string.gmatch(target_i_notes, "%d+") do 
        notes_numbercodes[par_indx] = word
        par_indx = par_indx + 1
      end

      if sel_item_track ~= reaper.GetTrack(0, 0) and notes_numbercodes[1] == notes_numbercodes[4] or sel_item_track == reaper.GetTrack(0, 0) and notes_numbercodes[2] == notes_numbercodes[3] then  
        if sel_item_track ~= reaper.GetTrack(0, 0) then
          local temp = item
          item = target_item
          target_item = temp
        end

		local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
		
		if item_length > amount then
			reaper.SetMediaItemLength(target_item, reaper.GetMediaItemInfo_Value(target_item, "D_LENGTH") + amount, true)  
			reaper.SetMediaItemLength(item, reaper.GetMediaItemInfo_Value(item, "D_LENGTH") - amount, true)  
			
			reaper.SetMediaItemTakeInfo_Value(reaper.GetTake(target_item, 0), "D_STARTOFFS", reaper.GetMediaItemTakeInfo_Value(reaper.GetTake(target_item, 0), "D_STARTOFFS") - amount)
			reaper.SetMediaItemPosition(target_item, reaper.GetMediaItemInfo_Value(target_item, "D_POSITION") - amount, true) 
			update_group_member_items(item, amount)
		end
		return 0;
      end
    end  
  end
end

function main()

	local selected_item_count = reaper.CountSelectedMediaItems(0)
  
	for i = 0, selected_item_count - 1, 1 do
		local item = reaper.GetSelectedMediaItem(0, i)
		decrease_tail_length(item, 0.020)
	end

end

main()













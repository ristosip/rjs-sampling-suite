-- This script is a part of 'Sampling Suite' designed to automate tasks related to sample instrument creation.
-- Running the script labels the samples based on timeline markers that indicate midi note values.
--
-- How to use: 
--             1. Place the samples on the first track of the project. Ideally you have run the 'Chop Samples' script and are ready to go.
--             2. Create timeline markers to indicate the desired midi note value. (See details below.)
--             3. Run the script.
--
-- Timeline markers:
--             'perc [midi note value]'
--
--              Every sample appearing after a marker will be labeled accordingly.
--              Create a new marker each time you want to change the labeling.
--              * Visual Example:
--
--  Timeline--> |---------|---------|---------|---------|---------|---------|---------|---------|---------|---------|---------|---------|---------|---------|---------|---------|
--                 ||                                      ||                                         || 
--                 Marker 1: 'perc 36'                     Marker 2: 'perc 38'                        Marker 3: 'perc 42'
--
--                    [Sample 1]  [Sample 2]   [Sample 3]      [Sample 4]  [Sample 5]  [Sample 6]           [Sample 7]    [Sample 8]
-- 
--
--              Samples 1-3 would be assigned to midi note '36' and labeled/colored accordingly.
--              Samples 4-6 would be assigned to midi note '38'.
--              Samples 7-8 would be assigned to midi note '42'.
--
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

function assign_percussion_keys(item, note)
	-- colors the item based on the midi note number, that is the output of this script: R component has the pure note number, others are manipulated for artistic effect
	reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", reaper.ColorToNative(note, math.abs(math.floor((255 - (note%12)/12 * 255))),math.floor((note%12)/12 * 255/2))|0x1000000)
	reaper.UpdateArrange()
	update_group_member_items(item, note)					
end

function main()
	local itemCount = reaper.CountTrackMediaItems(reaper.GetTrack(0, 0))
	local retval, num_markers, num_regions = reaper.CountProjectMarkers(0)
	local midi_note = 36
	
	if itemCount > 0 then
		for i = 0, itemCount - 1, 1 do
			local item = reaper.GetTrackMediaItem(reaper.GetTrack(0, 0), i)
			local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
			for j = num_markers - 1, 0, -1 do
				local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(j)
				local identifier_found = false
				if pos < item_pos then
					for word in string.gmatch(name, "%a+") do 
						if word == "perc" then
							identifier_found = true
							break;
						end
					end
					if identifier_found then
						for word in string.gmatch(name, "%d+") do 
							if tonumber(word) >= 24 and tonumber(word) <= 108 then
								midi_note = tonumber(word)
								break;
							else
								midi_note = 36
								break;
							end
						end
						break;
					else
						midi_note = 36
					end
				end
			end			
			assign_percussion_keys(item, midi_note)	
		end
	end
end

main()
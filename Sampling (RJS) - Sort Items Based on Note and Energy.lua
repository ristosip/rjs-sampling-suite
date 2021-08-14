-- This script is a part of 'Sampling Suite' designed to automate tasks related to sample instrument creation.
-- Running the script reorders the samples based on note and signal energy values.
-- The script is designed to help sorting and curating the samples that go into the 'arranging for export' phase.
-- This is a convenience script and running it is optional. It doesn't add anything to the automated processes.
--
-- Sorting and Energy Detection modes:
--                    The script has four modes:
--                    -  1  Transient heavy mode: The energy is calculated from the first 10 ms of the signal.
--                    -  2  Body heavy mode (Default): The energy is calculated from the first 500 ms of the signal (or the whole sample length if the sample is shorter than 500 ms).
--                    -  3  Ignore Energy Values.
--                    -  4  Ignore Note Values. (Body heavy energy calculation)
--                    -  5  Ignore Note Values. (Transient heavy energy calculation)
--
--                    The mode can be changed by using a marker as an input command:        'sortNE [sorting mode num]' 
--
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

function sort_items_by_note_and_signal_energy()

	local itemCount = reaper.CountTrackMediaItems(reaper.GetTrack(0, 0))
	local itemEnergyValues = {}
	local itemNoteValues = {}
	local itemList = {}
	local default_mode = 2
	local energy_detection_mode = default_mode
	local transient_heavy_mode = 1
	local body_heavy_mode = 2
	
	-- read input data
	local retval, num_markers, num_regions = reaper.CountProjectMarkers(0)
	local marker_count = num_markers + num_regions
	for i = 0, marker_count - 1, 1 do
	
		local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
		local input_parameters = {}
		local par_indx = 1
		input_parameters[1] = 2

		local j, k = string.find(name, "sortNE")

		if j ~= nil then
			for word in string.gmatch(name, "%d+") do 
				input_parameters[par_indx] = word
				par_indx = par_indx + 1
			end
			energy_detection_mode = tonumber(input_parameters[1])
			break; --breaks 'for'-loop
		end
	end 
	
	if energy_detection_mode < 1 or energy_detection_mode > 5 then
		energy_detection_mode = default_mode
	end
	
	if itemCount > 0 then
		for i = 0, itemCount - 1, 1 do
		
			local item = reaper.GetTrackMediaItem(reaper.GetTrack(0, 0), i)
			local take = reaper.GetTake(item, 0)
			local source = reaper.GetMediaItemTake_Source(take)
			local numchannels = reaper.GetMediaSourceNumChannels(source)
			local samplerate = reaper.GetMediaSourceSampleRate(source)
			local starttime_sec = 0.0
			local endtime_sec = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
						
			if energy_detection_mode == transient_heavy_mode or energy_detection_mode == 3 or energy_detection_mode == 5 then
				starttime_sec = .000
				if endtime_sec > 0.010 then
					endtime_sec = 0.010
				end
			elseif energy_detection_mode == body_heavy_mode then
				starttime_sec = 0.000
				if endtime_sec > 0.500 then
					endtime_sec = 0.500
				end
			end	
			
			local samplecount = math.floor((endtime_sec - starttime_sec) * samplerate)
			local bufferSize = samplecount * numchannels
			local samplebuffer = reaper.new_array(bufferSize)
			local audio_accessor = reaper.CreateTakeAudioAccessor(take)

			retval = reaper.GetAudioAccessorSamples(audio_accessor, samplerate, numchannels, starttime_sec, samplecount, samplebuffer)

			if retval == 1 and numchannels < 3 then
				local temp_buffer = samplebuffer.table()
				local monoBuffer = {}
				monoBufferSize = 0
				if numchannels == 2 then
					for i = 1, bufferSize, 2 do
						monoBufferSize = monoBufferSize + 1
						monoBuffer[monoBufferSize] = temp_buffer[i] + temp_buffer[i + 1]
					end
				else
					monoBuffer = temp_buffer
					monoBufferSize = bufferSize
				end
				
				local energy = 0
				
				for j = 1, monoBufferSize, 1 do
					energy = energy + monoBuffer[j] * monoBuffer[j]
				end
				
				itemEnergyValues[i + 1] = energy
			end

			r, g, b = reaper.ColorFromNative(reaper.GetMediaItemInfo_Value(reaper.GetTrackMediaItem(reaper.GetTrack(0, 0), i), 'I_CUSTOMCOLOR'))
			itemNoteValues[i + 1] = r -- 'Detect Sample Pitch' script writes the midi note value in to the item color
			itemList[i + 1] = item
		end
		
		-- sorting init
		
		local sorted_item_list = itemList
		local original_index = {}
		
		for i = 1, itemCount, 1 do
			original_index[i] = i
		end	
		
		if energy_detection_mode == 4 or energy_detection_mode == 5 then
			for i = 1, itemCount, 1 do
				itemNoteValues[i] = 1 -- the actual note values are ignored by writing over them
			end
		end
		
		-- sort by midi note values
		
		if energy_detection_mode < 4 then -- energy_detection_mode = sorting mode. mode 4 and 5 ---> ignore note values.

			for i = 1, math.floor(itemCount/2) + 1, 1 do
				local max = itemNoteValues[original_index[i]]
				local min = itemNoteValues[original_index[itemCount - i + 1]]
				local max_swap_idx = -1
				local min_swap_idx = -1
				 
				for j = i + 1, itemCount - i + 1, 1 do
					if itemNoteValues[original_index[j]] > max then
						max_swap_idx = j
						max = itemNoteValues[original_index[j]]
					end
				end
				if max_swap_idx ~= -1 then
					local temp = sorted_item_list[max_swap_idx]
					sorted_item_list[max_swap_idx] = sorted_item_list[i]
					sorted_item_list[i] = temp
					
					local temp_2 = original_index[max_swap_idx]
					original_index[max_swap_idx] = original_index[i]
					original_index[i] = temp_2
				end
				for j = i + 1, itemCount - i + 1, 1 do
					if itemNoteValues[original_index[itemCount - j + 1]] < min then
						min_swap_idx = itemCount - j + 1
						min = itemNoteValues[original_index[itemCount - j + 1]]
					end
				end
				if min_swap_idx ~= -1 then
					local temp = sorted_item_list[min_swap_idx]
					sorted_item_list[min_swap_idx] = sorted_item_list[itemCount - i +  1]
					sorted_item_list[itemCount - i +  1] = temp
					
					local temp_2 = original_index[min_swap_idx]
					original_index[min_swap_idx] = original_index[itemCount - i +  1]
					original_index[itemCount - i +  1] = temp_2
				end
			end	
		
		end
		
		-- sort items by signal energy values
		
		if energy_detection_mode ~= 3 then -- mode 4 and 5 ---> ignore energy values.
		
			local note_number_occurrence = {}
			note_number_occurrence[1] = 0
			local occurrence_list_idx = 0
			local counter = 0
			local current_number = -1
			
			for i = 1, itemCount, 1 do
				if itemNoteValues[original_index[i]] ~= current_number then
					current_number = itemNoteValues[original_index[i]]
					occurrence_list_idx = occurrence_list_idx + 1
					if note_number_occurrence[occurrence_list_idx] == nil then
						note_number_occurrence[occurrence_list_idx] = 0
					end
					note_number_occurrence[occurrence_list_idx] = note_number_occurrence[occurrence_list_idx] + 1
				else
					note_number_occurrence[occurrence_list_idx] = note_number_occurrence[occurrence_list_idx] + 1
				end
			end			
			
			local i_offset = 0

			for k = 1, occurrence_list_idx, 1 do
			
				local itemCount_ = note_number_occurrence[k]
			
				for i = 1, math.floor(itemCount_/2) + 1, 1 do
					local max = itemEnergyValues[original_index[i + i_offset]]
					local min = itemEnergyValues[original_index[itemCount_ - i + 1  + i_offset]]
					local max_swap_idx = -1
					local min_swap_idx = -1
					 
					for j = i + 1, itemCount_ - i + 1, 1 do
						if itemEnergyValues[original_index[j + i_offset]] > max then
							max_swap_idx = j + i_offset
							max = itemEnergyValues[original_index[j + i_offset]]
						end
					end
					if max_swap_idx ~= -1 then
						local temp = sorted_item_list[max_swap_idx]
						sorted_item_list[max_swap_idx] = sorted_item_list[i + i_offset]
						sorted_item_list[i + i_offset] = temp

						local temp_2 = original_index[max_swap_idx]
						original_index[max_swap_idx] = original_index[i + i_offset]
						original_index[i + i_offset] = temp_2
					end
					for j = i + 1, itemCount_ - i + 1, 1 do
						if itemEnergyValues[original_index[itemCount_ - j + 1 + i_offset]] < min then
							min_swap_idx = itemCount_ - j + 1 + i_offset
							min = itemEnergyValues[original_index[itemCount_ - j + 1 + i_offset]]
						end
					end
					if min_swap_idx ~= -1 then
						local temp = sorted_item_list[min_swap_idx]
						sorted_item_list[min_swap_idx] = sorted_item_list[itemCount_ - i +  1 + i_offset]
						sorted_item_list[itemCount_ - i +  1 + i_offset] = temp
						
						local temp_2 = original_index[min_swap_idx]
						original_index[min_swap_idx] = original_index[itemCount_ - i +  1 + i_offset]
						original_index[itemCount_ - i +  1 + i_offset] = temp_2
					end
				end
				i_offset = i_offset + note_number_occurrence[k]
			end
		
		end

		-- move sorted items
		
		local newPosition = 0
		
		for i = itemCount, 1, -1 do
			reaper.SetMediaItemPosition(sorted_item_list[i], newPosition, true)
			update_group_member_items(sorted_item_list[i], newPosition)
			newPosition = newPosition + reaper.GetMediaItemInfo_Value(sorted_item_list[i], "D_LENGTH") + 1.00
		end
		
	end
end

sort_items_by_note_and_signal_energy()
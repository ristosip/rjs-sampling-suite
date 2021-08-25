-- This script is a part of 'RJS Sampling Suite' designed to automate tasks related to sample instrument creation.
-- Running the script detects segments of audio that have audible content and chops the source item accordingly.
--
-- How to use: 
--             1. Place the source item on the first track of the project. 
--             2. Align and group the other source items on separate tracks if you have a multi mic recording.
--             3. If needed, create a timeline marker that serves as an input command for the script. (See details below.)
--             4. Run the script.
-- 
-- Input Command:
--             'chop [minimum sample length (ms)] [leading pad lenght (ms)] [start point detection sensitivity mode (1-3 + noisy modes)] [end point detection accuracy mode (1-3)] [show what is cut (1 or 0)] [fade out length (ms)] [fade in length (ms)]'
--
-- You only need to give as many input parameters as you want!
--
-- Examples of valid input commands:
--             Default parameters: No input command marker needed at all, just run the script! The default parameters are:         'chop 500 1 2 2 1 100 0.5'
--             Longer minimum length (useful when dealing with long notes / high detection sensitivity / noisy audio):             'chop 1500'
--             Shorter minimum length (useful for cutting short percussive sounds):                                                'chop 150'
--             Increased start point detection sensitivity (useful when cutting pad like sounds with slow attack):                 'chop 500 1 3'
--             Increased end point detection accuracy (useful when cutting sounds with long quiet tails):                          'chop 500 1 2 3'
--
-- Noisy Modes:
--             Noisy modes may be useful when a recording has a very high noise floor (due to being a compressed or auto-gained signal of a portable recorder or  a phone).
--             Available parameter values: 10 (high noise floor), 11 (very high noise floor)
--             Example:   'chop 500 1 11 10'
--             The start point sensitivity can be more of an issue then the end point accuracy setting.
--             -- These settings seem to work well:    'chop 500 1 10 1'    or    'chop 500 1 11 1'   (notice that the end point accuracy is the lowest one in the normal range, no noisy mode needed)
--
--
-- author: Risto Sipola

------------------------------------------------------------------------------------------
--------------------------- Default settings----------------------------------------------
------------------------------------------------------------------------------------------

default_min_sample_length_ms = 500

default_leading_pad_length_ms = 1

default_start_point_sensitivity_mode = 2

default_end_point_accuracy_mode = 2

default_show_what_is_cut = true

default_sample_fade_out_length_ms = 100

default_sample_fade_in_length_ms = 0.5  -- notice that decimal number values cannot be passed via the input command. The default value given here can be a decimal number.

------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------

function get_sample_block(block_size, audio_accessor, sample_rate, num_channels, sample_offset)

		local bufferSize = block_size * num_channels
		local samplebuffer = reaper.new_array(bufferSize)
		local start_time = sample_offset / sample_rate

		retval = reaper.GetAudioAccessorSamples(audio_accessor, sample_rate, num_channels, start_time, block_size, samplebuffer)

		if retval == 1 and num_channels < 3 and sample_rate > 0 then
			local temp_buffer = samplebuffer.table()
			local monoBuffer = {}
			monoBufferSize = 0
			if num_channels == 2 then
				for i = 1, bufferSize - 1, 2 do
					monoBufferSize = monoBufferSize + 1
					monoBuffer[monoBufferSize] = temp_buffer[i] + temp_buffer[i + 1]
				end
			else
				monoBuffer = temp_buffer
				monoBufferSize = bufferSize
			end
			return monoBuffer, monoBufferSize;
		else
			return {0}, -1;
		end
end

function find_sample_splitpoints(audio_accessor, sample_rate, num_channels, item_endtime, sensitivity_sp, sensitivity_ep)

	local peak_threshold = 0.0005 / sensitivity_sp
	local energy_threshold_1 = 0.001 / sensitivity_sp -- 1-3 are for start-point search
	local energy_threshold_2 = 0.002 / sensitivity_sp
	local energy_threshold_3 = 0.004 / sensitivity_sp
	local energy_threshold_4 = 0.000001 * sensitivity_ep -- 4-6 are for end-point search
	local energy_threshold_5 = 0.000001 * sensitivity_ep
	local energy_threshold_6 = 0.0000005 * sensitivity_ep
	local e_of_segment_1 = 0
	local e_of_segment_2 = 0
	local e_of_segment_3 = 0
	local segment_1_length = 0.001 * sample_rate
	local segment_2_length = 0.001 * sample_rate
	local segment_3_length = 0.001 * sample_rate
	local split_idx = 0
	local split_points = {}
	local point_types = {} -- '1' for start, '0' for end
	local i = 1
	local item_end_reached = false
	local i_offset = 0
	local blockSize = 1.0 * sample_rate
	local buffer, buffer_size = get_sample_block(blockSize, audio_accessor, sample_rate, num_channels, i_offset)

	while i < buffer_size - (math.floor(segment_1_length) + math.floor(segment_2_length) + math.floor(segment_3_length)) and item_end_reached == false do 

		while i < buffer_size - (math.floor(segment_1_length) + math.floor(segment_2_length) + math.floor(segment_3_length)) and item_end_reached == false do -- start point search loop
	
			e_of_segment_1 = 0
			e_of_segment_2 = 0
			e_of_segment_3 = 0
			
			if math.abs(buffer[i]) > peak_threshold then
				for j = i, i + math.floor(segment_1_length), 1 do
					e_of_segment_1 = e_of_segment_1 + buffer[j] * buffer[j]
				end
				if e_of_segment_1 > energy_threshold_1 then
					for j = i + math.floor(segment_1_length), i + math.floor(segment_1_length) + math.floor(segment_2_length), 1 do
						e_of_segment_2 = e_of_segment_2 + buffer[j] * buffer[j]						
					end				
					if e_of_segment_2 > energy_threshold_2 then
						for j = i + math.floor(segment_1_length) + math.floor(segment_2_length), i + math.floor(segment_1_length) + math.floor(segment_2_length) + math.floor(segment_3_length), 1 do
							e_of_segment_3 = e_of_segment_3 + buffer[j] * buffer[j]							
						end
						if e_of_segment_3 > energy_threshold_3 then -- new start point found
							split_idx = split_idx + 1
							split_points[split_idx] = i_offset
							point_types[split_idx] = 1 
							break; -- breaks the 'start point search loop'
						end
					end
				end
			end	
				i = i + 10
				i_offset = i_offset + 10
				if i_offset > math.floor(item_endtime * sample_rate) then
					item_end_reached = true
				end
				if i >= buffer_size - (segment_1_length + segment_2_length + segment_3_length) and item_end_reached == false then
					buffer, buffer_size = get_sample_block(blockSize, audio_accessor, sample_rate, num_channels, i_offset)	
					i = 1
				end
		end
		while i < buffer_size - (math.floor(segment_1_length) + math.floor(segment_2_length) + math.floor(segment_3_length)) and item_end_reached == false do -- end point search loop
	
			e_of_segment_1 = 0
			e_of_segment_2 = 0
			e_of_segment_3 = 0
	
			for j = i, i + math.floor(segment_1_length), 1 do
				e_of_segment_1 = e_of_segment_1 + buffer[j] * buffer[j]
			end
			if e_of_segment_1 < energy_threshold_4 then
				for j = i + math.floor(segment_1_length), i + math.floor(segment_1_length) + math.floor(segment_2_length), 1 do
					e_of_segment_2 = e_of_segment_2 + buffer[j] * buffer[j]
				end				
				if e_of_segment_2 < energy_threshold_5 then
					for j = i + math.floor(segment_1_length) + math.floor(segment_2_length), i + math.floor(segment_1_length) + math.floor(segment_2_length) + math.floor(segment_3_length), 1 do
						e_of_segment_3 = e_of_segment_3 + buffer[j] * buffer[j]
					end
					if e_of_segment_3 < energy_threshold_6 then -- new end point found
						split_idx = split_idx + 1
						split_points[split_idx] = i_offset
						point_types[split_idx] = 0 
						break; -- breaks the 'end point search loop'
					end
				end
			end
			i = i + 400
			i_offset = i_offset + 400
				if i_offset > math.floor(item_endtime * sample_rate) then
					item_end_reached = true					
				end
				if i >= buffer_size - (segment_1_length + segment_2_length + segment_3_length) and item_end_reached == false then
					buffer, buffer_size = get_sample_block(blockSize, audio_accessor, sample_rate, num_channels, i_offset)	
					i = 1
				end
		end
	end
	
	return split_points, point_types, split_idx;
end 

function clean_up_splits(raw_splits, raw_types, raw_array_length, sample_rate, item_end_time, min_length)
	local clean_split_points = {}
	local clean_split_types = {}
	local clean_array_length = 0
	
	if raw_array_length > 1 and sample_rate > 0 then

		-- last item piece is a special case
		if math.abs(item_end_time * sample_rate - raw_splits[raw_array_length]) / sample_rate < min_length or raw_types[i] == 0 then	
			if raw_array_length > 1 then
				if raw_types[raw_array_length - 1] == 1 then 
					if math.abs(raw_splits[raw_array_length] - raw_splits[raw_array_length - 1]) / sample_rate < min_length then
						raw_splits[raw_array_length] = -1 -- '-1' denotes a point to be removed from the list
						raw_types[raw_array_length - 1] = 0 -- fuses into a cut-out piece
					end	
				else
					raw_splits[raw_array_length] = -1
				end
			end
		end

		-- the rest of the pieces
		for i = raw_array_length - 1, 1, -1 do
			if raw_types[i] == 0 then
				if i > 1 then
					if raw_types[i - 1] == 1 then
						if math.abs(raw_splits[i] - raw_splits[i - 1]) / sample_rate < min_length then
							raw_splits[i] = -1 -- '-1' denotes a point to be removed from the list
							raw_types[i - 1] = 0 -- fuses into a cut-out piece							
						end
					else
						raw_splits[i] = -1
					end	
				else
					if (raw_splits[i] / sample_rate < min_length) and raw_types[i] == 0 then
						raw_splits[i] = -1
					end
				end
			end
		end
		
		for i = 1, raw_array_length, 1 do
			if raw_splits[i] ~= -1 then
				clean_array_length = clean_array_length + 1
				clean_split_points[clean_array_length] = raw_splits[i]
				clean_split_types[clean_array_length] = raw_types[i]				
			end			
		end
		return clean_split_points, clean_split_types, clean_array_length;
	else
		return {0}, -1, -1;
	end
	
end 

function split_grouped_items(track)
	local item_count = reaper.CountTrackMediaItems(track)
	local group_id_counter = 10000
	
	for i = item_count - 1, 0, -1 do
		local item = reaper.GetTrackMediaItem(track, i)
		local group_id = reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
		local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
		local end_pos = pos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
		for j = reaper.CountMediaItems(0) - 1, 0, -1 do
			local temp_item = reaper.GetMediaItem(0, j)
			local temp_id = reaper.GetMediaItemInfo_Value(temp_item, "I_GROUPID")
			if temp_id == group_id and group_id ~= 0 then
				local temp_pos = reaper.GetMediaItemInfo_Value(temp_item, "D_POSITION")
				local temp_end_pos = temp_pos + reaper.GetMediaItemInfo_Value(temp_item, "D_LENGTH")
				if temp_end_pos > end_pos and temp_pos < end_pos then
					local cut_out_item = reaper.SplitMediaItem(temp_item, end_pos)
					reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(cut_out_item), cut_out_item)
				end	
				if temp_pos < pos and temp_end_pos > pos then
					local new_item = reaper.SplitMediaItem(temp_item, pos)
					if new_item ~= nil then
						reaper.SetMediaItemInfo_Value(new_item, "D_FADEINLEN", reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN"))
						reaper.SetMediaItemInfo_Value(new_item, "D_FADEOUTLEN", reaper.GetMediaItemInfo_Value(item, "D_FADEOUTLEN"))
					end
				end
			end			
		end		
	end
	
	-- form groups for multi-mic samples
	for i = item_count - 1, 0, -1 do
		local item = reaper.GetTrackMediaItem(track, i)
		local group_id = reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
		if group_id ~= 0 then
			local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
			group_id_counter = group_id_counter + 1
			reaper.SetMediaItemInfo_Value(item, "I_GROUPID", group_id_counter)		
			for j = reaper.CountMediaItems(0) - 1, 0, -1 do
				local temp_item = reaper.GetMediaItem(0, j)
				local temp_id = reaper.GetMediaItemInfo_Value(temp_item, "I_GROUPID")
				if temp_id == group_id and group_id ~= 0 then
					local temp_pos = reaper.GetMediaItemInfo_Value(temp_item, "D_POSITION")
					if math.abs(temp_pos - pos) < 0.01 then
						reaper.SetMediaItemInfo_Value(temp_item, "I_GROUPID", group_id_counter)
					end
				end			
			end	
			if i == 0 then -- remove unused items
				for j = reaper.CountMediaItems(0) - 1, 0, -1 do
					local temp_item = reaper.GetMediaItem(0, j)
					local temp_id = reaper.GetMediaItemInfo_Value(temp_item, "I_GROUPID")
					local retval, tr_name = reaper.GetTrackName(reaper.GetMediaItem_Track(temp_item))
					if temp_id == group_id and tr_name ~= "Cut-Outs" and group_id ~= 0 and group_id < 10000 then
						reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(temp_item), temp_item)
					end			
				end	
			end
		end
	end
end

function main()

	--local default_sensitivity_mode = 2
	local sensitivity_mode_sp = default_start_point_sensitivity_mode
	local sensitivity_mode_ep = default_end_point_accuracy_mode
	local startpoints_detection_sensitivity
	local endpoints_detection_sensitivity

	local leading_pad = default_leading_pad_length_ms / 1000
	local fade_in_length = default_sample_fade_in_length_ms / 1000 
	local fade_out_length = default_sample_fade_out_length_ms / 1000 
	local show_what_is_cut = default_show_what_is_cut 
	local minLength = default_min_sample_length_ms / 1000 
	local cut_outs_track

	-- read input data
	local retval, num_markers, num_regions = reaper.CountProjectMarkers(0)
	local marker_count = num_markers + num_regions
	for i = 0, marker_count - 1, 1 do
	
		local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
		local input_parameters = {}
		local par_indx = 1

		local j, k = string.find(name, "chop")

		if j ~= nil then
			for word in string.gmatch(name, "%d+") do 
				input_parameters[par_indx] = word
				par_indx = par_indx + 1
			end
			if par_indx > 1 then
				minLength = tonumber(input_parameters[1])/1000
			end
			if par_indx > 2 then
				leading_pad = tonumber(input_parameters[2])/1000
			end
			if par_indx > 3 then
				sensitivity_mode_sp = tonumber(input_parameters[3])
			end
			if par_indx > 4 then
				sensitivity_mode_ep = tonumber(input_parameters[4])
			end
			if par_indx > 5 then
				if tonumber(input_parameters[5]) == 0 then
					show_what_is_cut = false
				end
			end
			if par_indx > 6 then
				fade_out_length = tonumber(input_parameters[6])/1000
			end
			if par_indx > 7 then
				fade_in_length = tonumber(input_parameters[7])/1000
			end
			break; --breaks 'for'-loop
		end
	end 
	
	if (sensitivity_mode_sp < 1 or sensitivity_mode_sp > 3) and sensitivity_mode_sp ~= 10 and sensitivity_mode_sp ~= 11 then
		sensitivity_mode_sp = default_sensitivity_mode
	end
	if (sensitivity_mode_ep < 1 or sensitivity_mode_ep > 3) and sensitivity_mode_sp ~= 10 and sensitivity_mode_sp ~= 11  then
		sensitivity_mode_ep = default_sensitivity_mode
	end

		 
	if sensitivity_mode_sp == 1 then
		startpoints_detection_sensitivity = 1.0
	elseif sensitivity_mode_sp == 2 then
		startpoints_detection_sensitivity = 10.0
	elseif sensitivity_mode_sp == 3 then
		startpoints_detection_sensitivity = 100.0
	elseif sensitivity_mode_sp == 10 then
		startpoints_detection_sensitivity = 0.1 -- noisy mode: high noise floor
	elseif sensitivity_mode_sp == 11 then
		startpoints_detection_sensitivity = 0.01 -- extra noisy mode: very high noise floor
	end


	if sensitivity_mode_ep == 3 then
		endpoints_detection_sensitivity = 1.0
	elseif sensitivity_mode_ep == 2 then
		endpoints_detection_sensitivity = 10.0
	elseif sensitivity_mode_ep == 1 then
		endpoints_detection_sensitivity = 100.0
		if sensitivity_mode_sp == 3 then
			endpoints_detection_sensitivity = 10.0
		end
	elseif sensitivity_mode_ep == 10 then
		endpoints_detection_sensitivity = 1000.0 -- noisy mode: high noise floor
		if sensitivity_mode_sp == 3 then
			endpoints_detection_sensitivity = 10.0
		end
	elseif sensitivity_mode_ep == 11 then
		endpoints_detection_sensitivity = 10000.0 -- extra noisy mode: very high noise floor
		if sensitivity_mode_sp == 3 then
			endpoints_detection_sensitivity = 10.0
		end
	end
	
	local track = reaper.GetTrack(0, 0)	
	local num_of_items = reaper.CountTrackMediaItems(track)	

	for i = num_of_items - 1, 0, -1 do
		
		local original_item_identifier = (i + 1) * 1000		
		local item = reaper.GetTrackMediaItem(track, i)
		local take = reaper.GetTake(item, 0)
		local source = reaper.GetMediaItemTake_Source(take)
		local numchannels = reaper.GetMediaSourceNumChannels(source)
		local samplerate = reaper.GetMediaSourceSampleRate(source)
		local itemEndtime = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
		local audioAccessor = reaper.CreateTakeAudioAccessor(take)

		if audioAccessor ~= nil and samplerate > 0 then

			local splitPoints_raw, pointTypes_raw, array_length_raw = find_sample_splitpoints(audioAccessor, samplerate, numchannels, itemEndtime, startpoints_detection_sensitivity, endpoints_detection_sensitivity)
		
			local splitPoints, pointTypes, array_length = clean_up_splits(splitPoints_raw, pointTypes_raw, array_length_raw, samplerate, itemEndtime, minLength)
		
			if splitPoints ~= nil and pointTypes ~= nil and array_length > 0 then
				if show_what_is_cut == true then
					local num_tracks = reaper.CountTracks(0)
					local dest_track_exists = false
					for i = 0, num_tracks - 1, 1 do
						local temp_track = reaper.GetTrack(0, i)
						local retval, name = reaper.GetTrackName(temp_track)
						if name == "Cut-Outs" then
							dest_track_exists = true
							cut_outs_track = temp_track
						end
					end
					if dest_track_exists == false then
						reaper.InsertTrackAtIndex(1, true)
						cut_outs_track = reaper.GetTrack(0, 1)
						reaper.GetSetMediaTrackInfo_String(cut_outs_track, "P_NAME", "Cut-Outs", true)
					end
				end
				for i = array_length, 1, -1 do				
					local ret_item = reaper.SplitMediaItem(item, reaper.GetMediaItemInfo_Value(item, "D_POSITION") + splitPoints[i] / samplerate - leading_pad)
					if ret_item ~= nil then
						reaper.SetMediaItemInfo_Value(ret_item, "D_FADEINLEN", fade_in_length)
						reaper.SetMediaItemInfo_Value(ret_item, "D_FADEOUTLEN", fade_out_length)
						reaper.GetSetMediaItemInfo_String(ret_item, "P_NOTES", tostring(i + original_item_identifier).." "..tostring(i+1 + original_item_identifier), true)
						
						if pointTypes[i] == 0 then					
							if show_what_is_cut == true then
								reaper.SetMediaItemInfo_Value(ret_item, "D_FADEINLEN", 0)
								reaper.SetMediaItemInfo_Value(ret_item, "D_FADEOUTLEN", 0)
								reaper.MoveMediaItemToTrack(ret_item, cut_outs_track)
							else
								reaper.DeleteTrackMediaItem(track, ret_item)
							end	
						end
					end 					
					if i == 1 then
						if pointTypes[1] == 1 then
							reaper.GetSetMediaItemInfo_String(item, "P_NOTES", tostring(0 + original_item_identifier).." "..tostring(1 + original_item_identifier), true)
							if show_what_is_cut == true then
								reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", 0)
								reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", 0)
								reaper.MoveMediaItemToTrack(item, cut_outs_track)
							else
								reaper.DeleteTrackMediaItem(track, item)
							end	
						else
							reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", fade_in_length)
							reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", fade_out_length)
							reaper.GetSetMediaItemInfo_String(item, "P_NOTES", tostring(0 + original_item_identifier).." "..tostring(1 + original_item_identifier), true)
						end
					end
				end
				reaper.UpdateArrange()
			end
		end
	end
	split_grouped_items(track)
end

main()

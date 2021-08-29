-- Copyright (C) 2021 Risto Sipola
-- License: See LICENSE.txt
--
-- This script is a part of 'RJS Sampling Suite' designed to automate tasks related to sample instrument creation.
-- Running the script tunes the selected samples.
--
-- To change the tuning mode (pitch shift algorithm / playrate change) or the measurement window settings use a project marker as an input command.     
-- To change the default settings, change the code lines below.
--
-- How to use:
--            1. The samples need to be labelled. Run pitch detection or midi note assignment first.
--            2. Run the tuning script.
--
-- Input command:       'tune   [tuning mode: pitch/rate]   [measurement window start time (milliseconds)]    [measurement window (max) length (ms)]    [measurement stop point (max percentage of the sample length)]' 
--
--
-- author: Risto Sipola

--------------------------------------------------------------------------------------------------------
------------------------ change these to change the default behavior -----------------------------------
--------------------------------------------------------------------------------------------------------

default_tune_mode = "rate" -- change this to change the default behavior of the script. "rate" or "pitch".

default_measurement_window_start_time_ms = 400 -- the measurement should start once the note pitch has settled.

default_measurement_window_length_ms = 3000 -- this can be longer than the actual sample lengths. The number will be scaled down for each sample if needed.

default_measurement_end_max_percentage_of_sample_length = 70 -- 70 = 70 percent. This means that the measurement will stop if the point of [0.7 * sample length] is reached.
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------

note_frequencies = {4434.922, 4186.009, 3951.066, 3729.310, 3520.000, 3322.438, 3135.963, 2959.955, 2793.826, 2637.020, 2489.016, 2349.318, 2217.461, 
2093.005, 1975.533, 1864.655, 1760.000, 1661.219, 1567.982, 1479.978, 1396.913, 1318.510, 1244.508, 1174.659, 1108.731, 
1046.502, 987.7666, 932.3275, 880.0000, 830.6094, 783.9909, 739.9888, 698.4565, 659.2551, 622.2540, 587.3295, 554.3653, 
523.2511, 493.8833, 466.1638, 440.0000, 415.3047, 391.9954, 369.9944, 349.2282, 329.6276, 311.1270, 293.6648, 277.1826, 
261.6256, 246.9417, 233.0819, 220.0000, 207.6523, 195.9977, 184.9972, 174.6141, 164.8138, 155.5635, 146.8324, 138.5913,
130.8128, 123.4708, 116.5409, 110.0000, 103.8262, 97.99886, 92.49861, 87.30706, 82.40689, 77.78175, 73.41619, 69.29566, 
65.40639, 61.73541, 58.27047, 55.00000, 51.91309, 48.99943, 46.24930, 43.65353, 41.20344, 38.89087, 36.70810, 34.64783,
32.70320, 30.86771}
note_frequencies_size = 87

function get_audio_buffer(take, start_time_sec, length_sec)

	local source = reaper.GetMediaItemTake_Source(take)
	local numchannels = reaper.GetMediaSourceNumChannels(source)
	local samplerate = reaper.GetMediaSourceSampleRate(source)
	local starttime_sec = start_time_sec
	local samplecount = math.floor(length_sec * samplerate)
	local bufferSize = samplecount * numchannels
	local samplebuffer = reaper.new_array(bufferSize)
	local audio_accessor = reaper.CreateTakeAudioAccessor(take)

	retval = reaper.GetAudioAccessorSamples(audio_accessor, samplerate, numchannels, starttime_sec, samplecount, samplebuffer)
	
	if retval == 1 and numchannels < 3 then

		local temp_buffer = samplebuffer.table()
		local monoBuffer = {}
		monoBufferSize = 0
		if numchannels == 2 then
			for j = 1, bufferSize, 2 do
				monoBufferSize = monoBufferSize + 1
				monoBuffer[monoBufferSize] = temp_buffer[j] -- + temp_buffer[j + 1]
			end
		else
			monoBuffer = temp_buffer
			monoBufferSize = bufferSize
		end
		return monoBuffer, monoBufferSize, samplerate
	else
		return -1, -1, -1
	end
end

function search_zero_crossing(audio_buffer, buffer_size, search_start_offset)
	local phase = 1
	local zero_crossing_idx = -1
	local crossing_partial = -1
	
	if buffer_size > search_start_offset then
		
		for i = 1 + search_start_offset, buffer_size - 1, 1 do
			
			if audio_buffer[i] * audio_buffer[i + 1] < 0 then
				if audio_buffer[i] >= 0 then
					phase = -1
				end                                                      
				zero_crossing_idx = i
				crossing_partial = math.abs(audio_buffer[i]) / math.abs(audio_buffer[i] - audio_buffer[i + 1])
				break;
			end
		end
	end
	return zero_crossing_idx, crossing_partial, phase
end

function zero_crossing_method(audio_buffer, buffer_size, start_offset_samples, samplerate, ideal_pitch)

	local linear_cent_approximation = 0.0005946

	if ideal_pitch ~= 0 and samplerate ~= 0 then
		
		local period_start, start_crossing_partial, start_phase = search_zero_crossing(audio_buffer, buffer_size, start_offset_samples)
		
		if period_start ~= -1 then
			local period_length_sample_count = math.floor(samplerate / ideal_pitch) 			
			local two_period_stop, stop_crossing_partial, stop_phase  = search_zero_crossing(audio_buffer, buffer_size, start_offset_samples + 2 * period_length_sample_count - math.ceil(0.01 * period_length_sample_count)) 
			
			if two_period_stop ~= -1 then
				-- the crossing partials are for interpolation
				local measured_two_period = ((two_period_stop + stop_crossing_partial) - (period_start + start_crossing_partial)) / samplerate
				if math.abs(((measured_two_period / 2) / (1 / ideal_pitch)) - 1) < 60 * linear_cent_approximation and measured_two_period ~= 0 and start_phase == stop_phase then
					return 1 / (measured_two_period / 2)
				else
					return -1
				end
			end	
		else
			return -1
		end
	else
		return -1
	end
end

function calculate_pitch_difference(audio_buffer, buffer_size, samplerate, measuring_interval_sec, ideal_pitch)
	
	local measurements = {}
	local measurements_idx = 0
	local pitch = 0
	local offset_increment = math.floor(measuring_interval_sec * samplerate)
	local buffer_offset = -offset_increment
	
	while buffer_offset < buffer_size and offset_increment > 0 do
		
		buffer_offset = buffer_offset + offset_increment
		
		pitch = zero_crossing_method(audio_buffer, buffer_size, buffer_offset, samplerate, ideal_pitch)
	
		if pitch ~= -1 and pitch ~= nil then
			measurements_idx = measurements_idx + 1
			measurements[measurements_idx] = pitch
		end
	end
	
	if measurements_idx > 0 then		
		local pitch_sum = 0
		for i = 1, measurements_idx, 1 do
			pitch_sum = pitch_sum + measurements[i]
		end
		local average_pitch = pitch_sum / measurements_idx
		return average_pitch - ideal_pitch
	else
		return -1
	end
end

function tune_sample(item, tune_mode, meas_win_start_time, meas_win_length, meas_max_percent)

	local take = reaper.GetTake(item, 0)
	local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
	local start_time_sec = meas_win_start_time
	local snippet_length = meas_win_length
	local measuring_interval_sec = 0.010
	
	while snippet_length > 0.060 do
		if meas_max_percent * item_length < start_time_sec + snippet_length then
			start_time_sec = start_time_sec * 0.9
			snippet_length = snippet_length * 0.9 
		else
			break;
		end
	end
	local old_pitch = reaper.GetMediaItemTakeInfo_Value(take, "D_PITCH")
	reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH", 0)
	local old_rate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
	reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", 1) 
	local audio_buffer, buffer_size, samplerate = get_audio_buffer(take, start_time_sec, snippet_length)
	
	if buffer_size > 0 then	
	
		local linear_cent_approximation = 0.0005946 --https://en.wikipedia.org/wiki/Cent_(music)#Piecewise_linear_approximation
	
		local item_color = reaper.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
		local r, g, b = reaper.ColorFromNative(item_color)
		
		local ideal_pitch = note_frequencies[note_frequencies_size - (r - 23)]

		local pitch_delta = calculate_pitch_difference(audio_buffer, buffer_size, samplerate, measuring_interval_sec, ideal_pitch)

		if pitch_delta ~= -1 then
			if tune_mode == "pitch" then
				-- changing the sample tuning
				local pitch_shift = -pitch_delta / ideal_pitch / linear_cent_approximation / 100
				reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH", pitch_shift)
				reaper.UpdateItemInProject(item)
			else
				local playrate = ideal_pitch / (ideal_pitch + pitch_delta)
				reaper.SetMediaItemTakeInfo_Value(take, "B_PPITCH", 0)				
				reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", playrate)
				reaper.UpdateItemInProject(item)
			end
		else
			-- when tuning fails, set the values back to original
			reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH", old_pitch)
			reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", old_rate)
			reaper.UpdateItemInProject(item)
		end
	else
		-- when tuning fails, set the values back to original
		reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH", old_pitch)
		reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", old_rate)
		reaper.UpdateItemInProject(item)
	end
end

function main()

	local retval, num_markers, num_regions = reaper.CountProjectMarkers(0)
	local tune_mode = default_tune_mode
	local meas_win_start_time = default_measurement_window_start_time_ms / 1000
	local meas_win_length = default_measurement_window_length_ms / 1000
	local meas_max_percent = default_measurement_end_max_percentage_of_sample_length / 100
	local input_parameters = {}
	local par_indx = 0

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
			for word in string.gmatch(name, "%d+") do 
				par_indx = par_indx + 1
				input_parameters[par_indx] = word				
			end
			if par_indx > 0 then
				meas_win_start_time = tonumber(input_parameters[1])/1000
			end
			if par_indx > 1 then
				meas_win_length = tonumber(input_parameters[2])/1000
			end
			if par_indx > 2 then
				meas_max_percent = tonumber(input_parameters[3])/100
			end
			break;
		end
	end			

	local track = reaper.GetTrack(0, 0)
	local selected_items_count = reaper.CountSelectedMediaItems(0)
	reaper.Undo_BeginBlock()
	for i = 0, selected_items_count - 1, 1 do
		local item = reaper.GetSelectedMediaItem(0, i)
		local temp_track = reaper.GetMediaItem_Track(item)
		
		if temp_track == track then
			tune_sample(item, tune_mode, meas_win_start_time, meas_win_length, meas_max_percent)
		end
	end	
	reaper.Undo_EndBlock("Tune Selected Samples", 0)
end

main()

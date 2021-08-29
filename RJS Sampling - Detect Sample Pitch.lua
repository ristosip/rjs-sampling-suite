-- Copyright (C) 2021 Risto Sipola
-- License: See LICENSE.txt
--
-- This script is a part of 'RJS Sampling Suite' designed to automate tasks related to sample instrument creation.
-- Running the script detects the pitches (closest musical note) of the samples and labels the samples accordingly. In addition, the script creates a tuning aid track (See details below).
--
-- How to use: 
--             1. Place the samples on the first track of the project. Ideally you have run the 'Chop Samples' script and are ready to go.
--             2. Run the script.
--
-- Tuning Aid: The script creates a track with midi items on it. The midi items correspond to the samples and the detected pitches. The tuning aid track has a synth which can help tuning the samples by ear.
--
-- In case of misdetections: Change the note of the midi item to the correct pitch and run 'Update Sample Info'. If the midi item is missing, create one by recording or copying, create/modify a note and run 'Update Sample Info'.                       
--
-- author: Risto Sipola

note_frequencies = {4434.922, 4186.009, 3951.066, 3729.310, 3520.000, 3322.438, 3135.963, 2959.955, 2793.826, 2637.020, 2489.016, 2349.318, 2217.461, 
2093.005, 1975.533, 1864.655, 1760.000, 1661.219, 1567.982, 1479.978, 1396.913, 1318.510, 1244.508, 1174.659, 1108.731, 
1046.502, 987.7666, 932.3275, 880.0000, 830.6094, 783.9909, 739.9888, 698.4565, 659.2551, 622.2540, 587.3295, 554.3653, 
523.2511, 493.8833, 466.1638, 440.0000, 415.3047, 391.9954, 369.9944, 349.2282, 329.6276, 311.1270, 293.6648, 277.1826, 
261.6256, 246.9417, 233.0819, 220.0000, 207.6523, 195.9977, 184.9972, 174.6141, 164.8138, 155.5635, 146.8324, 138.5913,
130.8128, 123.4708, 116.5409, 110.0000, 103.8262, 97.99886, 92.49861, 87.30706, 82.40689, 77.78175, 73.41619, 69.29566, 
65.40639, 61.73541, 58.27047, 55.00000, 51.91309, 48.99943, 46.24930, 43.65353, 41.20344, 38.89087, 36.70810, 34.64783,
32.70320, 30.86771}
note_frequencies_size = 87

function downsample(input_buf, buf_size, downsampling_factor)

	local output_buf = {}
	local output_buf_idx = 0
	
	for i = 1, buf_size, downsampling_factor do
		output_buf_idx = output_buf_idx + 1
		output_buf[output_buf_idx] = input_buf[i]
	end

	return output_buf, output_buf_idx
end

function upsample(input_buf, buf_size, upsampling_factor)

	local output_buf = {}
	local output_buf_idx = 0
	
	for i = 1, buf_size - 1, 1 do
		local delta = input_buf[i + 1] - input_buf[i]
		local sub_delta = delta / upsampling_factor
		for j = 0, upsampling_factor - 1, 1 do
		output_buf_idx = output_buf_idx + 1
		output_buf[output_buf_idx] = input_buf[i] + sub_delta * j
		end
	end

	return output_buf, output_buf_idx
end

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
				monoBuffer[monoBufferSize] = temp_buffer[j]-- + temp_buffer[j + 1]
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

function measure_pitch(input_buf, buf_size, samplerate)
  
	-- Autocorrelation
    ------------------
	local temp_autocorrelation_sequence = reaper.new_array(buf_size * 2 -1)
	temp_autocorrelation_sequence.clear()
	local autocorrelation_sequence = temp_autocorrelation_sequence.table()
  
	for i = buf_size, 1, -1 do
		for j = 1, buf_size, 1 do
			if (i + (buf_size - j)) < buf_size then
				break; -- break the inner for as only half of the values need to be calculated
			end
			autocorrelation_sequence[i + (buf_size - j)] = autocorrelation_sequence[i + (buf_size - j)] + input_buf[j] * input_buf[i] 
		end
	end
 
	-- finding the second maximum
	------------------------------
	
	-- remove center peak from the search
	local first_minimum_idx = 1 + buf_size - 1
	
	while first_minimum_idx < buf_size * 2 -1 do
	
		first_minimum_idx = first_minimum_idx + 1
	
		if autocorrelation_sequence[first_minimum_idx - 1] > autocorrelation_sequence[first_minimum_idx]
			and autocorrelation_sequence[first_minimum_idx] < autocorrelation_sequence[first_minimum_idx + 1] then
			
			break; -- breaks the while loop
		end
	end

	-- find the second maximum
	
	local maximum = 0
	local maximum_idx = buf_size
	
	for i = first_minimum_idx, buf_size * 2 -1, 1 do
		if autocorrelation_sequence[i] > maximum then
			maximum = autocorrelation_sequence[i]
			maximum_idx = i
		end
	end
	
	local lag = maximum_idx - buf_size -- interval between the center peak and the second maximum is the 'lag' ---> period of the input signal
	
	if(samplerate ~= 0) then
		return 1/((1/samplerate) * lag); 
	else
		return -1
	end
end

function main()

	local itemCount = reaper.CountTrackMediaItems(reaper.GetTrack(0, 0))
	
	if itemCount > 0 then
	
		reaper.Undo_BeginBlock()
		 
		reaper.InsertTrackAtIndex(1, true)
		local tuning_aid_track = reaper.GetTrack(0, 1)
		track_count = reaper.CountTracks(0)
		reaper.GetSetMediaTrackInfo_String(tuning_aid_track, 'P_NAME', "Tuning Aid", true)	
		reaper.TrackFX_AddByName(tuning_aid_track, "ReaSynth", false, -1)
		reaper.TrackFX_SetParam(tuning_aid_track, 0, 3, .55) -- change these numbers to change the synth sound
		reaper.SetMediaTrackInfo_Value(tuning_aid_track, "D_VOL", 0.25)
	
		for i = 0, itemCount - 1, 1 do
		
			local item = reaper.GetTrackMediaItem(reaper.GetTrack(0, 0), i)
			local take = reaper.GetTake(item, 0)
			local resampling_factor = 1 / 8
			local snippet_length = 0.060
			local start_time_sec = 0.800
			local resampledBuffer, resampledBufferSize

			local audio_buffer, buffer_size, samplerate = get_audio_buffer(take, start_time_sec, snippet_length)
			
			if buffer_size ~= -1 and resampling_factor ~= 0 then
				local testBuffer, testBufferSize = downsample(audio_buffer, buffer_size, 1 / resampling_factor)				
				local test_pitch = measure_pitch(testBuffer, testBufferSize, samplerate * resampling_factor)				
				if test_pitch < 100 then
					resampling_factor = 1 / 8
					snippet_length = 0.060
				end
				if test_pitch > 100 then
					resampling_factor = 1 / 4
					snippet_length = 0.03
				end
				if test_pitch > 200 then
					resampling_factor = 1 / 2
					snippet_length = 0.015
				end
				if test_pitch > 400 then
					resampling_factor = 1
					snippet_length = 0.0075
				end
				if test_pitch > 800 then
					resampling_factor = 2
					snippet_length = 0.00375
				end				
				audio_buffer, buffer_size, samplerate = get_audio_buffer(take, start_time_sec, snippet_length)
				if resampling_factor > 1 then
					resampledBuffer, resampledBufferSize = upsample(audio_buffer, buffer_size, resampling_factor)
				end
				if resampling_factor < 1 then
					resampledBuffer, resampledBufferSize = downsample(audio_buffer, buffer_size, 1 / resampling_factor)
				end
				if resampling_factor == 1 then
					resampledBuffer = audio_buffer
					resampledBufferSize = buffer_size
				end
			end
			
			if resampledBufferSize ~= nil and resampledBufferSize ~= -1 and resampling_factor ~= 0 then
					
				local pitch = measure_pitch(resampledBuffer, resampledBufferSize, samplerate * resampling_factor)

				if pitch ~= -1 then
					
					local note = 255
					local target_pitch = -1
					local done_searhing = false
					local note_idx = 2
					
					while(done_searhing == false) do
						if math.abs(pitch - note_frequencies[note_idx - 1]) > math.abs(pitch - note_frequencies[note_idx])
							and math.abs(pitch - note_frequencies[note_idx]) < math.abs(pitch - note_frequencies[note_idx + 1]) then
							note = (88 - note_idx) - 1 + 23 --midi note number (notice: the note_freq table has padding notes, thus "-1")
							target_pitch = note_frequencies[note_idx]
							done_searhing = true
						end		
						note_idx = note_idx + 1
			
						if note_idx == note_frequencies_size - 1 then
							-- failed search
							done_searhing = true
						end
					end
			
					-- colors the item based on the midi note number, that is the output of this script: R component has the pure note number, others are manipulated for artistic effect
					reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", reaper.ColorToNative(note, math.abs(math.floor((255 - (note%12)/12 * 255))),math.floor((note%12)/12 * 255/2))|0x1000000)
					reaper.UpdateArrange()
					update_group_member_items(item, note)
					
					if target_pitch ~= -1 then
						-- piecewise linear approximation of the adjustment in 'cents'
						local ratio = pitch / target_pitch
						local delta = 1 - ratio
						local cent_approximation = delta / 0.0005946 -- https://en.wikipedia.org/wiki/Cent_(music)#Piecewise_linear_approximation
			
						--reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH", cent_approximation / 100)
						 
						local temp_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
						local temp_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
						local temp_endtime = temp_pos + temp_length
						local midi_item = reaper.CreateNewMIDIItemInProj(tuning_aid_track, temp_pos, temp_endtime)
						local length_in_midi_ticks = temp_length / (60 / reaper.Master_GetTempo() / 960)
						reaper.MIDI_InsertNote(reaper.GetTake(midi_item, 0), false, false, 0, length_in_midi_ticks, 1, note, 80)
					end
				end	
			end
		end
		reaper.Undo_EndBlock("Detect Sample Pitch", 0)
	end
end

main()


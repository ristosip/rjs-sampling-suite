-- This script is a part of 'RJS Sampling Suite' designed to automate tasks related to sample instrument creation.
-- Running the script counts the items on the first track and prints a detailed inventory.
--
-- Copyright (C) 2021 Risto Sipola
-- 'RJS Sampling Suite' script collection is licensed under the GNU General Public License v3.0: See LICENSE.txt
--
-- How to use: 
--             1. Run the script.
--             2. Optional: Use the dialog box to input plan data. Press OK.
--             3. The script prints the inventory and marks questionable items if there are any.
--
-- author: Risto Sipola

note_letters_ucase = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }

note_list = {}
pass_list = {}

function init_lists()
	for i = 1, 109, 1 do
		note_list[i] = 0
		pass_list[i] = 0
	end
end

function get_user_input()
	local vel_layers
	local round_robins

	local retval, retvals_csv = reaper.GetUserInputs("Take a Sample Inventory", 2, "Planned Velocity Layers:,Planned Round Robins:", "-"..",".."-")

	if retval == true then
		vel_layers, round_robins = retvals_csv:match("([^,]+),([^,]+)")
		vel_layers = tonumber(vel_layers)
		round_robins = tonumber(round_robins)
	end

	return vel_layers, round_robins, not retval
end

function mark_problem_item(item, midi_note)
	local text = ""
	local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
	if midi_note == 0 then
		text = "Possibly an unlabeled item"
	elseif midi_note > 0 and midi_note <= 108 then
		text = "Possibly a failed labeling"
	else
		text = "Outside the normal midirange"
	end
	
	reaper.AddProjectMarker(0, false, pos, 0, text, 0)
end

function mark_problem_items(midi_note, track, item_count)
	for i = 0, item_count - 1, 1 do
		local item = reaper.GetTrackMediaItem(track, i)
		local item_color = reaper.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
		local r, g, b = reaper.ColorFromNative(item_color)
		local out_of_range_items_count = 0
		if r == midi_note then
			mark_problem_item(item, r)
		end
	end
end

function get_note_string(midi_note_num)
	local note_string = ""
	local note = midi_note_num % 12 + 1
	note_string = note_letters_ucase[note]
	local octave = math.floor(midi_note_num / 12) - 1
	note_string = note_string..octave
	return note_string
end

function print_inventory_data(item_count, vel_layers, round_robins, out_of_range_items_count, clean_pass)
	local pass_string
	
	if clean_pass then
		pass_string = "SUCCESS:  The sample count and the labeling match the plan."
	else
		pass_string = "FAIL:   A mismatch between the sample count and the plan."
	end

	reaper.ShowConsoleMsg("\n")
	reaper.ShowConsoleMsg("----------------------------\n")
	reaper.ShowConsoleMsg("------SAMPLE INVENTORY------\n")
	reaper.ShowConsoleMsg("----------------------------\n")
	reaper.ShowConsoleMsg("\n")
	reaper.ShowConsoleMsg("Total item count:   "..item_count.."\n")
	reaper.ShowConsoleMsg("\n")
	
	if vel_layers ~= nil and round_robins ~= nil then
		local total = vel_layers * round_robins
		reaper.ShowConsoleMsg("Plan:   "..vel_layers.."  velocity layers,  "..round_robins.."  round robins.".."\n")	
		reaper.ShowConsoleMsg("\n")
		reaper.ShowConsoleMsg(pass_string)
		reaper.ShowConsoleMsg("\n")
		reaper.ShowConsoleMsg("\n")
	end
	reaper.ShowConsoleMsg("---------- Notes ----------\n")
	reaper.ShowConsoleMsg("\n")

	for i = 1, 109, 1 do
		local note_string = get_note_string(i - 1)
		local sample_count = note_list[i]
		pass_string = ""
		if sample_count > 0 then
			sample_count = tostring(sample_count)
			local pass_code = pass_list[i]
			if pass_code == 1 then
				pass_string = "OK"
			elseif pass_code == 2 then
				pass_string = "TOO MANY SAMPLES"
			elseif pass_code == 3 then
				pass_string = "SAMPLES MISSING"
			elseif pass_code == 4 then
				pass_string = "QUESTIONABLE"
			end
			if i == 1 then
				pass_string = pass_string.." / POSSIBLY UNLABELED GARBAGE"
			end
			reaper.ShowConsoleMsg("   Note:   "..note_string.."   Amount:  "..sample_count.."   "..pass_string)
			reaper.ShowConsoleMsg("\n")		
		end
	end
		if out_of_range_items_count > 0 then
			reaper.ShowConsoleMsg("   Out-of-range notes:   "..out_of_range_items_count)
			reaper.ShowConsoleMsg("\n")
		end
		reaper.ShowConsoleMsg("\n")
		reaper.ShowConsoleMsg("----------- END ----------\n")
		reaper.ShowConsoleMsg("\n")
end

function main()
	init_lists()
	local first_track = reaper.GetTrack(0, 0)
	if first_track ~= nil then
		local vel_layers, round_robins, cancelled = get_user_input()
		if not cancelled then
			local item_count = reaper.CountTrackMediaItems(first_track)
			local out_of_range_items_count = 0
			for i = 0, item_count - 1, 1 do
				local item = reaper.GetTrackMediaItem(first_track, i)
				local item_color = reaper.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
				local r, g, b = reaper.ColorFromNative(item_color)
				if r >= 0 and r <= 108 then
					note_list[r + 1] = note_list[r + 1] + 1
				else
					mark_problem_item(item, r)
					out_of_range_items_count = out_of_range_items_count + 1
				end
			end
			local clean_pass = true
			if vel_layers ~= nil and round_robins ~= nil then
				local sample_count = vel_layers * round_robins
				for i = 1, 109, 1 do
					if note_list[i] == sample_count then
						pass_list[i] = 1 -- pass
					elseif note_list[i] > sample_count then
						clean_pass = false
						pass_list[i] = 2 -- too many samples
					elseif note_list[i] >= sample_count / 2 and note_list[i]  < sample_count then
						clean_pass = false
						pass_list[i] = 3 -- missing some samples
					elseif note_list[i] < sample_count / 2 and note_list[i] > 0 then
						clean_pass = false
						pass_list[i] = 4 -- questionable
						mark_problem_items(i - 1, first_track, item_count)
					end
				end
			end
			print_inventory_data(item_count, vel_layers, round_robins, out_of_range_items_count, clean_pass, out_of_range_items_count)
		end
	end
end

main()
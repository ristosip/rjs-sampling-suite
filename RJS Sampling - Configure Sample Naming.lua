-- This script is a part of 'RJS Sampling Suite' designed to automate tasks related to sample instrument creation.
-- Running the script names items/samples based on user input and the project arrangement. 
-- This gives the user control over the naming convention/configuration of the sample audio files.
--
-- Copyright (C) 2022 Risto Sipola
-- 'RJS Sampling Suite' script collection is licensed under the GNU General Public License v3.0: See LICENSE.txt
--
-- 
-- How to use:
--             1. Preparation: 
--                              * 'Arrange Samples for Export' script must be run before using this script.
--                              * Adjust item selections if needed. Only selected items will be affected.
--             2. Run the script:
--                              * Set the naming configuration using the input dialog. 
--                              * Use the 'keywords' available. (Details below.)
--             3. New item names are set: 
--                              * Render the samples using '$item' wildcard.
--
-- About keywords:
--                   Keywords refer to bits of information in the arrangement, such as a rootnote, or a velocity layer, for instance.
--                   A list of the available keywords is found below in the 'Default Settings' section.
--                   If you often/always use the same configuration, use 'default_sample_naming_configuration' variable for convenience.
--                   Default mic names such as 'Mic1' can be replaced using the variables found below. 
--
-- How does it work? Each keyword provided is replaced with the actual information that the script finds in the arrangement.
--                   The order of the keywords can be changed freely. Keywords can be included or omitted freely.
-- 
-- Why use?          Some samplers expect a certain kind of naming convention which they can use for automapping samples.
--
-- author: Risto Sipola

------ Default Settings ------

default_sample_naming_configuration = "groupmicrr_lonote_rootnote_hinote_lovel_hivel"

-- Keywords you can use:
------------------------
--
-- lonote                        = midi note number of the lowest stretched note
-- hinote                        = midi note number of the highest stretched note
-- rootnote                      = midi note number of the root note
-- note                          = same as 'rootnote' - midi note number of the root note
--
-- lonotename                    = letter symbol of the lowest stretched note (for example A2)
-- hinotename                    = letter symbol of the highest stretched note
-- rootnotename                  = letter symbol of the root note
-- notename                      = same as 'rootnotename' - letter symbol of the root note
--
-- lovel                         = the lowest midi velocity value of the note/item/zone
-- hivel                         = the highest midi velocity value of the note/item/zone
-- velnum                        = ordering number of the velocity layer, for example, '5' meaning the fifth velocity layer
--
-- mic                           = microphone information
-- micnum                        = number of the microphone
--
-- rr                            = round robin information = round robin tag + round robin number
-- rrnum                         = round robin number
--
-- group                         = group information (does not include mic or rr info)
--
-- $[custom keyword]              = a freely chosen word preceded by the character '$'. When the script encounters a custom keyword word 
--                                 it goes through the item notes to see if there is a matching word there. If a match is found then 
--                                 the characters (words and numbers) following the keyword will be used in the item name.
--                                  A comma ',' is used to mark the end of the info. Note! '$' is not needed/used in the item notes.
--                                 Example: 
--                                           'mycustomkeyword extrainformation 101,' is written in an item's notes. 
--                                           Now, if the naming configuration is, for instance, 'notename Vvelnum $mycustomkeyword'
--                                                then the item name will be 'A2 V5 extrainformation 101'
--                                            
--                                 Example2: 
--                                            item notes:              'myfirstkeyword custominfo, mysecondkeyword morecustomstuff,'
--                                            naming configuration:    '$mysecondkeyword_lonote_rootnote_hinote_$myfirstkeyword'
--                                            resulting item name:     'morecustomstuff_60_62_64_custominfo'
--
--                                 Affecting a whole group of items: the custom keyword is written only into the notes of the first item.
--                                 The keyword is prefixed with the word 'group'. For example, 'mykeyword' -> 'groupmykeyword'.
--                                 
--                                 Example:   the first item's notes:   'groupcustomkeyword custominfo'
--                                            naming configuration:     'notename $customkeyword'
--                                            resulting item names:     '[notename] custominfo'
--                                            (items inside the group can override the group effect by using the same keyword for themselves)
--                                            (let say one item had 'customkeyword exception'. This item will be named '[notename] exception')
--
--
-- [other text]                  = [other text] will be added as is
--
------------------------

-- Example settings:
------------------------
--
-- groupmicrr_lonote_rootnote_hinote_lovel_hivel                  ---->  'ViolinMic1RR3_60_62_64_80_127.wav'
--
-- notename Vvelnum rr group mic                                  ---->  'D4 V2 RR3 Violin Shure57.wav' (In this example 'default_mic1_name = "Shure57"')
--
-- randomtext note - group - round robin rrnum - velocity velnum  ---->  'randomtext D4 - Violin - round robin 3 - velocity 2.wav' 
--
-----------------------


default_mic1_name = "Mic1"       -- These can be replaced with actual microphone names, for instance, 'Shure57' or something.
default_mic2_name = "Mic2"
default_mic3_name = "Mic3"
default_mic4_name = "Mic4"
default_mic5_name = "Mic5"

default_round_robin_tag = "RR"   -- This is the tag that appears in the file name before the round robin number: .._RR3_.. or _rr3_.. or .._roundrobin3_ or..

default_want_upper_case_note_letters = true  -- Switch between upper and lower case note symbols: A2 vs a2.

------------------------------
--  end of default settings --
------------------------------

note_letters_ucase = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }
note_letters_lcase = { "c", "c#", "d", "d#", "e", "f", "f#", "g", "g#", "a", "a#", "b" }

function open_user_input_dialog()
	local naming_format = default_sample_naming_configuration
	local mic1_name = default_mic1_name
	local mic2_name = default_mic2_name
	local dialog_title = "Configure Sample Naming (Keywords: group, lonote, rootnote, hinote, lovel, hivel, notename, velnum, mic, rr, $[custom])"
	local retval, retvals_csv = reaper.GetUserInputs(dialog_title, 3, "Naming Configuration:,Mic1 name:,Mic2 name:,extrawidth=450", tostring(naming_format)..","..tostring(mic1_name)..","..tostring(mic2_name))

	if retval == true then
		naming_format, mic1_name, mic2_name = retvals_csv:match("([^,]+),([^,]+),([^,]+)")
		default_sample_naming_configuration = naming_format
		default_mic1_name = mic1_name
		default_mic2_name = mic2_name
	end
	return not retval
end

function parse_track_name_for_rr_num(track_name)
	
	local num1
	local num2
	local rr_num
	local digit_counter = 0
	
	local identifier_found = false
	if track_name ~= nil then
		for word in string.gmatch(track_name, "%a+") do 
			if string.find(word, "RR") ~= nil then
				identifier_found = true
				break;
			end
		end
		if identifier_found then
			for word in string.gmatch(track_name, "%d+") do 
				digit_counter = digit_counter + 1
				if digit_counter == 1 then
					num1 = tonumber(word)
				end
				if digit_counter == 2 then
					num2 = tonumber(word)
				end
			end
			
			if num2 ~= nil then
				rr_num = num2
			else
				rr_num = num1
			end
		end
	end
	return rr_num
end

function parse_group_info_for_mic_num(group_info)
	local num1
	local num2
	local mic_num
	local digit_counter = 0
	
	local identifier_found = false
	
	for word in string.gmatch(group_info, "%a+") do 
		if string.find(word, "Mic") ~= nil then
			identifier_found = true
			break;
		end
	end
	if identifier_found then
		for word in string.gmatch(group_info, "%d+") do 
			digit_counter = digit_counter + 1
			if digit_counter == 1 then
				num1 = tonumber(word)
			end
			if digit_counter == 2 then
				num2 = tonumber(word)
			end
		end
		
		if num2 ~= nil then
			mic_num = num1
		else
			mic_num = num1
		end
	end
	return mic_num
end

function parse_track_name_for_velocity_values(track_name)
	local loVel
	local hiVel
	local digit_counter = 0
	
	for word in string.gmatch(track_name, "%d+") do 
		digit_counter = digit_counter + 1
		if digit_counter == 1 then
			loVel = tonumber(word)
		end
		if digit_counter == 2 then
			hiVel = tonumber(word)
		end
	end
	
	return loVel, hiVel
end

function parse_region_name_for_note_values(region_name)
	local rootNote
	local loNote
	local hiNote
	local digit_counter = 0
	
	for word in string.gmatch(region_name, "%d+") do 
		digit_counter = digit_counter + 1
		if digit_counter == 1 then
			loNote = tonumber(word)
		end
		if digit_counter == 2 then
			rootNote = tonumber(word)
		end
		if digit_counter == 3 then
			hiNote = tonumber(word)
		end
	end
	
	return loNote, rootNote, hiNote
end

function get_region_name(item)
	local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
	local retval, num_markers, num_regions = reaper.CountProjectMarkers(0)
	local ret_name = ""
	for i = 0, num_markers + num_regions - 1, 1 do
		local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
		if isrgn then
			if math.abs(pos - item_pos) < 0.01 then
				ret_name = name
			end
		end
	end
	return ret_name
end

function convert_note_num_to_note_name(midi_note_num)
	if midi_note_num ~= nil then
		local note = midi_note_num % 12 + 1
		if default_want_upper_case_note_letters then
			note_string = note_letters_ucase[note]
		else
			note_string = note_letters_lcase[note]
		end
		local octave = math.floor(midi_note_num / 12) - 1
		note_string = note_string..octave
	end
	return note_string
end

function get_item_custom_keyword_value(notes, keyword)
	local original_notes = notes
	local sub_strings = {}
	local sub_strings_idx = 0
	local comma_idx = 0
	local digit_counter = 0
	local ret_value
	
	while comma_idx ~= nil do
		comma_idx = string.find(notes, ",", 1) 
		if comma_idx ~= nil then
			sub_strings_idx = sub_strings_idx + 1
			sub_strings[sub_strings_idx] = string.sub(notes, 1, comma_idx)  
			notes = string.gsub(notes, sub_strings[sub_strings_idx], "")			
		else
			if notes ~= nil then
				sub_strings_idx = sub_strings_idx + 1
				sub_strings[sub_strings_idx] = notes
			end
		end
	end
	local identifier_found = false
	for i = 1, sub_strings_idx, 1 do
		for word in string.gmatch(sub_strings[i], "%a+") do 
			if string.find(word, keyword) ~= nil then
				identifier_found = true
				break;
			end
		end
		if identifier_found then
			sub_strings[i] = string.gsub(sub_strings[i], ",", "")
			sub_strings[i] = string.gsub(sub_strings[i], " "..keyword.." ", "") -- removing spaces (different permutations covered)
			sub_strings[i] = string.gsub(sub_strings[i], " "..keyword, "")
			sub_strings[i] = string.gsub(sub_strings[i], keyword.." ", "")
			sub_strings[i] = string.gsub(sub_strings[i], keyword, "")
			ret_value = sub_strings[i]
			break
		end
	end
		
	return ret_value
end

function get_first_item_of_the_group(member_item)
	local item_track = reaper.GetMediaItemTrack(member_item)
	local parent_track = reaper.GetParentTrack(item_track)
	local parent_track_num = reaper.GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER")
	local first_item
	local first_track_of_the_group = reaper.GetTrack(0, parent_track_num)
	if first_track_of_the_group ~= nil then
		first_item = reaper.GetTrackMediaItem(first_track_of_the_group, 0)
	end
	return first_item
end

function change_item_name(item)
	local new_item_name = default_sample_naming_configuration
	local retval, item_notes = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
	local take = reaper.GetTake(item, 0)
	local track = reaper.GetMediaItemTrack(item)
	local parent_track = reaper.GetParentTrack(track)
	local track_num = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
	local parent_track_num = reaper.GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER")
	local first_item_in_the_group = get_first_item_of_the_group(item)
	local retval_, first_item_notes = reaper.GetSetMediaItemInfo_String(first_item_in_the_group, "P_NOTES", "", false)
	local vel_layer_num
	if track_num ~= nil and parent_track_num ~= nil and track_num > 0 and parent_track_num > 0 then
		vel_layer_num = tostring(math.floor(track_num - parent_track_num))
	else
		vel_layer_num = ""
	end
	local retval, group_info = reaper.GetTrackName(parent_track)
	local retval2, track_name = reaper.GetTrackName(track)
	local rr_num, rr_tag, mic_num, loNote, rootNote, hiNote, loVel, hiVel
	if group_info ~= nil then	
		rr_num = parse_track_name_for_rr_num(group_info)		
		mic_num = parse_group_info_for_mic_num(group_info)
	else
		group_info = ""
	end	
	if rr_num ~= nil then
		group_info = string.gsub(group_info, "RR"..rr_num, "")	
		rr_num = tostring(rr_num)
		rr_tag = default_round_robin_tag..rr_num
	else
		rr_num = ""
		rr_tag = ""
	end
	if mic_num ~= nil then
		group_info = string.gsub(group_info, "Mic"..mic_num, "")
		mic_num = mic_num
	else
		mic_num = ""
	end	
	
	if track_name ~= nil and track_name ~= "" then
		loVel, hiVel = parse_track_name_for_velocity_values(track_name)
		if loVel ~= nil then
			loVel = tostring(loVel)
		end
		if hiVel ~= nil then
			hiVel = tostring(hiVel)
		end
	end
	if loVel == nil then
		loVel = ""
	end
	if hiVel == nil then
		hiVel = ""
	end
	
	local region_name = get_region_name(item)
	local lo_note_name, root_note_name, hi_note_name
	if region_name ~= "" then
		loNote, rootNote, hiNote = parse_region_name_for_note_values(region_name)
		lo_note_name = convert_note_num_to_note_name(loNote)
		root_note_name = convert_note_num_to_note_name(rootNote)
		hi_note_name = convert_note_num_to_note_name(hiNote)
	end
	if loNote ~= nil then
		loNote = tostring(loNote)
	else
		loNote = ""
	end	
	if rootNote ~= nil then
		rootNote = tostring(rootNote)
	else
		rootNote = ""
	end	
	if hiNote ~= nil then
		hiNote = tostring(hiNote)
	else
		hiNote = ""
	end		
	if lo_note_name == nil then
		lo_note_name = ""
	end	
	if root_note_name == nil then
		root_note_name = ""
	end
	if hi_note_name == nil then
		hi_note_name = ""
	end

	local mic_name
	if mic_num == 1 then
		mic_name = default_mic1_name
	elseif mic_num == 2 then
		mic_name = default_mic2_name
	elseif mic_num == 3 then
		mic_name = default_mic3_name
	elseif mic_num == 4 then
		mic_name = default_mic4_name
	elseif mic_num == 5 then
		mic_name = default_mic5_name
	else
		mic_name = ""
	end
		
	local temp = new_item_name
	
	new_item_name = string.gsub(new_item_name, "group", group_info)	
	
	new_item_name = string.gsub(new_item_name, "rrnum", rr_num)
	new_item_name = string.gsub(new_item_name, "rr", rr_tag)

	new_item_name = string.gsub(new_item_name, "micnum", tostring(mic_num))
	new_item_name = string.gsub(new_item_name, "mic", mic_name)
	new_item_name = string.gsub(new_item_name, "velnum", vel_layer_num)
	
	new_item_name = string.gsub(new_item_name, "lonotename", lo_note_name)
	new_item_name = string.gsub(new_item_name, "rootnotename", root_note_name)
	new_item_name = string.gsub(new_item_name, "hinotename", hi_note_name)
	new_item_name = string.gsub(new_item_name, "notename", root_note_name)
	
	new_item_name = string.gsub(new_item_name, "lonote", loNote)
	new_item_name = string.gsub(new_item_name, "rootnote", rootNote)
	new_item_name = string.gsub(new_item_name, "hinote", hiNote)
	new_item_name = string.gsub(new_item_name, "note", rootNote)

	new_item_name = string.gsub(new_item_name, "lovel", loVel)
	new_item_name = string.gsub(new_item_name, "hivel", hiVel)
	
	-- handling custom keywords
		
	temp = string.gsub(temp, "group", "")	
	
	temp = string.gsub(temp, "rrnum", "")
	temp = string.gsub(temp, "rr", "")

	temp = string.gsub(temp, "micnum", "")
	temp = string.gsub(temp, "mic", "")
	temp = string.gsub(temp, "velnum", "")
	
	temp = string.gsub(temp, "lonotename", "")
	temp = string.gsub(temp, "rootnotename", "")
	temp = string.gsub(temp, "hinotename", "")
	temp = string.gsub(temp, "notename", "")
	
	temp = string.gsub(temp, "lonote", "")
	temp = string.gsub(temp, "rootnote", "")
	temp = string.gsub(temp, "hinote", "")
	temp = string.gsub(temp, "note", "")

	temp = string.gsub(temp, "lovel", "")
	temp = string.gsub(temp, "hivel", "")
	
	
	for word in string.gmatch(temp, "%a+") do
		-- check for $
		local is_custom_keyword = false
		local start_idx, end_idx = string.find(new_item_name, word)
		if start_idx > 1 then
			local preceding_char = string.sub(new_item_name, start_idx - 1, start_idx - 1)
			if preceding_char == "$" then
				is_custom_keyword = true
			end
		end
		--
		if is_custom_keyword then	
			local custom_info_group
			local custom_info
			if first_item_notes ~= nil then			
				custom_info_group = get_item_custom_keyword_value(first_item_notes, "group"..word)
			end	
			if item_notes ~= nil then			
				custom_info = get_item_custom_keyword_value(item_notes, word)
			end
			if custom_info ~= nil and item == first_item_in_the_group then
				custom_info = string.gsub(custom_info, " group ", "")
				custom_info = string.gsub(custom_info, " group", "")
				custom_info = string.gsub(custom_info, "group ", "")
				new_item_name = string.gsub(new_item_name, "$"..word, custom_info)
			elseif custom_info ~= nil then
				new_item_name = string.gsub(new_item_name, "$"..word, custom_info)
			elseif custom_info_group ~= nil then
				new_item_name = string.gsub(new_item_name, "$"..word, custom_info_group)
			else
				new_item_name = string.gsub(new_item_name, "$"..word, "")
			end
		else
			-- the text is left unchanged
		end
	end
	
	reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", new_item_name, true)	
end

function main()
	local cancelled = open_user_input_dialog()
	
	if not cancelled then	
		local sel_item_count = reaper.CountSelectedMediaItems(0)
		
		for i = 0, sel_item_count - 1, 1 do
			local item = reaper.GetSelectedMediaItem(0, i)
			change_item_name(item)
		end
	end
end

main()
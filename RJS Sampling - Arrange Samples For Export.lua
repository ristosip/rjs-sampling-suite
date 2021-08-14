-- This script is a part of 'RJS Sampling Suite' designed to automate tasks related to sample instrument creation.
-- Running the script creates tracks and regions and moves the samples on the new tracks. The regions and tracks are named so that the rendered samples can easily be automapped in Kontakt. Utilize Reaper's file naming "wildcards" when rendering! (See details below.)
--
-- How to use: 
--             1. Preparation: The (main mic) samples are labeled and lined up on the first track, ideally, after running 'Chop Samples' and 'Detect Sample Pitch' or 'Assign Percussion Keys'.
--             2. Create a timeline marker that serves as an input command for the script. (See details below.)
--             3. Run the script.
--             4. The samples are now arranged and ready for export. Open Reaper's 'Render' dialog and type in appropriate settings. Render.
--
-- Preparation details:
--             - The script assumes that the samples on the first track are ordered so that round robin samples are next to each other and velocity layers go from low to high.
--               * The script 'Sort Items Based on Note and Energy' can help with the ordering.
--               * Example:
--
--               Visualization:    [N_1 Vel_1 RR_1]    [N_1 Vel_1 RR_2]    [N_1 Vel_2 RR_1]    [N_1 Vel_2 RR_2]    [N_2 Vel_1 RR_1]    [N_2 Vel_1 RR_2]    [N_2 Vel_2 RR_1]    [N_2 Vel_2 RR_2]
--
--
--                                 [    ] = sample
--                                  N_X   = Note number X
--                                  Vel_X = Velocity Layer number X
--                                  RR_X  = Round Robin number X
--
-- Recommended rendering settings:
--                               Source: 'Selected media items via master'
--                               File name: '$parenttrack\$parenttrack_$region_$track'
-- 
-- Input Command:
--             'arr [velocity layer structure] [number of round robins] [stretching policy] [offset amount] [articulation name] [pitch handling] [dynamic level points]'
--
--
-- Examples of valid input commands:
--              Default settings: no input command needed, just run the script!       Default: 'arr 1 1 Default'
--              Long notes (let's name them 'Long') with 2 velocity layers:                    'arr 2 1 Long'
--              Same as above but only want to use upward stretching:                          'arr 2 1 onlyup Long'
--              Same as above but don't want any stretching:                                   'arr 2 1 nostretch Long'
--              Want to push the velocity layers up by adding an offset of 20:                 'arr 2 1 offtwenty Long'
--              Want to stretch the highest and the lowest samples to cover the midi keyboard: 'arr 2 1 stretch Long'
--              3 velocity layers, 2 round robins, only down stretching and an offset of 50:   'arr 3 2 onlydown offfifty Long'
--
--
-- A Command that covers most use cases:
--              'arr [num low layers] [num highest layers] offxxxxx [articulation name] [dynamic level point]'
--
--               This command allows you to easily create various velocity distributions:
--               * Use [num highest layers] to target the higher velocity section (default range is 116-127). You can also omit this number entirely!
--               * Use [num lower layers] to target the lower velocity section (default range is 1-115). (If you omit [num highest layers], you will target the full range 1-127)
--               * Use 'offxxxx' to push the layers up (by stretching the lowest layer). The lowest velocities are often not as important as the middle velocities, thus, you might want to concentrate your velocity layers higher.
--                 ** 'offxxxxx' goes from zero to sixty in increments of five: offzero, offfive, default, offfifteen, offtwenty, offtwentyfive.......offsixty.
--                 ** The default value is an offset of 10 velocity points. If you don't want any offsetting, you need to explicitly use 'offzero'!
--               * Use [dynamic level point] to determine the velocity point that divides low and high layer sections.
--               
--               Example: 'arr 3 1 1 offthirty Long 116'
--
--               Visualization:
--
--                             127                 ---
--                                                  |
--                                                  |     Highest velocity layer [num highest layers]
--                                                  |
--    dynamic level point -->  116                 ---
--                                                  |
--                                                  |     3rd velocity layer (of the [num low layers])
--                                                  |
--                              87                 ---
--                                                  |
--                                                  |     2nd velocity layer
--                                                  |
--                              59                 ---
--                                                  |
--                                                  |
--                                                  |
--                              30           ---    |     1st velocity layer = offset + (115 - offset)/3 = 30 + ~28 = 58
--                                            |     |
--                                     offset |     |      
--                                            |     |
--                               1           ---   ---
--
--
--
--
-- Input Command details (for expert use):
--
--              [velocity layer structure]
--              - The structure consists of Dynamic Level Points and layers between the points.
--                * This system enables the user to distribute the velocity scale unevenly between the samples.
--                * Dynamic Level Points are velocity points 'mp' 'mf' 'f' and 'ff' that divide the velocity scale into sections.
--                * Each velocity section is further divided into actual velocity layers. Visualization: 1..[vel layers]..mp..[vel layers]..mf..[vel layers]..f..[vel layers]..ff..[vel layers]..127
--                * The values of the velocity points depend on how many sections the user defines. The user can define up to 5 sections. 
--                * Example: 'arr 2 3 1 1 Long'. This marker defines 3 sections. The lowest dynamic section has 2 velocity layers, the middle section has 3, and the loudest section has only 1 layer. (The last '1' in the command is the amount of round robins.)
--                  The script would automatically assign two velocity points based on this command: 'f' = 90 and 'ff' = 116.
--                  This means that the velocity range 1-89 would be divided into 2 layers, the range 90-115 would have 3 layers, and the range 116-127 would be the loudest velocity layer.
--              - The split point values of the sections:
--                * Only one velocity layer value given (e.g. 'arr 2 1 Long'): No section split points, the range 1-127 is evenly distributed between the layers. 
--                * Two velocity layer values given (e.g. 'arr 3 2 1 Long'): One split point: ff = 116. The range 1-115 is evenly distributed between the lowest layers, the range 116-127 is evenly distributed between the highest layers.
--                * Three velocity layer values given (e.g. 'arr 3 3 2 1 Long'): Two split points: ff = 116 and f = 90. 'arr 3 3 2 1 Long' --> The range 1-89 is divided into three layers, the range 90-115 is evenly divided into three layers, the range 116-127 is evenly divided into two layers.
--                * Four velocity layer values given (e.g. 'arr 3 3 2 1 1 Long'): Three split points: ff = 116, f = 96, mf = 71.
--                * Five velocity layer values given (e.g. 'arr 2 3 3 2 1 1 Long'): Four split points: ff = 116, f = 101, mf = 81, mp = 51.
--
--              [stretching policy]
--              - Options:
--                * default, 'preferdown': samples are stretched both upward and downward, but stretching down is preferred if a space between samples covers an odd number of notes.
--                  ** Example: Samples C and E: C would be stretched up to C#, E would be stretched down to D.
--                * 'preferup': Samples are stretched both upward and downward, but stretching up is preferred. 
--                  ** Example: Samples C and E: C would be stretched up to D, E would be stretched down to Eb.
--                * 'onlyup': Samples are stretched only upward.
--                * 'onlydown': Samples are stretched only downward.
--                * 'nostretch': Samples are not stretched at all.
--                * 'stretch': The outer most samples are stretched up and down to cover the whole midi keyboard. Unlike the others this does not refer to inter-note stretching! 'arr 1 1 stretch onlydown Long' is a valid command.
--
--              [offset amount]
--              - Options: 'offxxxxx' goes from zero to sixty in increments of five: offzero, offfive, default, offfifteen, offtwenty, offtwentyfive.......offsixty.
--                ** Example: 'arr 1 1 offfortyfive Long'
--                ** The default value is an offset of 10 velocity points. If you don't want any offsetting, you need to explicitly use 'offzero'!
--
--              [pitch handling]
--              - By default the script takes the midi note labelling of the samples into account when moving the samples onto the new tracks. This makes sure that the note values of the regions and the samples match.
--              - 'nopitch' makes the script ignore the midi note labelling of the samples. The script will simply move through the samples in order. This may result in a mismatch between the regions and the arranged samples.
-- 
--              [dynamic level points] 
--              - The parameter can be used to override the default values of the Dynamic Level Points.
--              - The points must be listed from 'ff' to 'mp'. The points that are not used can be omitted.
--                ** Example: 'arr ... 120 90 80 50' , 'arr ... 120 90 80' , 'arr ... 120 90' , 'arr ... 120' are all valid commands.
--                           'arr ... 120 50 80' is an invalid command (because 50 < 80).
--              - The user must make sure not to create invalid structures by assigning custom values that conflict with the default values.
--                ** Example: 'arr 2 2 2 1 Long 80' will cause a conflict. The 'ff' point is set to a custom value of 80 while the 'f' point's default value is 91. The script will run anyway and create an invalid structure.
--              - Minimum value is 40.
--
-- author: Risto Sipola

--default offset
offset = 10
----------------

-- enable the use of default settings when no input command is given
default_settings_enabled = true

-----------------------
-----------------------
-- default Dynamic Level Points

-- 1 point system
default_ff_point_1 =  116
-- 2 point system
default_f_point_2 = 91
default_ff_point_2 =  116
-- 3 point system
default_mf_point_3 = 71
default_f_point_3 = 96
default_ff_point_3 =  116
-- 4 point system
default_mp_point_4 = 51
default_mf_point_4 = 81
default_f_point_4 =  101
default_ff_point_4 = 116

-------------------------
-------------------------

function contains_dynamic_level_points(input_array, array_length)
	local count = 0
	local p1 = -1
	local p2 = -1
	local p3 = -1
	local p4 = -1
	local dyn_p_count = 0
	
	for i = 1, array_length, 1 do
		local in_value = tonumber(input_array[i])
		if in_value > 39 then
			dyn_p_count = dyn_p_count + 1
			
			if dyn_p_count == 1 then
				p1 = in_value
				count = 1
			elseif dyn_p_count == 2 then
				p2 = in_value
				count = 2
			elseif dyn_p_count == 3 then
				p3 = in_value
				count = 3
			elseif dyn_p_count == 4 then
				p4 = in_value
				count = 4				
				break -- all possible points found, exiting the loop
			end
		end
	end
	
	return count, p1, p2, p3, p4
end

function parse_input_command()

	local mp_point = 0
	local mf_point = 0
	local f_point = 0
	local ff_point = 1 -- default value for the most simple use cases with no input command
	local p_layer_count = 0
	local mp_layer_count = 0
	local mf_layer_count = 0
	local f_layer_count = 0
	local ff_layer_count = 1 -- default value for the most simple use cases with no input command
	local articulation_name = "Default" -- default value for the most simple use cases with no input command
	local round_robin_count	= 1 -- default value for the most simple use cases with no input command
	local no_pitch = false
	local stretch = false
	local stretch_policy = 0
	
	local retv, num_markers, num_regions = reaper.CountProjectMarkers(0)
	local input_marker_found = false
	local input_marker_idx = -1
	
	
	for i = 0, num_markers + num_regions - 1, 1 do
	
		local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
		
		for word in string.gmatch(name, "%a+") do 
			if word == "arr" then
				input_marker_found = true
				input_marker_idx = i
				break;
			end
		end
		if input_marker_found == true then
			break;
		end
	end
	if input_marker_idx ~= -1 or default_settings_enabled == true then
	
		local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(input_marker_idx)
		local input_parameters = {}
		local par_indx = 0

		for word in string.gmatch(name, "%d+") do 
			par_indx = par_indx + 1
			input_parameters[par_indx] = word
		end
		
		for word in string.gmatch(name, "%a+") do
			if word ~= "arr" and word ~= "nopitch"and word ~= "stretch" and word ~= "nostretch" and word ~= "preferup" and word ~= "onlyup" and word ~= "onlydown" and string.find(word, "offset") == nil then
				articulation_name = word
			end 
			if word == "nopitch" then
				no_pitch = true
			end 
			if word == "stretch" then
				stretch = true
			end 
			if word == "preferup" then
				stretch_policy = 1
			end
			if word == "onlyup" then
				stretch_policy = 2
			end
			if word == "onlydown" then
				stretch_policy = 3
			end
			if word == "nostretch" then
				stretch_policy = 4
			end
			if word == "offzero" then
				offset = 0
			end 
			if word == "offfive" then
				offset = 5
			end 
			if word == "offfifteen" then
				offset = 15
			end 
			if word == "offtwenty" then
				offset = 20
			end 
			if word == "offtwentyfive" then
				offset = 25
			end
			if word == "offthirty" then
				offset = 30
			end 
			if word == "offthirtyfive" then
				offset = 35
			end 
			if word == "offforty" then
				offset = 40
			end 
			if word == "offfortyfive" then
				offset = 45
			end 
			if word == "offfifty" then
				offset = 50
			end 
			if word == "offfiftyfive" then
				offset = 55
			end 
			if word == "offsixty" then
				offset = 60
			end 
		end

		-- dynamic level points
		local count, ff_p, f_p, mf_p, mp_p = contains_dynamic_level_points(input_parameters, par_indx)
		
		if count > 0 then
			if ff_p ~= -1 then
				ff_point = ff_p
			end
			if f_p ~= -1 then
				f_point = f_p
			end
			if mf_p ~= -1 then
				mf_point = mf_p
			end
			if mp_p ~= -1 then
				mp_point = mp_p
			end
			-- remove dynamic level points from the parameter list to not mess up the following
			for i = 1, count, 1 do
				table.remove(input_parameters)
				par_indx = par_indx - 1
			end
		end	

		-- support for several types of input lines
		
		if par_indx == 1 then		
			ff_point = 1
			ff_layer_count = tonumber(input_parameters[1])
			round_robin_count = 1
		end
		
		if par_indx == 2 then		
			ff_point = 1
			ff_layer_count = tonumber(input_parameters[1])
			round_robin_count = tonumber(input_parameters[2])
		end
		
		if par_indx == 3 then	
			f_point = 1
			f_layer_count = tonumber(input_parameters[1])
			if ff_point == 0 then
				ff_point = default_ff_point_1
			end
			ff_layer_count = tonumber(input_parameters[2])
			round_robin_count = tonumber(input_parameters[3])
		end
		
		if par_indx == 4 then
			mf_point = 1
			mf_layer_count = tonumber(input_parameters[1])
			if f_point == 0 then
				f_point = default_f_point_2
			end
			f_layer_count = tonumber(input_parameters[2])
			if ff_point == 0 then
				ff_point = default_ff_point_2
			end
			ff_layer_count = tonumber(input_parameters[3])
			round_robin_count = tonumber(input_parameters[4])
		end
		
		if par_indx == 5 then
			mp_point = 1
			mp_layer_count = tonumber(input_parameters[1])
			if mf_point == 0 then
				mf_point = default_mf_point_3
			end
			mf_layer_count = tonumber(input_parameters[2])
			if f_point == 0 then
				f_point = default_f_point_3
			end
			f_layer_count = tonumber(input_parameters[3])
			if ff_point == 0 then
				ff_point = default_ff_point_3
			end
			ff_layer_count = tonumber(input_parameters[4])
			round_robin_count = tonumber(input_parameters[5])
		end
		
		if par_indx == 6 then
			p_layer_count = tonumber(input_parameters[1])
			if mp_point == 0 then
				mp_point = default_mp_point_4
			end
			mp_layer_count = tonumber(input_parameters[2])
			if mf_point == 0 then
				mf_point = default_mf_point_4
			end
			mf_layer_count = tonumber(input_parameters[3])
			if f_point == 0 then
				f_point = default_f_point_4
			end
			f_layer_count = tonumber(input_parameters[4])
			if ff_point == 0 then
				ff_point = default_ff_point_4
			end
			ff_layer_count = tonumber(input_parameters[5])
			round_robin_count = tonumber(input_parameters[6])
		end
		
		if par_indx == 10 then
			mp_point = tonumber(input_parameters[1])
			mf_point = tonumber(input_parameters[2])
			f_point = tonumber(input_parameters[3])
			ff_point = tonumber(input_parameters[4])

			p_layer_count = tonumber(input_parameters[5])
			mp_layer_count = tonumber(input_parameters[6])
			mf_layer_count = tonumber(input_parameters[7])
			f_layer_count = tonumber(input_parameters[8])
			ff_layer_count = tonumber(input_parameters[9])
			round_robin_count = tonumber(input_parameters[10])
		end
		
		if round_robin_count == 0 then round_robin_count = 1 end
		
		local number_of_tracks = (p_layer_count + mp_layer_count + mf_layer_count + f_layer_count + ff_layer_count) * round_robin_count
		
		return mp_point, mf_point, f_point, ff_point, p_layer_count, mp_layer_count, mf_layer_count, f_layer_count, ff_layer_count, articulation_name, round_robin_count, number_of_tracks, no_pitch, stretch, stretch_policy
	else
		return -1, -1, -1, -1, -1, -1,  -1, -1, -1, "-1", -1, -1, false
	end
end

function add_regions_for_notes(padded_note_list, padded_note_count, region_lenght, start_point, stretch_policy)

	local region_number = 1
		
	padded_note_list[1] = padded_note_list[2] - 2 * math.abs(padded_note_list[2] -  padded_note_list[1]) -- taking into account the stretch algorithm
	padded_note_list[padded_note_count] = padded_note_list[padded_note_count - 1] + 2 * math.abs(padded_note_list[padded_note_count] -  padded_note_list[padded_note_count - 1]) + 1

	for i = 2, padded_note_count - 1, 1 do
		local note = padded_note_list[i]
		local note_spacing_up = padded_note_list[i + 1] - padded_note_list[i]
		local note_spacing_down = padded_note_list[i] - padded_note_list[i - 1]
		local stretch_up = math.floor(math.abs(note_spacing_up - 1) / 2)
		local stretch_down = math.floor(math.abs(note_spacing_down - 1) / 2) + (math.abs(note_spacing_down - 1) % 2)

		if stretch_policy == 0 then
			stretch_up = math.floor(math.abs(note_spacing_up - 1) / 2)
			stretch_down = math.floor(math.abs(note_spacing_down - 1) / 2) + (math.abs(note_spacing_down - 1) % 2)
		elseif stretch_policy == 1 then
			stretch_up = math.floor(math.abs(note_spacing_up - 1) / 2) + (math.abs(note_spacing_up - 1) % 2)
			stretch_down = math.floor(math.abs(note_spacing_down - 1) / 2) 
		elseif stretch_policy == 2 then
			stretch_up = (note_spacing_up - 1)
			stretch_down = 0
			if stretch_up == -1 then
				stretch_up = 0
			end
		elseif stretch_policy == 3 then
			stretch_up = 0
			stretch_down = (note_spacing_down - 1)
			if stretch_down == -1 then
				stretch_down = 0
			end
		elseif stretch_policy == 4 then
			stretch_up = 0
			stretch_down = 0			
		end
		-- these are needed to catch corner-cases (lowest/highest note) where note spacing is zero 
		if note_spacing_up == 0 then
			stretch_up = 0
		end
		if note_spacing_down == 0 then
			stretch_down = 0
		end

		reaper.AddProjectMarker2(0, true, start_point + region_lenght * (region_number - 1), start_point + region_lenght * region_number, tostring(note - stretch_down).."_"..tostring(note).."_"..tostring(note + stretch_up), -1, reaper.ColorToNative(note, math.abs(math.floor((255 - (note%12)/12 * 255))),math.floor((note%12)/12 * 255/2))|0x1000000)
		region_number = region_number + 1
	end

end

function create_tracks(mp_point, mf_point, f_point, ff_point, p_layer_count, mp_layer_count, mf_layer_count, f_layer_count, ff_layer_count, articulation_name, round_robin_count)

	local highest_assigned = 0
	local track_count = reaper.CountTracks(0)
	local points = {mp_point, mf_point, f_point, ff_point, 128}
	local layer_counts = {p_layer_count, mp_layer_count, mf_layer_count, f_layer_count, ff_layer_count}

	for i = 1, 5, 1 do
		local current_point = points[i]
		local current_layer_count = layer_counts[i]

		if(current_layer_count > 0) then
			
			local layer_size = math.floor(((current_point - 1) - highest_assigned) / current_layer_count)
			local remainder = ((current_point - 1) - highest_assigned) % current_layer_count
			local remndr_count = 0

			for j = 1,  current_layer_count, 1 do

				local vel_min
				local vel_max
	
				if j == 1 then
					if highest_assigned == 0 then
						-- offset is used to expand the bottom layer as it is more useful to have the layers sit a bit higher
						layer_size = math.floor(((current_point - 1) - highest_assigned - offset) / current_layer_count)
						remainder = ((current_point - 1) - highest_assigned - offset) % current_layer_count
						vel_min = (highest_assigned + 1)
						vel_max = (highest_assigned ) + layer_size + offset
					else
						vel_min = (highest_assigned + 1)
						vel_max = (highest_assigned ) + layer_size
					end
				else
					vel_min = (highest_assigned + 1)
					vel_max = (highest_assigned) + layer_size
				end
				
				-- spreading the remainder between the layers
				if remndr_count < remainder then
					vel_max = vel_max + 1 -- '1' is part of the remainder
					remndr_count = remndr_count + 1
				end
				
				-- tracks
				if round_robin_count > 1 then
					for k = 1, round_robin_count, 1 do
					reaper.InsertTrackAtIndex((track_count - 1) + 1, true)
					track_count = reaper.CountTracks(0)
					reaper.GetSetMediaTrackInfo_String(reaper.GetTrack(0, (track_count - 1)), 'P_NAME', tostring(vel_min).."_"..tostring(vel_max).."_"..articulation_name.."RR"..tostring(k), true)
					end
				else
					reaper.InsertTrackAtIndex((track_count - 1) + 1, true)
					track_count = reaper.CountTracks(0)
					reaper.GetSetMediaTrackInfo_String(reaper.GetTrack(0, (track_count - 1)), 'P_NAME', tostring(vel_min).."_"..tostring(vel_max).."_"..articulation_name, true)
				end
				
				highest_assigned = vel_max

			end		
		end
	end
end

function move_items_to_tracks(number_of_tracks, round_robin_count, no_pitch, track)
	
	for i = 0, reaper.CountMediaItems(0) - 1, 1 do
		reaper.SetMediaItemSelected(reaper.GetMediaItem(0, i), false)
	end
	
	--local track = reaper.GetTrack(0, 0)
	local item_count = reaper.CountTrackMediaItems(track)
	
	for i = 0, item_count - 1, 1 do
		reaper.SetMediaItemSelected(reaper.GetTrackMediaItem(track, i), true)
	end
		
	local retval, num_markers, num_regions = reaper.CountProjectMarkers(0)
	local first_track_idx = reaper.CountTracks(0) - number_of_tracks
	
	local test = false

	for i = 0, num_regions + num_markers - 1, 1 do
	
		local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
		local r_reg, g, b = reaper.ColorFromNative(color)
		
		if isrgn == true then
		
			for j = first_track_idx, reaper.CountTracks(0) - 1, 1 do
				local item_count = reaper.CountSelectedMediaItems(0)
				for k = 0, item_count - 1, 1 do
					local item = reaper.GetSelectedMediaItem(0, k)
					if(item ~= nil) then
					
						local color_item = reaper.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
						local r_item, g, b = reaper.ColorFromNative(color_item) -- this makes it possible to arrange unlabelled samples
						
						if reaper.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR") == color or no_pitch == true or r_reg == r_item then			
							reaper.MoveMediaItemToTrack(item, reaper.GetTrack(0, j))
							reaper.SetMediaItemPosition(item, pos, true)
							reaper.SetMediaItemSelected(item, false)	
							break; -- suitable item found, break search
						end
					end
				end
			end
		end
	end

	for i = 0, reaper.CountMediaItems(0) - 1, 1 do
		reaper.SetMediaItemSelected(reaper.GetMediaItem(0, i), false)
	end

	for i = 0, reaper.CountTracks(0) - 1, 1 do
		reaper.SetTrackSelected(reaper.GetTrack(0, i), false)
	end

	if round_robin_count > 1 then
	
		-- create folder tracks, select tracks, move under the folder	
		local tracks_per_round_robin = number_of_tracks / round_robin_count
		
		for i = round_robin_count, 1, -1 do
			reaper.InsertTrackAtIndex(first_track_idx, true)
			reaper.GetSetMediaTrackInfo_String(reaper.GetTrack(0, first_track_idx), 'P_NAME', "RR"..tostring(i), true)
			for j = 1, tracks_per_round_robin * i, i do
				reaper.SetTrackSelected(reaper.GetTrack(0, reaper.CountTracks(0) - j), 1)
			end
			reaper.ReorderSelectedTracks(first_track_idx + 1, 1)
			for i = 0, reaper.CountTracks(0) - 1, 1 do
				reaper.SetTrackSelected(reaper.GetTrack(0, i), false)
			end			
		end
	end
	
	local tc = reaper.CountTracks(0)
	
	-- set moved items selected and ready for export
	for i = 1, number_of_tracks + round_robin_count - 1, 1 do
		local tr = reaper.GetTrack(0, tc - i)
		local ic = reaper.CountTrackMediaItems(tr)
		if ic > 0 then
			for j = 0, ic - 1, 1 do
				local itm = reaper.GetTrackMediaItem(tr, j)
				if itm ~= nil then
					reaper.SetMediaItemSelected(itm, true)
				end
			end
		end
	end
end

function arrange_samples(track_idx)

	local track = reaper.GetTrack(0, track_idx) 
	local item_count = reaper.CountTrackMediaItems(track)
	if(item_count > 0) then
			
		local region_lenght = 10
		local start_point = 10
		local lowest_note = 109
		local highest_note = -1
		local max_item_length = 0
		
		local notes = {}
		local notes_count = 0

		local mp_point, mf_point, f_point, ff_point, p_layer_count, mp_layer_count, mf_layer_count, f_layer_count, ff_layer_count, articulation_name, round_robin_count, number_of_tracks, no_pitch, stretch, stretch_policy = parse_input_command()

		if stretch == true and stretch_policy ~= 4 then
			lowest_note = 24
			highest_note = 108
		end

		for i = 0, item_count - 1, 1 do
			local item = reaper.GetTrackMediaItem(track, i)
			local r, g, b = reaper.ColorFromNative(reaper.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR"))
			local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
			local placement_idx = 1
			
			if item_len > max_item_length then
				max_item_length = item_len
			end
			
			if notes_count == 0 then
				notes[1] = r
				notes_count = 1
			else
				if r > notes[notes_count] then
					notes_count = notes_count + 1
					notes[notes_count] = r
				else
					for j = notes_count, 1, -1 do
						if notes[j] == r then
							break; -- note already appears in the list
						end
						if r > notes[j] then
							table.insert(notes, j + 1, r)
							notes_count = notes_count + 1
							break;
						elseif j == 1 then
							table.insert(notes, 1, r)
							notes_count = notes_count + 1
							break;
						end
					end
				end
			end		
		end
		-- region length
		if max_item_length > region_lenght then

			if max_item_length < 15 then
				region_lenght = 15
			elseif max_item_length < 20 then
				region_lenght = 20
			elseif max_item_length < 25 then
				region_lenght = 25
			elseif max_item_length < 30 then
				region_lenght = 30
			else
				region_lenght = max_item_length
			end
		end
		
		-- padding the note list
		if notes[1] < lowest_note then
			lowest_note = notes[1]
		end
		if notes[notes_count] > highest_note then
			highest_note = notes[notes_count]
		end
		
		table.insert(notes, 1, lowest_note)
		notes_count = notes_count + 2
		notes[notes_count] = highest_note
		
		-- regions
		if track_idx == 0 then
			add_regions_for_notes(notes, notes_count, region_lenght, start_point, stretch_policy)
		end
		
		-- tracks
		create_tracks(mp_point, mf_point, f_point, ff_point, p_layer_count, mp_layer_count, mf_layer_count, f_layer_count, ff_layer_count, articulation_name, round_robin_count)
		
		-- move items
		move_items_to_tracks(number_of_tracks, round_robin_count, no_pitch, track)
	end
end

function main()
		
	local main_track = reaper.GetTrack(0, 0)	
	local main_sample_count = reaper.CountTrackMediaItems(main_track)
	local group_ids = {}
	local group_ids_idx = 0
	
	for i = 0,  main_sample_count - 1, 1 do
		local temp_item = reaper.GetTrackMediaItem(main_track, i)
		local id = reaper.GetMediaItemInfo_Value(temp_item, "I_GROUPID")
		if id ~= 0 then
			if group_ids_idx == 0 then
				group_ids_idx = 1
				group_ids[group_ids_idx] = id
			else
				for j = 1, group_ids_idx, 1 do
					if id == group_ids[j] then
						break;
					else
						if j == group_ids_idx then
							group_ids_idx = group_ids_idx + 1
							group_ids[group_ids_idx] = id
						end
					end
				end
			end
		end
	end
	
	local track_numbers = {}
	local track_numbers_idx = 1
	track_numbers[1] = 1 -- main_track - note: track number is 1-based, track index is 0-based
	
	if group_ids_idx > 1 then
	
		local item_count = reaper.CountMediaItems(0)
		
		for i = 0, item_count - 1, 1 do
			local temp_item = reaper.GetMediaItem(0, i)
			local temp_track = reaper.GetMediaItem_Track(temp_item)
			local temp_tr_num = reaper.GetMediaTrackInfo_Value(temp_track, "IP_TRACKNUMBER")
			local id = reaper.GetMediaItemInfo_Value(temp_item, "I_GROUPID")
			
			for j = 1, group_ids_idx, 1 do
				if id == group_ids[j] then				
					for k = 1, track_numbers_idx, 1 do
						if temp_tr_num == track_numbers[k] then
							break;
						else
							if k == track_numbers_idx then
								track_numbers_idx = track_numbers_idx + 1
								track_numbers[track_numbers_idx] = temp_tr_num
							end
						end
					end
				end
			end			
		end
	
	end
	
	reaper.Undo_BeginBlock()
	
	local old_track_count = reaper.CountTracks(0)
	
	for i = 1, track_numbers_idx, 1 do
		local track_idx = track_numbers[i] - 1 -- note: number -> index, thus '-1'
		arrange_samples(track_idx) 
	end
		
	local item_count = reaper.CountMediaItems(0)
		
	for i = 0, item_count - 1, 1 do
		local temp_item = reaper.GetMediaItem(0, i)
		local id = reaper.GetMediaItemInfo_Value(temp_item, "I_GROUPID")
		
		for j = 1, group_ids_idx, 1 do
			if id == group_ids[j] then				
				reaper.SetMediaItemSelected(temp_item, true) -- selected items are ready for rendering/export
			end
		end
	end
	
	if track_numbers_idx > 0 then
		--add mic folder tracks and finalize naming
		local new_track_count = reaper.CountTracks(0)
		local num_added_tracks = new_track_count - old_track_count
		local num_tracks_per_mic = num_added_tracks / track_numbers_idx
				
		for i = track_numbers_idx, 1, -1 do
			reaper.InsertTrackAtIndex(old_track_count, true)
			local new_track = reaper.GetTrack(0, old_track_count)
			reaper.GetSetMediaTrackInfo_String(new_track, "P_NAME", "Mic "..tostring(i), true)
			reaper.SetMediaTrackInfo_Value(new_track, "I_FOLDERDEPTH", 1)
			
			for j = reaper.CountTracks(0) - 1, reaper.CountTracks(0) - num_tracks_per_mic, -1 do
				local temp_tr = reaper.GetTrack(0, j)
				reaper.SetTrackSelected(temp_tr, true)
				local retval, old_name = reaper.GetSetMediaTrackInfo_String(temp_tr, "P_NAME", "", false)
				if reaper.GetMediaTrackInfo_Value(temp_tr, "I_FOLDERDEPTH") == 1 then
					--
				else
					local new_name = ""
					local mic_string = "Mic"..tostring(i)
					if track_numbers_idx == 1 then
						mic_string = "" -- no need for word "Mic"
					end
					if string.find(old_name, "RR") ~= nil then
						new_name = string.gsub(old_name, "RR", mic_string.."RR", 1)
					else
						new_name = old_name..mic_string
					end
					
					local space_count = 0
					for c in string.gmatch(new_name, "%p") do 
						if c == "_" then
							space_count = space_count + 1
						end
					end
					
					local name_info_part = ""
					if space_count == 2 then
						local reversed_name = string.reverse(new_name)
						local separator_idx = string.find(reversed_name, "_")
						name_info_part = string.sub(new_name, string.len(new_name) - separator_idx + 2)
						if name_info_part ~= "" and name_info_part ~= nil then
							new_name = string.gsub(new_name, "_"..name_info_part, "", 1)
						else
							new_name = string.sub(new_name, 1, -2)
						end
					end
					
					reaper.GetSetMediaTrackInfo_String(reaper.GetParentTrack(temp_tr), "P_NAME", name_info_part, true)	
					reaper.GetSetMediaTrackInfo_String(temp_tr, "P_NAME", new_name, true)
				end
			end
			
			reaper.ReorderSelectedTracks(old_track_count + 1, 1)		
			reaper.SetMediaTrackInfo_Value(reaper.GetTrack(0, old_track_count + num_tracks_per_mic), "I_FOLDERDEPTH", -2)
			for j = 0, reaper.CountTracks(0) - 1, 1 do
				reaper.SetTrackSelected(reaper.GetTrack(0, j), false)
			end
		end
	end
	reaper.Undo_EndBlock("Arrange Samples For Export", 0)
end

main()

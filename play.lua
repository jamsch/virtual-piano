local total, VP_LastTime = 0, 0
local _, _, _, tocversion = GetBuildInfo()
local isDeprecated = (tocversion < 30000)
VP_NotebindMode = false
local paused = false

local function AddonMessages(key)
	if (VP_isRecording) then
		local currentTime = GetTime();
		delay = currentTime - VP_LastTime
		--more than 6 seconds of the person not pressing a key will result in 0.5s delay
		if (delay > 6) then delay = 0.5 end 
		tinsert(VP_Settings.noteTime, round(delay,3))
		tinsert(VP_Settings.songNote, key)
		VP_LastTime = currentTime;
	end
	if (VP_PartyBroadcast:GetChecked()) then
		SendAddonMessage("VP_Key", key, "PARTY")
	end
	if (VP_GuildBroadcast:GetChecked()) then
		SendAddonMessage("VP_Key", key, "GUILD")
	end	
	if (VP_RaidBroadcast:GetChecked()) then
		SendAddonMessage("VP_Key", key, "RAID")
	end		
	if (VP_PlayerBroadcast:GetChecked() and VP_WhisperTarget ~= nil) then
		SendAddonMessage("VP_Key", key, "WHISPER", VP_WhisperTarget)
	end
end

function VP_KeybindDownKey(self, key)
	if (key == "LSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "RSHIFT" or key == "RALT" or key == "LALT") then
		return
	end
	if IsShiftKeyDown() then
		key = "s"..key
	elseif IsControlKeyDown() then
		key = "c"..key
	elseif IsAltKeyDown() then
		key = "a"..key
	end
	if (VP_KeybindBtn:IsKeyboardEnabled()) then
		VP_KeybindBtnText:SetText(key)
		VP_SetKeybindBtn:Enable()
		VP_UnbindBtn:Enable()
		VP_KeybindBtn:EnableKeyboard(false)
			if (VP_Keybinds[VP_Settings.KeybindProfile][key]) then
				if (type(VP_Keybinds[VP_Settings.KeybindProfile][key]) == "table") then
					for i, v in pairs(VP_Keybinds[VP_Settings.KeybindProfile][key]) do
						if (VP_KeybindEntry:GetText() ~= "") then
							VP_KeybindEntry:SetText(VP_KeybindEntry:GetText()..","..v)
						else
							VP_KeybindEntry:SetText(v)
						end
					end
				else
					VP_KeybindEntry:SetText(VP_Keybinds[VP_Settings.KeybindProfile][key])
				end
			else
				VP_KeybindEntry:SetText("")
			end
		VP_KeybindBtn:SetScript("OnKeyDown", nil)
		return
	end
	return key
end

local function GetNoteBinds(key)
	local text = ""
	for i, name in pairs(VP_Keybinds[VP_Settings.KeybindProfile]) do
		if type(name) == "table" then
			for i2,name2 in pairs(VP_Keybinds[VP_Settings.KeybindProfile][i]) do
				if (key == name2) then
					if (text == "") then
						text = i
					else
						text = text..","..i
					end
				end
			end
		elseif (key == name) then
			if (text == "") then
				text = i
			else
				text = text..","..i
			end
		end
	end
	return text
end

function VPiano_DownKey(self, key)
	if (self == VP_MainPianoWindow) then --if this is a key press
		if (key == "ESCAPE") then
			VPiano_ToggleKeyboard()
			return
		end
		key = VP_KeybindDownKey(_,key)
		if (not key) then return end -- if the return was a nil (returned because a modifier key)
		if (VP_Keybinds[VP_Settings.KeybindProfile][key]) then 
			key = VP_Keybinds[VP_Settings.KeybindProfile][key]
		elseif (VP_Settings.KeybindProfile == "default" and VP_Keybinds[VP_Settings.KeybindProfile].ExtraKeybinds[key]) then
			key = VP_Keybinds[VP_Settings.KeybindProfile].ExtraKeybinds[key]
		elseif (strlen(key) == 2) then -- in case for shift/alt modifier keys
			if (VP_Keybinds[VP_Settings.KeybindProfile][strsub(key,2)]) then
				key = VP_Keybinds[VP_Settings.KeybindProfile][strsub(key,2)]
			elseif (VP_Settings.KeybindProfile == "default" and VP_Keybinds[VP_Settings.KeybindProfile].ExtraKeybinds[strsub(key,2)]) then
				key = VP_Keybinds[VP_Settings.KeybindProfile].ExtraKeybinds[strsub(key,2)]
			else
				return
			end
		else
			return
		end
	elseif (VP_KeybindEntry:HasFocus()) then
		if (VP_KeybindEntry:GetText() ~= "") then
			VP_KeybindEntry:SetText(VP_KeybindEntry:GetText()..","..key)
		else
			VP_KeybindEntry:SetText(key)
		end
	elseif (VP_NotebindMode) then
		VP_NotebindBtn:SetText(key)
		VP_NotebindEntry:SetText(GetNoteBinds(key))
		VP_SetNotebindBtn:Enable()
		VP_UnbindNoteBtn:Enable()
		VP_NotebindMode = false
	end
	if (type(key) ~= "table") then
		VP_PlayNote(key)
		AddonMessages(key)
	else
		for i,name in pairs(key) do
			VP_PlayNote(name)
			AddonMessages(name)
		end
	end
end

function VP_PlayNote(key)
	PlaySoundFile("Interface\\Addons\\Virtualpiano\\Notes\\"..key..".ogg", "Master")
	local VPKey = _G["VP_"..key.."Keyf"];
	local VPKey2 = _G["VP_"..key.."Key"]
	if (VPKey2 ~= nil) then --in case a player sends a malformed key or script is messed up
		if (not VPKey2:IsVisible()) then -- avoid animating the hidden keys
			return
		elseif UIFrameIsFading(VPKey) then
			UIFrameFlashStop(VPKey)
		end
		if (VP_RandomColors:GetChecked()) then
			VPKey:SetBackdropColor(math.random(),math.random(),math.random())
		end
		UIFrameFadeIn(VPKey, 0.85, 1, 0)
	end
end


function VP_StartSong(self,elapsed)
	total = total + elapsed
	if (VP_time[VP_Iterator] ~= nil) then
		if total >= (VP_time[VP_Iterator]/VP_Settings.Speed) then
			VP_PlayNote(VP_note[VP_Iterator])
			total = 0
			VP_Iterator = VP_Iterator + 1
			if (VP_time[VP_Iterator] ~= nil and VP_time[VP_Iterator] < 0.05) then
			--these are notes that are played together and need to be played asap
				VP_PlayNote(VP_note[VP_Iterator])
				VP_Iterator = VP_Iterator + 1
			end
			VP_Slider:SetValue(VP_Iterator)
		end
	elseif ((not VP_ShuffleMode and VP_isPlayingPlaylist and (VP_TrackNum + 1) <= VP_MaxTracksInPlaylist) or (VP_ShuffleMode and VP_isPlayingPlaylist and ((VP_ShuffleIterator + 1) <= VP_MaxTracksInPlaylist))) then
		if (total > 4) then
			if (VP_ShuffleMode) then
				VP_ShuffleIterator = VP_ShuffleIterator + 1
				VP_TrackNum = VP_ShuffledPlaylist[VP_ShuffleIterator]
			else
				VP_TrackNum = VP_TrackNum + 1
			end
			local songName, songString = next(VP_Playlist[VP_SelectedPlaylist][VP_TrackNum])
				VP_MSG("Playing song: "..songName)
				VP_PlayRecording:SetScript("OnUpdate", nil)	
				VP_FormatSong(songString)
		end
	else
		VP_PlayingSong = false
		if (VP_SelectedPlaylist == "") then
			VP_PlayStopButton:Hide()
			VP_PauseButton:Hide()
		else
			VP_PlayStopButton:SetBackdrop({bgFile = [[Interface\AddOns\Virtualpiano\Images\PlaybackControls\Play]]})
		end
		VP_Slider:Hide()
		VP_SpeedSlider:Hide()
		VP_MSG("Stopped playback")
		VP_PlayRecording:SetScript("OnUpdate", nil)
	end
end

function VP_PauseTrack()
	VP_PlayRecording:SetScript("OnUpdate", nil)
	VP_PlayStopButton:SetBackdrop({bgFile = [[Interface\AddOns\Virtualpiano\Images\PlaybackControls\Play]]})
	paused = true
	VP_PlayingSong = false
end

function VP_TogglePlayStop()
	if (paused) then
		VP_PlayStopButton:SetBackdrop({bgFile = [[Interface\AddOns\Virtualpiano\Images\PlaybackControls\Stop]]})
		VP_PlayingSong = true
		VP_PlayRecording:SetScript("OnUpdate", VP_StartSong)
		paused = false
	elseif (VP_PlayingSong) then
		if (VP_SelectedPlaylist == "") then
			VP_PlayStopButton:Hide()
			VP_PauseButton:Hide()
		else
			VP_PlayStopButton:SetBackdrop({bgFile = [[Interface\AddOns\Virtualpiano\Images\PlaybackControls\Play]]})
		end
		VP_Slider:Hide()
		VP_SpeedSlider:Hide()
		VP_PlayRecording:SetScript("OnUpdate", nil)
		VP_PlayingSong = false
	elseif (VP_SelectedPlaylist ~= "") then --VP_isPlayingPlaylist
		VP_isPlayingPlaylist = true
		local songName, songString = next(VP_Playlist[VP_SelectedPlaylist][VP_TrackNum])
		VP_MSG("Playing song: "..songName)
		VP_FormatSong(songString)
	end
end

function VP_playSong(notetime,note)
	VP_PlayingSong = true
	VP_PlayStopButton:SetBackdrop({bgFile = [[Interface\AddOns\Virtualpiano\Images\PlaybackControls\Stop]],})
	VP_time = notetime
	VP_note = note
	if (getn(VP_time) == nil) then
		VP_MSG("Error: Something wrong with the script")
	end
	local songLength = 0
	for i,notelength in ipairs(VP_time) do
		songLength = songLength + (notelength/VP_Settings.Speed)
	end
	VP_Slider:SetValue(1)
	local arrayLength = getn(VP_time)
	if arrayLength == 0 then arrayLength = 1 end -- to avoid any lua errors
	VP_Slider:SetMinMaxValues(1, arrayLength)
	VP_SliderLow:SetText('0')
	VP_SliderHigh:SetText(date("%M:%S", songLength))
	VP_Iterator = 1
	VP_Slider:Show()
	VP_SpeedSlider:Show()
	VP_PlayStopButton:Show()
	VP_PauseButton:Show()
	if (VP_SelectedPlaylist ~= "") then
		local songName = next(VP_Playlist[VP_SelectedPlaylist][VP_TrackNum])
		UIDropDownMenu_SetSelectedID(VP_Tracklist, VP_TrackNum)
		if (isDeprecated) then
			UIDropDownMenu_SetText(VP_TrackNum..": "..songName, VP_Tracklist)
		else
			UIDropDownMenu_SetText(VP_Tracklist, VP_TrackNum..": "..songName)
		end
	end
	if VP_PlayRecording == nil then
		VP_PlayRecording = CreateFrame("frame")
	end
	VP_PlayRecording:SetScript("OnUpdate", VP_StartSong)
end

function VP_PlayTrack(self,isSelected)
	if (not VP_isPlayingPlaylist) then return end
	if (self == VP_NextTrackButton) then
		if ((not VP_ShuffleMode and (VP_TrackNum + 1) > VP_MaxTracksInPlaylist) or (VP_ShuffleMode and ((VP_ShuffleIterator + 1) > VP_MaxTracksInPlaylist))) then return end
		if (VP_ShuffleMode) then
			VP_ShuffleIterator = VP_ShuffleIterator + 1
		else
			VP_TrackNum = VP_TrackNum + 1
		end
	elseif (self == VP_PreviousTrackButton) then
		if ((not VP_ShuffleMode and VP_TrackNum == 1) or (VP_ShuffleIterator == 1 and VP_ShuffleMode)) then return end
		if (VP_ShuffleMode and not isSelected) then
			VP_ShuffleIterator = VP_ShuffleIterator - 1
		else
			VP_TrackNum = VP_TrackNum - 1
		end
	end
	if (VP_PlayingSong) then
		VP_PlayRecording:SetScript("OnUpdate", nil)
	end
	VP_isPlayingPlaylist = true
	VP_PlayingSong = true
	if (VP_ShuffleMode) then
		if (VP_ShuffleIterator > VP_MaxTracksInPlaylist or VP_ShuffleIterator < 0) then return end
		VP_TrackNum = VP_ShuffledPlaylist[VP_ShuffleIterator]
	end
	local songName, songString = next(VP_Playlist[VP_SelectedPlaylist][VP_TrackNum])
	VP_MSG("Playing song: "..songName)
	VP_FormatSong(songString)	
end
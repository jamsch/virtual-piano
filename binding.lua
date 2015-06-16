local function hideFrameText(text)
	--if no other keys are bound
	if (not (SetKeyText("VP_"..text.."Key") and SetKeyText("VP_"..text.."Keyf"))) then
		_G["VP_"..text.."KeyText"]:SetText("")
		_G["VP_"..text.."KeyfText"]:SetText("")
	end
end

function VP_deleteProfile(profile)
	if (profile ~= "default") then
		if (VP_Keybinds[profile] ~= nil) then
			VP_Keybinds[profile] = nil
			for i,v in ipairs(VP_Settings.Profiles) do
				if (profile == v) then
					tremove(VP_Settings.Profiles, i)
					break
				end
			end
			VP_MSG("Deleted keybind profile: "..profile)
		else
			VP_MSG("Keybind does not exist. Type /vp profile to see the keybind profile list.")
			return
		end
	else
		VP_MSG("Cannot delete the default profile.")
		return
	end
	--If the currently selected profile is the profile that is going to be deleted, set back to default
	if (VP_Settings.KeybindProfile == profile) then
		VP_Settings.KeybindProfileID = 1
		VP_Settings.KeybindProfile = "default"
		for i, self in pairs(VP_Keys) do
			if (not SetKeyText(self:GetName())) then
				_G[self:GetName().."Text"]:SetText("")
			end
		end
		if (isTBC) then return end
		UIDropDownMenu_SetSelectedID(VP_DropDownMenu, VP_Settings.KeybindProfileID)
	end
end

function VP_unbindPianoKey(pianokey)
	for i, name in pairs(VP_Keybinds[VP_Settings.KeybindProfile]) do
	if (type(name) == "table") then
		for i2, name2 in pairs(name) do
			if name2 == pianokey then
				VP_Keybinds[VP_Settings.KeybindProfile][i][i2] = nil
			end
		end
		elseif (name == pianokey) then
			VP_Keybinds[VP_Settings.KeybindProfile][i] = nil
		end
	end
	hideFrameText(pianokey)
	VP_MSG("Unbinded piano key")
end

local function formatKeybind(key,uppercase)
	local stringLength = strlen(key)
	local firstKey = strlower(strsub(key,1,1))
	if (stringLength == 2 and firstKey ~= "f") then --F1,F2,F3, etc
		return strlower(strsub(key,1,1)) .. strupper(strsub(key,2))
	elseif (uppercase) then
		return strupper(key)
	else
		return strlower(key)
	end
end

function VP_unbindKeyboardKey(key)
	local pianokey
	key = formatKeybind(key,true)
	if (VP_Keybinds[VP_Settings.KeybindProfile][key]) then
		if (type(VP_Keybinds[VP_Settings.KeybindProfile][key]) == "table") then
			for i,name in pairs(VP_Keybinds[VP_Settings.KeybindProfile][key]) do
				pianokey = name
				VP_Keybinds[VP_Settings.KeybindProfile][key][i] = nil
				hideFrameText(pianokey)
			end
		else
			pianokey = VP_Keybinds[VP_Settings.KeybindProfile][key]
			VP_Keybinds[VP_Settings.KeybindProfile][key] = nil
			hideFrameText(pianokey)
		end
		VP_Keybinds[VP_Settings.KeybindProfile][key] = nil
		VP_MSG("Unbinded key "..key)
	else
		VP_MSG("Keyboard key "..key.." does not exist.")
	end
end

function VP_BindKeyboardKey(key,pianokey)
	local formattedKey = formatKeybind(key)
	local tempKey = VP_Keybinds[VP_Settings.KeybindProfile][key]
	if (strlen(formattedKey) > 3)  then
		formattedKey = VP_formatBindText(formattedKey) 
	end
	if (strmatch(pianokey, ",")) then
		pianokey = {strsplit(",",pianokey)}
		VP_Keybinds[VP_Settings.KeybindProfile][key] = {} -- make a table container for the piano key
		for i, keyname in pairs(pianokey) do
			tinsert(VP_Keybinds[VP_Settings.KeybindProfile][key],keyname)
			_G["VP_"..keyname.."KeyText"]:SetText(formattedKey)
			_G["VP_"..keyname.."KeyfText"]:SetText(formattedKey)
		end
	elseif (_G["VP_"..pianokey.."Key"] ~= nil) then
		VP_Keybinds[VP_Settings.KeybindProfile][key] = pianokey
		_G["VP_"..pianokey.."KeyText"]:SetText(formattedKey)
		_G["VP_"..pianokey.."KeyfText"]:SetText(formattedKey)
	else
		VP_MSG("Invalid piano key '"..pianokey.."'.")
		return
	end
	--Clean up keyboard binds
	if type(tempKey) == "table" then
		for i, keyname in pairs(tempKey) do
			if not (tContains(VP_Keybinds[VP_Settings.KeybindProfile][key],keyname)) then
				hideFrameText(keyname)
			end
		end
	end
	VP_MSG("Successfully binded "..key)
end

function VP_BindPianoKey(pianokey, key)
local formattedKey
	if (strmatch(key, ",")) then
		key = {strsplit(",",key)}
		for i, keyname in pairs(key) do
			if (strlen(keyname) <= 2) then
				keyname = formatKeybind(keyname,true)
				if (VP_Keybinds[VP_Settings.KeybindProfile][keyname] ~= nil) then
					if (type(VP_Keybinds[VP_Settings.KeybindProfile][keyname]) == "table") then
						if (not tContains(VP_Keybinds[VP_Settings.KeybindProfile][keyname], pianokey)) then
							tinsert(VP_Keybinds[VP_Settings.KeybindProfile][keyname], pianokey)
						end
					elseif (VP_Keybinds[VP_Settings.KeybindProfile][keyname] ~= pianokey) then
						local tempval = VP_Keybinds[VP_Settings.KeybindProfile][keyname]
						VP_Keybinds[VP_Settings.KeybindProfile][keyname] = {tempval,pianokey}
					end
				else
					VP_Keybinds[VP_Settings.KeybindProfile][keyname] = pianokey
				end
			else
				VP_MSG("Invalid key '"..keyname.."'. Keybinds can be written like 's', 'sA' (shift A), 'aS' (alt S).")
				return
			end
		end
		formattedKey = formatKeybind(key[1])
		_G["VP_"..pianokey.."KeyText"]:SetText(formattedKey)
		_G["VP_"..pianokey.."KeyfText"]:SetText(formattedKey)
	elseif (strlen(key) < 3) then
		formattedKey = formatKeybind(key)
		key = formatKeybind(key,true)
		if (type(VP_Keybinds[VP_Settings.KeybindProfile][key]) == "table") then
			if (not tContains(VP_Keybinds[VP_Settings.KeybindProfile][key], pianokey)) then
				tinsert(VP_Keybinds[VP_Settings.KeybindProfile][key], pianokey)
			end
		elseif (VP_Keybinds[VP_Settings.KeybindProfile][key] ~= nil) then 
			if (VP_Keybinds[VP_Settings.KeybindProfile][key] ~= pianokey) then
				local tempval = VP_Keybinds[VP_Settings.KeybindProfile][key]
				VP_Keybinds[VP_Settings.KeybindProfile][key] = {tempval,pianokey}
			end
		else
			VP_Keybinds[VP_Settings.KeybindProfile][key] = pianokey
		end
		_G["VP_"..pianokey.."KeyText"]:SetText(formattedKey)
		_G["VP_"..pianokey.."KeyfText"]:SetText(formattedKey)
	else
		VP_MSG("Invalid key '"..key.."'. Keybinds can be written like 's', 'sA' (shift A), 'aS' (alt S).")
		return
	end
	VP_MSG("Successfully binded "..pianokey)
end
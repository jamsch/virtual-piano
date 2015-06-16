VP_ShuffleMode,VP_PlayingSong, VP_randomColors, VP_isRecording, VP_isPlayingPlaylist = false, false, false, false, false
local _, _, _, tocversion = GetBuildInfo()
local isDeprecated,isCurrent = (tocversion < 30000), (tocversion > 40000)
local CurrentMajorVersion = 1.5
VP_TrackNum,VP_MaxTracksInPlaylist,VP_ShuffleIterator = 1, 0, 1
VP_SelectedPlaylist = ""
local IndexedPlaylist,VP_ReceivedScripts,VP_MessageLength,VP_Keys,VP_MoreKeys,VP_MoreKeyPoints,VP_Naturals,VP_Sharps,VP_NaturalsP,VP_SharpsP = {},{},{},{},{},{},{},{},{},{}
local colorFrame
local lastKey = ""
VP_Playlist = {}
--todo: export to midi using a csv tol
--todo: add custom playlists for scripts and recordings
--todo: add ability to remove songs and items from playlists
SLASH_VIRTUALP1,SLASH_VIRTUALP2,SLASH_VIRTUALP3 = "/virtualpiano","/vp","/vpiano"

function VP_MSG(param,addPrefix)
	if (not addPrefix) then
		param = "|cffFF7D0AVirtual Piano|r: "..param
	end
	DEFAULT_CHAT_FRAME:AddMessage(param)
end

--Formats the binds on piano keys if the text is longer than 3 characters
function VP_formatBindText(text)
local text = strupper(text)
	if (strmatch(text,"PAGE") ~= nil) then
		if (strmatch(text,"DOWN")) then
			return "PgD"
		else
			return "PgU"
		end
	elseif (text == "HOME") then
		return "Hm"
	elseif (text == "INSERT") then
		return "Ins"
	elseif (text == "DELETE") then
		return "Del"
	elseif (strmatch(text,"CAPSLOCK") ~= nil) then
		if (text == "sCAPSLOCK" or text == "SCAPSLOCK") then
			return "sCL"
		elseif (text == "aCAPSLOCK" or text == "ACAPSLOCK") then
			return "aCL"
		elseif (text == "cCAPSLOCK" or text == "CCAPSLOCK") then
			return "cCL"
		else
			return "CAP"
		end
	elseif (text == "HOME") then
		return "Hm"
	elseif (strmatch(text,"NUMPAD") ~= nil) then
		local firstLetter = strlower(strsub(text,1,1))
		local modifierLetter = ""
		if (firstLetter == "s" or firstLetter == "c" or firstLetter == "a") then
			modifierLetter = firstLetter
		end
		local secondPart = ""
		if (strmatch(text,"DIVIDE") ~= nil) then
			secondPart = "/"
		elseif (strmatch(text,"MULTIPLY") ~= nil) then
			secondPart = "*"
		elseif (strmatch(text,"MINUS") ~= nil) then
			secondPart = "-"
		elseif (strmatch(text,"PLUS") ~= nil) then
			secondPart = "+"
		elseif (strmatch(text,"DECIMAL") ~= nil) then
			secondPart = "."
		else
			secondPart = strsub(text,7)
		end
		return modifierLetter.."N"..secondPart
	else --cannot match with anything else
		return strsub(text,1,3)
	end
end

function SetKeyText(frameName)
	for i,name in pairs(VP_Keybinds[VP_Settings.KeybindProfile]) do
		if type(name) ~= "table" then 
		--I have an extra table inside Default for extra keybinds, and I don't want to set the text on the keys with it
		--Also if some keys have multiple bindings in other keybind profiles
			if (frameName == "VP_"..name.."Key" or frameName == "VP_"..name.."Keyf") then
				if (strlen(i) == 1) then
					i = strlower(i) --lowercase a non capital letter
				elseif (strlen(i) > 3) then
					i = VP_formatBindText(i)
				end
				_G[frameName.."Text"]:SetText(i)
				return true
			end
		elseif (VP_Keybinds[VP_Settings.KeybindProfile].ExtraKeybinds == nil) then
			for i2, name2 in pairs(name) do
				if (frameName == "VP_"..name2.."Key" or frameName == "VP_"..name2.."Keyf") then
					if (strlen(i) == 1) then
						i = strlower(i) --lowercase a non capital letter
					elseif (strlen(i) > 3) then
						i = VP_formatBindText(i)
					end
					_G[frameName.."Text"]:SetText(i)
					return true
				end
			end
		end
	end
	--if there is no keybind for the frame
	return false
end

local function SetKey(self,hideExtraKeys)
	local frameName = self:GetName()
	local fontstring = self:CreateFontString(frameName.."Text","OVERLAY","font")
	local key = strsub(self:GetName(),4,strfind(self:GetName(),"Key")-1)
	local isPressedKey = strmatch(self:GetName(),"Keyf")
	if (strlen(key) == 3) then
	--is a sharp
		fontstring:SetTextColor(1,1,1)
		if (isPressedKey ~= nil) then
			--make a list of keys so we can do things such as coloring
			tinsert(VP_SharpsP,self)
			fontstring:SetPoint("BOTTOM",self,"BOTTOM",0,23)
		else
			tinsert(VP_Sharps,self)
			fontstring:SetPoint("BOTTOM",self,"BOTTOM",0,20)
		end
	else
	--is a natural
		fontstring:SetTextColor(0,0,0)
		if (isPressedKey ~= nil) then
			tinsert(VP_NaturalsP,self)
			fontstring:SetPoint("BOTTOM",self,"BOTTOM",0,34)
		else
			tinsert(VP_Naturals,self)
			fontstring:SetPoint("BOTTOM",self,"BOTTOM",0,30)
		end
	end
	--hide the extra octaves and put them in a list
	if (not isPressedKey ~= nil and hideExtraKeys) then
		if (strmatch(key,"1") ~= nil or strmatch(key,"2") ~= nil or (strmatch(key,"8") ~= nil and key ~= "c8") or strmatch(key,"9") ~= nil) then
			tinsert(VP_MoreKeys,self)
			self:Hide()
		end
	end
	if (not VP_Settings.keysHidden) then
		if (not SetKeyText(frameName)) then
			_G[frameName.."Text"]:SetText("")
		end
	end
end

local function SetButtonBackdropColor()
	local r,g,b,a = VP_Settings.Buttons[1],VP_Settings.Buttons[2],VP_Settings.Buttons[3],VP_Settings.Buttons[4]
	VP_ToggleKeyboardButton:SetBackdropColor(r,g,b,a)
	VP_ClosePianoButton:SetBackdropColor(r,g,b,a)
	VP_MoreKeysButton:SetBackdropColor(r,g,b,a)
	VP_PianoOptionsButton:SetBackdropColor(r,g,b,a)
end

local function SetButtonBorderColor()
	local r,g,b,a = VP_Settings.ButtonsBorder[1],VP_Settings.ButtonsBorder[2],VP_Settings.ButtonsBorder[3],VP_Settings.ButtonsBorder[4]
	VP_ToggleKeyboardButton:SetBackdropBorderColor(r,g,b,a)
	VP_ClosePianoButton:SetBackdropBorderColor(r,g,b,a)
	VP_MoreKeysButton:SetBackdropBorderColor(r,g,b,a)
	VP_PianoOptionsButton:SetBackdropBorderColor(r,g,b,a)
end

local function SetBGBackdrop()
	local r,g,b,a = VP_Settings.Background[1],VP_Settings.Background[2],VP_Settings.Background[3],VP_Settings.Background[4]
	VP_PianoHeader:SetBackdropColor(1,1,1,a) --header needs to be original color
	VP_PianoOptionsFrame:SetBackdropColor(r,g,b,a)
	VP_MainPianoWindow:SetBackdropColor(r,g,b,a)
	VP_KeybindWrapper:SetBackdropColor(r,g,b,a)
end

function VP_SetKeyBackdrop()
	for i, name in ipairs(VP_NaturalsP) do
		name:SetBackdropColor(VP_Settings.NaturalsP[1],VP_Settings.NaturalsP[2],VP_Settings.NaturalsP[3],VP_Settings.NaturalsP[4])
	end
	for i, name in ipairs(VP_SharpsP) do
		name:SetBackdropColor(VP_Settings.SharpsP[1],VP_Settings.SharpsP[2],VP_Settings.SharpsP[3],VP_Settings.SharpsP[4])
	end
	for i, name in ipairs(VP_Naturals) do
		name:SetBackdropColor(VP_Settings.Naturals[1],VP_Settings.Naturals[2],VP_Settings.Naturals[3],VP_Settings.Naturals[4])
	end
	for i, name in ipairs(VP_Sharps) do
		name:SetBackdropColor(VP_Settings.Sharps[1],VP_Settings.Sharps[2],VP_Settings.Sharps[3],VP_Settings.Sharps[4])
	end
end

local function RunHandlerScripts()
	VP_PianoScaleSlider:SetScript("OnValueChanged", function(self,value)
		VP_Settings.Scale = round(value, 2)
		VP_PianoHeader:SetScale(VP_Settings.Scale)
		VP_PianoScaleSliderValue:SetText(VP_Settings.Scale)
	end)
	VP_DimSlider:SetScript("OnValueChanged", function(self,value) 
		VP_Settings.DimOpacity = round(value, 2)
		VP_DimFrame:SetBackdropColor(VP_Settings.DimBackground[1],VP_Settings.DimBackground[2],VP_Settings.DimBackground[3],VP_Settings.DimOpacity)
		VP_DimSliderValue:SetText(VP_Settings.DimOpacity)
	end)
	VP_PianoTransparencySlider:SetScript("OnValueChanged", function(self,value)
		local dimvalue = round(value, 2)
		VP_Settings.Buttons[4] = dimvalue
		VP_Settings.ButtonsBorder[4] = dimvalue
		VP_Settings.Background[4] = dimvalue
		VP_Settings.Naturals[4] = dimvalue
		VP_Settings.NaturalsP[4] = dimvalue
		VP_Settings.Sharps[4] = dimvalue
		VP_Settings.SharpsP[4] = dimvalue
		SetButtonBackdropColor()
		SetButtonBorderColor()
		VP_SetKeyBackdrop()
		SetBGBackdrop()
		VP_PianoTransparencySliderValue:SetText(round(dimvalue, 2))
	end)
	VP_SpeedSlider:SetScript("OnValueChanged", function(self,value)
		VP_Settings.Speed = round(value, 1)
		VP_SpeedSliderValue:SetText("Speed: "..VP_Settings.Speed)
		if VP_Slider:IsVisible() then
			local songLength = 0
			for i,notelength in ipairs(VP_time) do
				songLength = songLength + (notelength/VP_Settings.Speed)
			end
			VP_SliderHigh:SetText(date("%M:%S", songLength))
		end
	end)
end

function VP_FormatSong(rawstring)
	local timeCodes = {}
	local Note = {}
	local formattedSong = {strsplit("$",rawstring)}
	if (formattedSong == nil) then
	--stack overflow if there are too many notes, so we first split by 200 at every "$"
		isLargeString = false;
		formattedSong = {strsplit(",",Scriptbox:GetText())}
	else
		isLargeString = true;
	end
	for i, name in ipairs(formattedSong) do
		if (isLargeString) then
			local notes = {strsplit(",",name)}
			  for j, name2 in ipairs(notes) do
				local index = string.find(name2, ":")
				if (index ~= nil) then
					tinsert(timeCodes,tonumber(strsub(name2, index+1)))
					tinsert(Note,strsub(name2, 1, index-1))
					end
				end
		else
			local index = string.find(name, ":")
			if (index ~= nil) then
				tinsert(timeCodes, tonumber(strsub(name, index+1)))
				tinsert(Note,strsub(name, 1, index-1))
			end
		end
	end
	VP_playSong(timeCodes,Note)
end

local function createScriptFrames()
	local ScriptPanel = CreateFrame('Frame', "VP_ScriptPanel", UIParent)
		ScriptPanel:SetMovable(true)
		ScriptPanel:EnableMouse(true)
		ScriptPanel:RegisterForDrag("LeftButton")
		ScriptPanel:SetScript("OnDragStart", VP_ScriptPanel.StartMoving)
		ScriptPanel:SetScript("OnDragStop", VP_ScriptPanel.StopMovingOrSizing)
		ScriptPanel:SetWidth(400)
		ScriptPanel:SetHeight(200)
		ScriptPanel:SetPoint('BOTTOM', VP_PianoHeader, 'TOP', 0, 40)
		ScriptPanel:SetFrameStrata('BACKGROUND')
		ScriptPanel:SetBackdrop({
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
			bgFile = [[Interface\Buttons\WHITE8x8]],
			insets = {left = 10, right = 10, top = 10, bottom = 10
		}})
		ScriptPanel:SetBackdropColor(0, 0, 0, 0.7)
		
	local TypeTextButton = CreateFrame("BUTTON", "VP_TypeTextButton", ScriptPanel, "UIPanelButtonTemplate")
		TypeTextButton:SetWidth(80)
		TypeTextButton:SetHeight(25)
		TypeTextButton:SetText("Type Text")
		TypeTextButton:SetPoint("CENTER", ScriptPanel, "TOPLEFT",50,-20)
		TypeTextButton:SetScript("OnClick", function()
			if (VP_Scriptbox:IsAutoFocus()) then
				VP_Scriptbox:SetAutoFocus(false)
				VP_Scriptbox:ClearFocus();
				TypeTextButton:SetText("Type Text")
			else
				VP_Scriptbox:SetAutoFocus(true)
				TypeTextButton:SetText("Clear Focus")
				--Disable keyboard pressing
				if (VP_MainPianoWindow:IsKeyboardEnabled()) then
					VP_MainPianoWindow:EnableKeyboard(false)
					VP_MainPianoWindow:SetScript("OnKeyDown", nil)
					VP_ToggleKeyboardButtonText:SetText("Enable Keyboard")
				end
			end
		end)
		TypeTextButton:SetAlpha(1)
		TypeTextButton:Show()
		
		--not local so it can be used outside this function
	local Scriptbox = CreateFrame('EditBox', "VP_Scriptbox", VP_ScriptPanel)
		Scriptbox:SetMultiLine(true)
		Scriptbox:SetAutoFocus(false)
		Scriptbox:ClearFocus()
		Scriptbox:EnableMouse(true)
		Scriptbox:SetMaxLetters(99999)
		Scriptbox:SetFont('Fonts\\ARIALN.ttf', 13, 'THINOUTLINE')
		Scriptbox:SetWidth(360) -- 40 reserved for scrollbar
		Scriptbox:SetScript('OnEscapePressed', function() ScriptPanel:Hide(); VP_OpenScriptWindow:SetChecked(false) end)
		Scriptbox:SetScript('OnEditFocusGained', function(self) 
			VP_TypeTextButton:SetText("Clear Focus")
			self:SetAutoFocus(true)
			if (VP_MainPianoWindow:IsKeyboardEnabled()) then
				VP_MainPianoWindow:EnableKeyboard(false)
				VP_MainPianoWindow:SetScript("OnKeyDown", nil)
				VP_ToggleKeyboardButtonText:SetText("Enable Keyboard")
			end
		end)
		
	local Scroll = CreateFrame('ScrollFrame', 'VP_ScrollFrame', ScriptPanel, 'UIPanelScrollFrameTemplate')
		Scroll:SetPoint('TOPLEFT', ScriptPanel, 'TOPLEFT', 8, -35)
		Scroll:SetPoint('BOTTOMRIGHT', ScriptPanel, 'BOTTOMRIGHT', -35, 8)
		Scroll:SetScrollChild(Scriptbox)
		VP_ScriptPanel:Show()
		VP_OpenScriptWindow:SetChecked(true)
		
	local SendScriptButton = CreateFrame("BUTTON", nil, ScriptPanel, "UIPanelButtonTemplate")
		SendScriptButton:SetWidth(80)
		SendScriptButton:SetHeight(50)
		SendScriptButton:SetText("Send Script")
		SendScriptButton:SetPoint("CENTER", VP_ScriptPanel, "BOTTOMRIGHT",-40,-20)
		SendScriptButton:SetScript("OnClick", function()
				if (VP_PartyBroadcast:GetChecked() or VP_GuildBroadcast:GetChecked() or VP_RaidBroadcast:GetChecked() or (VP_PlayerBroadcast:GetChecked() and VP_WhisperTarget ~= nil)) then
					if (not VP_Sending) then
					local length = string.len(VP_Scriptbox:GetText())
					local messageslength = floor(length / 254) + 1
					local total = 0
					local firstIteration = true;
					VP_Sending = true;
					local VP_SendMessageFrame = CreateFrame("frame")
						VP_SendMessageFrame:SetScript("OnUpdate", function(self,elapsed) 
							total = total + elapsed
								if (messageslength > 0) then
									if (total > 0.2) then --restricting time of sending addon messages because of blizz restrictions
										local msgLen = messageslength
										if (messageslength < 10) then
											msgLen = "0"..msgLen
										end
										if (firstIteration) then
											stringToSend = "VP_MSG_LEN="..messageslength
										else
											stringToSend = msgLen.."|"..strsub(VP_Scriptbox:GetText(),((messageslength - 1) * 252) + 1,messageslength*252)
										end
										if (VP_PartyBroadcast:GetChecked()) then
											SendAddonMessage("VP_SCRIPT", stringToSend, "PARTY")
										end
										if (VP_GuildBroadcast:GetChecked()) then
											SendAddonMessage("VP_SCRIPT", stringToSend, "GUILD")
										end	
										if (VP_RaidBroadcast:GetChecked()) then
											SendAddonMessage("VP_SCRIPT", stringToSend, "RAID")
										end		
										if (VP_PlayerBroadcast:GetChecked() and VP_WhisperTarget ~= nil) then
											SendAddonMessage("VP_SCRIPT", stringToSend, "WHISPER", VP_WhisperTarget)
										end
										total = 0
										if (firstIteration) then
											firstIteration = false
										else
											messageslength = messageslength - 1
										end
										SendScriptButton:SetText("Sending ("..messageslength..")")
									end
								else
									VP_Sending = false;
									SendScriptButton:SetText("Send Script")
									VP_SendMessageFrame:SetScript("OnUpdate", nil)
								end
						end)
					end
				else
				VP_MSG("Error! No targets selected for broadcasting. Type /vp config and select a broadcasting channel")
			end
		end)
		SendScriptButton:Show()
		local PlayButton = CreateFrame("BUTTON", nil, SendScriptButton, "UIPanelButtonTemplate")
		PlayButton:SetWidth(80)
		PlayButton:SetHeight(50)
		PlayButton:SetText("Play Script")
		PlayButton:SetPoint("CENTER", SendScriptButton, "CENTER",-80,0)
		PlayButton:SetScript("OnClick", function() 
			if (not VP_PianoHeader:IsVisible()) then
				VPiano_TogglePianoFrame()
			end
			if (not VP_PlayingSong) then
				VP_Scriptbox:ClearFocus()
				VP_TypeTextButton:SetText("Type Text")
				VP_MSG("Playing script.")
				VP_PlayingSong = true
				VP_isPlayingPlaylist = false
				VP_FormatSong(VP_Scriptbox:GetText())
				if (VP_Scriptbox:IsAutoFocus()) then
					VP_Scriptbox:SetAutoFocus(false)
				end
			end
		end)
		PlayButton:SetAlpha(1)
		PlayButton:Show()

		local PlayRecordingBtn = CreateFrame("BUTTON", nil, PlayButton, "UIPanelButtonTemplate")
		PlayRecordingBtn:SetWidth(80)
		PlayRecordingBtn:SetHeight(50)
		PlayRecordingBtn:SetText("Play Record")
		PlayRecordingBtn:SetPoint("CENTER", PlayButton, "CENTER",-80,0)
		PlayRecordingBtn:SetScript("OnClick", function() 
			if (not VP_PianoHeader:IsVisible()) then
				VPiano_TogglePianoFrame()
			end
			if (not VP_PlayingSong) then
				VP_Scriptbox:ClearFocus()
				VP_TypeTextButton:SetText("Type Text")
				VP_MSG("Playing recording..")
				VP_PlayingSong = true
				VP_isPlayingPlaylist = false
				VP_playSong(VP_Settings.noteTime,VP_Settings.songNote)
				if (VP_Scriptbox:IsAutoFocus()) then
					VP_Scriptbox:SetAutoFocus(false)
				end
			end
		end)
		PlayRecordingBtn:Show()
		
		local ExportButton = CreateFrame("BUTTON", nil, PlayRecordingBtn, "UIPanelButtonTemplate")
		ExportButton:SetWidth(80)
		ExportButton:SetHeight(50)
		ExportButton:SetText("Export")
		ExportButton:SetPoint("CENTER", PlayRecordingBtn, "CENTER",-80,0)
		ExportButton:SetScript("OnClick", function()
			local VP_noteTimeString = ""
			for i, name in ipairs(VP_Settings.noteTime) do
				if (i % 200 == 0) then
					VP_noteTimeString = VP_noteTimeString .. "$" .. VP_Settings.songNote[i] ..":"..VP_Settings.noteTime[i]
				elseif (VP_noteTimeString == "") then
					VP_noteTimeString = VP_Settings.songNote[i] ..":"..VP_Settings.noteTime[i]
				else
					VP_noteTimeString = VP_noteTimeString .. "," .. VP_Settings.songNote[i] ..":"..VP_Settings.noteTime[i]
				end
			end
			if (VP_noteTimeString ~= nil) then
				VP_Scriptbox:SetText(VP_noteTimeString)
			end
		end)
		ExportButton:Show()
		
	local StartRecordingBtn = CreateFrame("BUTTON", nil, ExportButton, "UIPanelButtonTemplate")
		StartRecordingBtn:SetWidth(80)
		StartRecordingBtn:SetHeight(50)
		StartRecordingBtn:SetText("Record")
		StartRecordingBtn:SetPoint("CENTER", ExportButton, "CENTER",-80,0)
		StartRecordingBtn:SetScript("OnClick", function() 
			if (VP_isRecording) then
				VP_MSG("Stopped recording")
				VP_isRecording = false
				StartRecordingBtn:SetText("Record")
			else 
				VP_MSG("Recording")
				VP_isRecording = true
				VP_Settings.noteTime = {}
				VP_Settings.songNote = {}
				StartRecordingBtn:SetText("Stop Recording")
				VP_PianoHeader:Show()
				VP_Scriptbox:ClearFocus()
				VP_TypeTextButton:SetText("Type Text")
			end
		end)
		StartRecordingBtn:SetAlpha(1)
		StartRecordingBtn:Show()
		
	local CloseButton = CreateFrame("BUTTON", nil, VP_ScriptPanel, "UIPanelButtonTemplate")
		CloseButton:SetWidth(25)
		CloseButton:SetHeight(25)
		CloseButton:SetText("X")
		CloseButton:SetPoint("CENTER", VP_ScriptPanel, "TOPRIGHT",-22,-20)
		CloseButton:SetScript("OnClick", function() VP_ScriptPanel:Hide(); VP_OpenScriptWindow:SetChecked(false) end)
		CloseButton:Show()
end

function VP_openScriptPanel()
	if (VP_ScriptPanel ~= nil) then
		if (VP_ScriptPanel:IsVisible()) then
			VP_ScriptPanel:Hide()
			VP_OpenScriptWindow:SetChecked(false)
		else
			VP_ScriptPanel:Show()
			VP_OpenScriptWindow:SetChecked(true)
		end
	else
		createScriptFrames()
	end
end

local function VP_ChangeColor(restore)
	local newR, newG, newB, newA;
	if restore then -- The user bailed, we extract the old color from the table created by ShowColorPicker.
		newR, newG, newB, newA = unpack(restore);
	else
		newA, newR, newG, newB = OpacitySliderFrame:GetValue(), ColorPickerFrame:GetColorRGB();
	end
	if (colorFrame == "VP_MainPianoWindow") then
		VP_Settings.Background[1],VP_Settings.Background[2],VP_Settings.Background[3],VP_Settings.Background[4] = newR,newG,newB,newA
		SetBGBackdrop()
	elseif (colorFrame == "natural") then
		VP_Settings.Naturals[1],VP_Settings.Naturals[2],VP_Settings.Naturals[3],VP_Settings.Naturals[4] = newR,newG,newB,newA
		for i, name in ipairs(VP_Naturals) do
			name:SetBackdropColor(VP_Settings.Naturals[1],VP_Settings.Naturals[2],VP_Settings.Naturals[3],VP_Settings.Naturals[4])
		end
	elseif (colorFrame == "sharp") then
		VP_Settings.Sharps[1],VP_Settings.Sharps[2],VP_Settings.Sharps[3],VP_Settings.Sharps[4] = newR,newG,newB,newA
		for i, name in ipairs(VP_Sharps) do
			name:SetBackdropColor(VP_Settings.Sharps[1],VP_Settings.Sharps[2],VP_Settings.Sharps[3],VP_Settings.Sharps[4])
		end
	elseif (colorFrame == "naturalP") then
		VP_Settings.NaturalsP[1],VP_Settings.NaturalsP[2],VP_Settings.NaturalsP[3],VP_Settings.NaturalsP[4] = newR,newG,newB,newA
		for i, name in ipairs(VP_NaturalsP) do
			name:SetBackdropColor(VP_Settings.NaturalsP[1],VP_Settings.NaturalsP[2],VP_Settings.NaturalsP[3],VP_Settings.NaturalsP[4])
		end
	elseif (colorFrame == "sharpP") then
		VP_Settings.SharpsP[1],VP_Settings.SharpsP[2],VP_Settings.SharpsP[3],VP_Settings.SharpsP[4] = newR,newG,newB,newA
		for i, name in ipairs(VP_SharpsP) do
			name:SetBackdropColor(VP_Settings.SharpsP[1],VP_Settings.SharpsP[2],VP_Settings.SharpsP[3],VP_Settings.SharpsP[4])
		end
	elseif (colorFrame == "button") then
		VP_Settings.Buttons[1],VP_Settings.Buttons[2],VP_Settings.Buttons[3],VP_Settings.Buttons[4] = newR,newG,newB,newA
		SetButtonBackdropColor()
	elseif (colorFrame == "buttonborder") then
		VP_Settings.ButtonsBorder[1],VP_Settings.ButtonsBorder[2],VP_Settings.ButtonsBorder[3],VP_Settings.ButtonsBorder[4] = newR,newG,newB,newA
		SetButtonBorderColor()
	elseif (colorFrame == "dimbg") then
		VP_Settings.DimBackground[1],VP_Settings.DimBackground[2],VP_Settings.DimBackground[3] = newR,newG,newB
	end
end

local function ShowColorPicker(r, g, b, a)
	ColorPickerFrame:SetColorRGB(r,g,b);
	if (a ~= -1) then
		ColorPickerFrame.hasOpacity = true
	end
	ColorPickerFrame.opacity = a;
	ColorPickerFrame.previousValues = {r,g,b,a};
	ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = VP_ChangeColor, VP_ChangeColor, VP_ChangeColor;
	ColorPickerFrame:Hide(); -- Need to run the OnShow handler.
	ColorPickerFrame:ClearAllPoints()
	ColorPickerFrame:SetPoint('TOPRIGHT', VP_MainPianoWindow, 'BOTTOMRIGHT')
	if (not VP_PianoHeader:IsVisible()) then
		VPiano_TogglePianoFrame()
	end
	ColorPickerFrame:Show();
end

local function setBinds()
	for i, self in pairs(VP_Keys) do
		if (not SetKeyText(self:GetName())) then
			_G[self:GetName().."Text"]:SetText("")
		end
	end
end

function VP_ToggleKeybinds()
	if (not VP_HideKeybinds:GetChecked()) then
		VP_HideKeybinds:SetChecked(false)
		VP_Settings.keysHidden = false
		setBinds()
	else
		VP_HideKeybinds:SetChecked(true)
		VP_Settings.keysHidden = true
		for i, self in pairs(VP_Keys) do
			_G[self:GetName().."Text"]:SetText("")
		end
	end
end


local function handler(msg)
	msg = strlower(msg)
	if (msg == "about") then
		VP_MSG("Virtual Piano, a musical piano addon played with your keyboard and mouse!",true)
	elseif (msg == "play" or msg == "") then
		if (not VP_PianoHeader:IsVisible()) then
			VPiano_TogglePianoFrame()
		end	
	elseif (msg == "config" or msg == "options") then
		VPiano_ToggleOptionsFrame()
		VPiano_TogglePianoFrame()
	elseif (msg == "demo") then
		if (not VP_PianoHeader:IsVisible()) then
			VPiano_TogglePianoFrame()
		end
		if (not VP_PlayingSong) then
			VP_PlayingSong = true
			if (not VP_PianoHeader:IsVisible()) then
				VPiano_TogglePianoFrame()
			end
			VP_isPlayingPlaylist = false
			VP_FormatSong(VP_PlayDemo())
		end
	elseif (msg == "script") then
		VP_openScriptPanel()
	elseif (msg == "color sharps pressed") then
		colorFrame = "sharpP"
		ShowColorPicker(VP_Settings.SharpsP[1],VP_Settings.SharpsP[2],VP_Settings.SharpsP[3], VP_Settings.SharpsP[4])
	elseif (msg == "color naturals pressed") then
		colorFrame = "naturalP"
		ShowColorPicker(VP_Settings.NaturalsP[1],VP_Settings.NaturalsP[2],VP_Settings.NaturalsP[3], VP_Settings.NaturalsP[4])
	elseif (msg == "color sharps") then
		colorFrame = "sharp"
		ShowColorPicker(VP_Settings.Sharps[1],VP_Settings.Sharps[2],VP_Settings.Sharps[3], VP_Settings.Sharps[4])
	elseif (msg == "color naturals") then
		colorFrame = "natural"
		ShowColorPicker(VP_Settings.Naturals[1],VP_Settings.Naturals[2],VP_Settings.Naturals[3], VP_Settings.Naturals[4])
	elseif (msg == "color bg") then
		colorFrame = "VP_MainPianoWindow"
		ShowColorPicker(VP_Settings.Background[1],VP_Settings.Background[2],VP_Settings.Background[3], VP_Settings.Background[4])
	elseif (msg == "color buttons") then
		colorFrame = "button"
		ShowColorPicker(VP_Settings.Buttons[1],VP_Settings.Buttons[2],VP_Settings.Buttons[3], VP_Settings.Buttons[4])
	elseif (msg == "color button borders") then
		colorFrame = "buttonborder"
		ShowColorPicker(VP_Settings.ButtonsBorder[1],VP_Settings.ButtonsBorder[2],VP_Settings.ButtonsBorder[3], VP_Settings.ButtonsBorder[4])
	elseif (msg == "color dim bg") then
		colorFrame = "dimbg"
		ShowColorPicker(VP_Settings.DimBackground[1],VP_Settings.DimBackground[2],VP_Settings.DimBackground[3],-1)
	elseif (strmatch(msg, "color") ~= nil) then
		VP_MSG("Color format:")
		VP_MSG("'/vp color sharps' - for the black (sharp) keys",true)
		VP_MSG("'/vp color sharps pressed' - for the black (sharp) keys when they're pressed",true)
		VP_MSG("'/vp color naturals'  - for the white (natural) keys",true)
		VP_MSG("'/vp color naturals pressed' - for the white (natural) keys when they're pressed",true)
		VP_MSG("'/vp color bg' - for the piano background",true)
		VP_MSG("'/vp color buttons' - for the buttons",true)
		VP_MSG("'/vp color dim bg' - for the color of the dimmed background",true)
		VP_MSG("'/vp color button borders' - for the button borders",true)
	elseif (strmatch(msg,"reset confirm") ~= nil) then
		VP_InitSettings()
		ReloadUI()
	elseif (strmatch(msg,"reset") ~= nil) then
		VP_MSG("Type '/vp reset confirm' to confirm reset of ALL addon settings, and keybind profiles")
	elseif (strmatch(msg,"create") ~= nil) then
		local profile = strsub(msg,strfind(msg,"create")+7)
		if (VP_Keybinds[profile] == nil and profile ~= "") then
			VP_Keybinds[profile] = {}
			tinsert(VP_Settings.Profiles,profile)
			VP_MSG("Created keybind profile: "..profile)
		else
			VP_MSG("Keybind profile is nil or already exists. Type /vp keybind delete (profilename) if you would like to delete it.")
		end
	elseif (strmatch(msg,"delete") ~= nil) then
		VP_deleteProfile(strsub(msg,strfind(msg,"delete")+7))
	elseif (msg == "keybind") then
		VP_MSG("Keybind options.")
		VP_MSG("/vp create (profilename) - Creates a keybind profile",true)
		VP_MSG("/vp delete (profilename) - Deletes a keybind profile",true)
	else
		VP_MSG("Commands:")
		VP_MSG("/vp play - Opens the keyboard",false)
		VP_MSG("/vp config - Opens configuration panel",false)
		VP_MSG("/vp script - Record, play a script",false)
		VP_MSG("/vp demo - Plays a demo",false)
		VP_MSG("/vp color - Color your piano and keys",false)
		VP_MSG("/vp keybind - Set keybindings to the piano",false)
	end
end

function round(input, places)
    if not places then
        places = 0
    end
    if type(input) == "number" and type(places) == "number" then
        local pow = 1
        for i = 1, ceil(places) do
            pow = pow * 10
        end
        return floor(input * pow + 0.5) / pow
    end
end

function VPiano_TogglePianoFrame()
	if (VP_PianoHeader:IsVisible()) then
		if (VP_MainPianoWindow:IsKeyboardEnabled()) then
			VP_MainPianoWindow:EnableKeyboard(false)
		end
		if (VP_PianoOptionsFrame:IsVisible()) then
			VPiano_ToggleOptionsFrame()
		end	
		if (VP_KeybindWrapper:IsVisible()) then
			VP_KeybindWrapper:Hide()
			VP_BindToggle:SetChecked(false)
		end
		if (VP_DimFrame:IsVisible()) then
			VP_ToggleDim()
			VP_DimToggle:SetChecked(false)
		end
		UIFrameFadeOut(VP_PianoHeader, 0.50, 1, 0)
		VP_PianoHeader:SetScript("OnUpdate", function()
			if (not UIFrameIsFading(VP_PianoHeader)) then
				VP_PianoHeader:Hide()
				VP_PianoHeader:SetScript("OnUpdate", nil)
			end
		end)
		VP_ToggleKeyboardButtonText:SetText("Enable Keyboard")
	else
		VP_PianoHeader:ClearAllPoints()
		VP_PianoHeader:SetPoint("CENTER",  0, 300)
		UIFrameFadeIn(VP_PianoHeader, 0.65, 0, 1)
	end
end


function VPiano_ToggleMoreKeys()
local screenWidth = GetScreenWidth() * UIParent:GetEffectiveScale()
local currentScale = VP_PianoHeader:GetScale()
local windowWidth = VP_MainPianoWindow:GetWidth()
local opacity = 1
	if (VP_c9Key:IsVisible()) then
		VP_MoreKeysButtonText:SetText("More Keys");
		VP_MainPianoWindow:SetScript("OnUpdate",function(self)
			if (currentScale < VP_Settings.Scale) then			
				for i = VP_Settings.Scale, 0, -0.0005 do
					if ((windowWidth * i) <= screenWidth) then
						currentScale = i
						VP_PianoHeader:SetScale(currentScale)
						break
					end
				end
			end 
			self:SetWidth(windowWidth)
			VP_KeysFrame:SetAlpha(opacity)
			opacity = opacity - 0.02
			if ((windowWidth - 10) <= 1450) then
				if (opacity <= 0) then
					self:SetWidth(1450)
						for i, self in pairs(VP_MoreKeys) do
							VP_MoreKeyPoints[self] = {self:GetPoint()}
							self:ClearAllPoints();
							self:Hide()
						end
					VP_c8Key:SetBackdrop({bgFile = "Interface\\AddOns\\Virtualpiano\\Images\\FKey.tga"});
					VP_c8Keyf:SetBackdrop({bgFile = "Interface\\AddOns\\Virtualpiano\\Images\\FKey.tga"});
					VP_c8Key:SetBackdropColor(VP_Settings.Naturals[1],VP_Settings.Naturals[2],VP_Settings.Naturals[3],VP_Settings.Naturals[4])
					VP_c8Keyf:SetBackdropColor(VP_Settings.NaturalsP[1],VP_Settings.NaturalsP[2],VP_Settings.NaturalsP[3],VP_Settings.NaturalsP[4])
					VP_c3Key:ClearAllPoints();VP_c3Key:SetPoint("TOPLEFT", "VP_KeysFrame", "TOPLEFT", 40, -50)
					VP_c3Keyf:ClearAllPoints();VP_c3Keyf:SetPoint("TOPLEFT", "VP_KeysFrame", "TOPLEFT", 40, -52)
					VP_KeysFrame:SetWidth(1450)
					UIFrameFadeIn(VP_KeysFrame, 0.85, 0, 1)
					VP_Settings.Scale = currentScale
					VP_PianoScaleSliderValue:SetText(round(VP_Settings.Scale, 2))
					self:SetScript("OnUpdate",nil)
				end
			else
				windowWidth = windowWidth - 10
			end
		end);
	else
		VP_MoreKeysButtonText:SetText("Less Keys");
		VP_MainPianoWindow:SetScript("OnUpdate",function(self)
			if ((windowWidth * VP_Settings.Scale) > screenWidth) then
				for i = VP_Settings.Scale, 0, -0.0005 do
					if ((windowWidth * i) <= screenWidth) then
						currentScale = i
						VP_PianoHeader:SetScale(currentScale)
						break
					end
				end
			end
			self:SetWidth(windowWidth)
			VP_KeysFrame:SetAlpha(opacity);
			opacity = opacity - 0.02
			if ((windowWidth + 10) >= 2060) then
				if (opacity <= 0) then
				self:SetWidth(2060)
				VP_KeysFrame:SetWidth(2060)
				local parentFrame = "VP_KeysFrame"
				for i, self in pairs(VP_MoreKeys) do
					if VP_MoreKeyPoints[self] == nil then
						VP_MoreKeyPoints[self] = {self:GetPoint()}
					end
						self:ClearAllPoints();
						self:SetPoint(VP_MoreKeyPoints[self][1],VP_MoreKeyPoints[self][2],VP_MoreKeyPoints[self][3],VP_MoreKeyPoints[self][4],VP_MoreKeyPoints[self][5])
					if (not (strmatch(self:GetName(),"Keyf") ~= nil)) then
						self:Show()
					end
				end
				VP_c3Keyf:ClearAllPoints();VP_c3Keyf:SetPoint("TOPLEFT", "VP_b2Keyf", "TOPRIGHT");
				VP_c3Key:ClearAllPoints();VP_c3Key:SetPoint("TOPLEFT", "VP_b2Key", "TOPRIGHT");
				VP_c8Key:SetBackdrop({bgFile = "Interface\\AddOns\\Virtualpiano\\Images\\LKey.tga"});
				VP_c8Keyf:SetBackdrop({bgFile = "Interface\\AddOns\\Virtualpiano\\Images\\LKey.tga"});
				VP_c8Key:SetBackdropColor(VP_Settings.Naturals[1],VP_Settings.Naturals[2],VP_Settings.Naturals[3],VP_Settings.Naturals[4])
				VP_c8Keyf:SetBackdropColor(VP_Settings.NaturalsP[1],VP_Settings.NaturalsP[2],VP_Settings.NaturalsP[3],VP_Settings.NaturalsP[4])
				UIFrameFadeIn(VP_KeysFrame, 0.85, 0, 1)
				VP_PianoScaleSliderValue:SetText(round(currentScale, 2))
				self:SetScript("OnUpdate",nil)
				end
			else
				windowWidth = windowWidth + 10
			end
		end)
	end
end

function VP_CreateShuffleList()
	VP_ShuffleIterator = 1
	VP_ShuffledPlaylist = {}
	-- Create a table of track numbers 1-max
	for i = 1, VP_MaxTracksInPlaylist do
		VP_ShuffledPlaylist[i] = i
	end
	-- Shuffle the track numbers
	for i = 1, VP_MaxTracksInPlaylist do
	   local j = math.random(i, VP_MaxTracksInPlaylist)
	   VP_ShuffledPlaylist[i], VP_ShuffledPlaylist[j] = VP_ShuffledPlaylist[j], VP_ShuffledPlaylist[i]
	end
	-- Make the first track the starting track number for the shuffled list
	for i = 1, VP_MaxTracksInPlaylist do
		if VP_ShuffledPlaylist[i] == VP_TrackNum then
			VP_ShuffledPlaylist[i], VP_ShuffledPlaylist[1] = VP_ShuffledPlaylist[1], VP_ShuffledPlaylist[i]
			break
		end
	end
end

function VP_ToggleDim()
	if (VP_DimFrame:IsVisible() or UIFrameIsFading(VP_DimFrame)) then
		UIFrameFadeIn(MinimapCluster, 0.85, 0, 1)
		UIFrameFadeIn(UIParent, 0.85, 0, 1)
		UIFrameFadeOut(VP_DimFrame, 0.85, 1, 0)
		VP_DimFrame:SetScript("OnUpdate", function()
			if (not UIFrameIsFading(VP_DimFrame)) then
				VP_DimFrame:Hide()
				VP_DimFrame:SetScript("OnUpdate", nil)
			end
		end)
	else
		if UIFrameIsFading(UIParent) then
			UIFrameFlashStop(MinimapCluster)
			UIFrameFlashStop(UIParent)
		else
		--UIFrameFadeOut sometimes causes taints here
		MinimapCluster:Hide() 
		VP_DimFrame:SetBackdropColor(VP_Settings.DimBackground[1],VP_Settings.DimBackground[2],VP_Settings.DimBackground[3],VP_Settings.DimOpacity)
		UIFrameFadeOut(UIParent, 0.85, 1, 0)
		UIFrameFadeIn(VP_DimFrame, 0.85, 0, 1)
		end
	end
end

function VPiano_ToggleOptionsFrame()
	if (VP_PianoOptionsFrame:IsVisible()) then
		VP_PianoOptionsFrame:Hide()
		VP_KeybindWrapper:Hide()
	else
		if (VP_BindToggle:GetChecked()) then
			VP_KeybindWrapper:Show()
		end
		VP_PianoOptionsFrame:ClearAllPoints()
		VP_PianoOptionsFrame:SetPoint("BOTTOM",  0, 100)
		VP_PianoOptionsFrame:Show()
	end
end	

function VPiano_ToggleKeyboard()
	if (VP_MainPianoWindow:IsKeyboardEnabled()) then
		VP_MainPianoWindow:EnableKeyboard(false)
		VP_MainPianoWindow:SetScript("OnKeyDown", nil)
		VP_ToggleKeyboardButtonText:SetText("Enable Keyboard")
	else
		VP_MainPianoWindow:EnableKeyboard(true)
		VP_MainPianoWindow:SetScript("OnKeyDown", VPiano_DownKey)
		VP_ToggleKeyboardButtonText:SetText("Disable Keyboard")
	end
end	
function VPiano_CloseAll()
	if (VP_PianoOptionsFrame:IsVisible()) then
		VPiano_ToggleOptionsFrame()
	end
	if (VP_MainPianoWindow:IsKeyboardEnabled()) then
		VPiano_ToggleKeyboard()
	end
	if (VP_PianoHeader:IsVisible()) then
		VPiano_TogglePianoFrame()
	end
end


function VP_ToggleCurrPlaying()
	if (VP_PartyReceive:GetChecked() or VP_GuildReceive:GetChecked() or VP_PlayerReceive:GetChecked() or VP_RaidReceive:GetChecked()) then
		VP_CurrentlyPlaying:Show()
		VP_CurrentlyPlayingText:SetText("Currently Playing: ")
	else
		VP_CurrentlyPlaying:Hide()
	end
end

--Dropdown menu stuff
local function VP_DropDownMenuOnClick(self)
	if self == nil then self = this end
	VP_Settings.KeybindProfile = self.value 
	UIDropDownMenu_SetSelectedID(VP_DropDownMenu, self:GetID())
	VP_Settings.KeybindProfileID = self:GetID()
	setBinds()
	VP_MSG("Set keybind profile to "..self.value)
end

local function VP_DropDownMenuInitialize(self, level)
   local info = UIDropDownMenu_CreateInfo()
   for k,v in ipairs(VP_Settings.Profiles) do
      info = UIDropDownMenu_CreateInfo()
      info.text = v
      info.value = v
      info.func = VP_DropDownMenuOnClick
      UIDropDownMenu_AddButton(info, level)
   end
end

local function CreateDropDownButton()
   CreateFrame("Button", "VP_DropDownMenu", VP_MainPianoWindow, "UIDropDownMenuTemplate")
   VP_DropDownMenu:ClearAllPoints()
   VP_DropDownMenu:SetPoint("TOPRIGHT", -17, -10)
   UIDropDownMenu_Initialize(VP_DropDownMenu, VP_DropDownMenuInitialize)
   UIDropDownMenu_SetSelectedID(VP_DropDownMenu, VP_Settings.KeybindProfileID)
   if (isDeprecated) then
   	   UIDropDownMenu_SetWidth(100,VP_DropDownMenu);
	   UIDropDownMenu_SetButtonWidth(124, VP_DropDownMenu)
	   UIDropDownMenu_JustifyText("LEFT", VP_DropDownMenu)
   else
	   UIDropDownMenu_SetWidth(VP_DropDownMenu, 100);
	   UIDropDownMenu_SetButtonWidth(VP_DropDownMenu, 124)
	   UIDropDownMenu_JustifyText(VP_DropDownMenu, "LEFT")
   end
end

local function VP_PlaylistMenuOnClick(self)
	if self == nil then self = this end
	UIDropDownMenu_SetSelectedID(VP_PlaylistMenu, self:GetID()) 
	if (VP_SelectedPlaylist ~= self.value) then
		if isDeprecated then VP_SelectedPlaylist = this.value else VP_SelectedPlaylist = self.value end
		VP_TrackNum = 1
		for songName, _ in pairs(VP_Playlist[VP_SelectedPlaylist][VP_TrackNum]) do
			UIDropDownMenu_SetSelectedID(VP_Tracklist, VP_TrackNum)
			if (not isDeprecated) then UIDropDownMenu_SetText(VP_Tracklist, VP_TrackNum..": "..songName) else UIDropDownMenu_SetText(VP_TrackNum..": "..songName, VP_Tracklist)  end
		end
		VP_MaxTracksInPlaylist = getn(VP_Playlist[VP_SelectedPlaylist])
		if (VP_ShuffleMode) then
			VP_CreateShuffleList()
		end
	else
		UIDropDownMenu_SetSelectedID(VP_Tracklist, VP_TrackNum)
	end
	UIDropDownMenu_Initialize(VP_Tracklist, VP_TracklistInitialize)
end

local function VP_PlaylistInitialize(self, level)
   local info = UIDropDownMenu_CreateInfo()
	if (VP_ShuffleMode) then
		VP_CreateShuffleList()
	end
	for k in pairs(VP_Playlist) do
      info = UIDropDownMenu_CreateInfo()
      info.text = k
      info.value = k
      info.func = VP_PlaylistMenuOnClick
      UIDropDownMenu_AddButton(info, level)
   end
end

local function CreatePlaylistDropdown()
	VP_PlaylistMenu = CreateFrame("Button", "VP_PlaylistMenu", VP_MainPianoWindow, "UIDropDownMenuTemplate")
	VP_PlaylistMenu:ClearAllPoints()
	VP_PlaylistMenu:SetPoint("TOPLEFT", 25, -10)
	UIDropDownMenu_Initialize(VP_PlaylistMenu, VP_PlaylistInitialize)
	if (not isDeprecated) then
		UIDropDownMenu_SetWidth(VP_PlaylistMenu, 100);
		UIDropDownMenu_SetButtonWidth(VP_PlaylistMenu, 124)
		UIDropDownMenu_JustifyText(VP_PlaylistMenu, "LEFT")
	else
		UIDropDownMenu_SetWidth(100, VP_PlaylistMenu);
		UIDropDownMenu_SetButtonWidth(124, VP_PlaylistMenu)
		UIDropDownMenu_JustifyText("LEFT", VP_PlaylistMenu)
	end
end

local function VP_TracklistOnClick(self)
	if self == nil then self = this end
	VP_TrackNum = self.value
	VP_isPlayingPlaylist = true
	if (VP_ShuffleMode) then
		VP_CreateShuffleList()
	end
	VP_PlayTrack(_,true)
end

local function VP_TracklistInitialize(self, level)
   local info = UIDropDownMenu_CreateInfo()
   for k,v in ipairs(VP_Playlist[VP_SelectedPlaylist]) do
		for k2, v2 in pairs(VP_Playlist[VP_SelectedPlaylist][k]) do
		  info = UIDropDownMenu_CreateInfo()
		  info.text = k..": "..k2
		  info.value = k
		  info.func = VP_TracklistOnClick
		  UIDropDownMenu_AddButton(info, level)
		end
   end
end

local function CreateTracklistDropdown()
   VP_Tracklist = CreateFrame("Button", "VP_Tracklist", VP_PlaylistMenu, "UIDropDownMenuTemplate")
   VP_Tracklist:ClearAllPoints()
   VP_Tracklist:SetPoint("LEFT", 120, 0)
   UIDropDownMenu_Initialize(VP_Tracklist, VP_TracklistInitialize)
   	if (not isDeprecated) then
		UIDropDownMenu_SetWidth(VP_Tracklist, 200);
		UIDropDownMenu_SetButtonWidth(VP_Tracklist, 124)
		UIDropDownMenu_JustifyText(VP_Tracklist, "LEFT")
   else
		UIDropDownMenu_SetWidth(200, VP_Tracklist);
		UIDropDownMenu_SetButtonWidth(124, VP_Tracklist)
		UIDropDownMenu_JustifyText("LEFT", VP_Tracklist)
   end
end

function VP_TriggerDropDown()
	--Indexed playlist to use for chat functions
	local playlistIterator = 0
	for i in pairs(VP_Playlist) do
		playlistIterator = playlistIterator + 1
		IndexedPlaylist[playlistIterator] = i
	end
	VP_SelectedPlaylist = IndexedPlaylist[1]
	VP_MaxTracksInPlaylist = getn(VP_Playlist[VP_SelectedPlaylist])
	VP_PlayStopButton:Show()
	VP_PauseButton:Show()
	VP_NextTrackButton:Show()
	VP_PreviousTrackButton:Show()

	if VP_PlaylistMenu ~= nil then
		UIDropDownMenu_Initialize(VP_PlaylistMenu, VP_PlaylistInitialize)
	else
		CreatePlaylistDropdown()
		CreateTracklistDropdown()
		VP_ShuffleButton:SetPoint("LEFT", "VP_Tracklist", "RIGHT",10)
		VP_ShuffleButton:Show()
	end
	UIDropDownMenu_SetSelectedID(VP_PlaylistMenu, 1)
	if (isDeprecated) then 
		UIDropDownMenu_SetText(VP_SelectedPlaylist, VP_PlaylistMenu) 
	else
		UIDropDownMenu_SetText(VP_PlaylistMenu, VP_SelectedPlaylist)
	end
end

local function createPressedKeys()
	local pressedKeys = {}
	for i, name in pairs(VP_Keys) do
		local keyName = name:GetName().."f"
		local _, inherits = next(name:GetBackdrop())
		if (strmatch(keyName, "s") ~= nil) then
			inherits = "VP_BKeyTP"
		else
			inherits = "VP_"..strsub(inherits,38).."TP"
		end
		CreateFrame("Frame", keyName, VP_KeysFrame, inherits)
		_G[keyName]:SetPoint("CENTER", name, "CENTER",0,-3)
		_G[keyName]:Hide()
		tinsert(pressedKeys,_G[name:GetName().."f"])
	end
	for i, name in pairs(pressedKeys) do
		tinsert(VP_Keys,name)
	end
end

function VP_EventHandler(self, event, ...)
	local addon,arg2,arg3,arg4 = select(1,...)	
	if (event == "ADDON_LOADED" and addon == "Virtualpiano") then
		if (VP_Settings == nil) then
			VP_InitSettings()
		end
		if (VP_Settings.Version ~= nil) then
			if (VP_Settings.Version < CurrentMajorVersion) then
				VP_InitSettings()
			end
		else
			VP_InitSettings()
		end
		SlashCmdList["VIRTUALP"] = handler
		createPressedKeys()
		for i, name in pairs(VP_Keys) do
			SetKey(name,true) --Call SetKeythe SetKeys to loop through every key on the piano and set text
		end	
		
		VP_SetKeyBackdrop() -- Color the keys
		VP_SetKeybindBtn:Disable()
		VP_SetNotebindBtn:Disable()
		VP_UnbindNoteBtn:Disable()
		VP_UnbindBtn:Disable()
		SetButtonBackdropColor()
		SetButtonBorderColor()
		SetBGBackdrop()
		
		VP_DimFrame:SetBackdropColor(VP_Settings.DimBackground[1],VP_Settings.DimBackground[2],VP_Settings.DimBackground[3],VP_Settings.DimOpacity)
		VP_HideKeybinds:SetChecked(VP_Settings.keysHidden)
		--Starting events here because they rely on VP_Settings, which is nil before the addon fully loads
		VP_PianoScaleSlider:SetValue(VP_Settings.Scale)
		VP_PianoScaleSliderValue:SetText(round(VP_Settings.Scale, 2))
		VP_PianoHeader:SetScale(VP_Settings.Scale, 2)

		VP_DimSlider:SetValue(VP_Settings.DimOpacity)
		VP_DimSliderValue:SetText(VP_Settings.DimOpacity)
		
		VP_SpeedSliderHigh:SetText("")
		VP_SpeedSliderLow:SetText("")
		VP_SpeedSlider:SetValue(VP_Settings.Speed)
		VP_SpeedSliderValue:SetText("Speed: "..VP_Settings.Speed)
		
		VP_PianoTransparencySlider:SetValue(VP_Settings.Buttons[4])
		VP_PianoTransparencySliderValue:SetText(VP_Settings.Buttons[4])
		
		RunHandlerScripts()
		CreateDropDownButton()
		if (isCurrent) then
			RegisterAddonMessagePrefix("VP_SCRIPT")
			RegisterAddonMessagePrefix("VP_Key")
		end
		--Greeting message on load
		VP_MSG("by |cff0070DETrucidare|r - Corecraft. Type /vp play to start playing ");
		self:UnregisterEvent("ADDON_LOADED")
	elseif (event == "CHAT_MSG_ADDON" and not strmatch(arg4,UnitName("player"))) then
		if ((arg3 == "PARTY" and VP_PartyReceive:GetChecked()) or (arg3 == "GUILD" and VP_GuildReceive:GetChecked()) or (arg3 == "WHISPER" and VP_PlayerReceive:GetChecked()) or (arg3 == "RAID" and VP_RaidReceive:GetChecked())) then
			if (arg1 == "VP_Key") then
				VP_PlayNote(arg2)
				VP_CurrentlyPlayingText:SetText("Currently Playing: " .. arg4)
			elseif (arg1 == "VP_SCRIPT") then				
				local messageNumber
				local message
				if (VP_ReceivedScripts[arg4] == nil) then
					VP_ReceivedScripts[arg4] = {}
				end
				if (strmatch(arg2,"VP_MSG_LEN=") ~= nil) then --start message to identify how many messages we are about to receive
					if (VP_MessageLength[arg4] == nil) then
						VP_MessageLength[arg4] = {}
					end
					VP_MessageLength[arg4] = tonumber(strsub(arg2,12))
				else
					messageNumber, message = strsplit("|", arg2)
					VP_ReceivedScripts[arg4][tonumber(messageNumber)] = message
				end
				if (messageNumber == "1") then
					local receivedScript = ""
					for i, name in ipairs(VP_ReceivedScripts[arg4]) do
						receivedScript = receivedScript .. name
						if (i == VP_MessageLength[arg4]) then
							break --in the rare case that the sending player disconnects or reloads and then proceeds to send a different script
						end
					end
					if (not VP_PlayingSong) then
						VP_CurrentlyPlayingText:SetText("Currently Playing: " .. arg4)
						VP_MSG("Playing song sent from player " .. arg4)
						VP_PlayingSong = true
						if (not VP_PianoHeader:IsVisible()) then
							VPiano_TogglePianoFrame()
						end
						VP_isPlayingPlaylist = false
						VP_FormatSong(receivedScript)
					end
					 VP_ReceivedScripts[arg4] = nil --remove table if no longer needed
				end
			end
		end
	elseif (event == "PLAYER_REGEN_DISABLED" and VP_MainPianoWindow:IsVisible()) then 	--Close everything if player goes into combat
		VPiano_CloseAll()
	end
end
--Loads all the piano keys into a table for access
function VP_LoadKeys(self)
	tinsert(VP_Keys,self)
end
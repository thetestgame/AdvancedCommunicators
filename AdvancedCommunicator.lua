-----------------------------------------------------------------------------------------------
-- Client Lua Script for AdvancedCommunicators
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "CommunicatorLib"
require "Window"
require "Apollo"
require "DialogSys"
require "Quest"
require "MailSystemLib"
require "Sound"
require "GameLib"
require "Tooltip"
require "XmlDoc"
require "PlayerPathLib"
require "CommunicatorLib"
require "Unit"
require "CommDialog"
require "ICComm"
require "ICCommLib"
 
-----------------------------------------------------------------------------------------------
-- AdvancedCommunicators Module Definition
-----------------------------------------------------------------------------------------------
local AdvancedCommunicators = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------

local chanPCS = "__PCS__" 

local knDefaultWidth = 500
local knDefaultHeight = 173

-- TODO Hardcoded Colors for Items
local arEvalColors =
{
	[Item.CodeEnumItemQuality.Average] 		= ApolloColor.new("ItemQuality_Average"),
	[Item.CodeEnumItemQuality.Good] 		= ApolloColor.new("ItemQuality_Good"),
	[Item.CodeEnumItemQuality.Excellent]	= ApolloColor.new("ItemQuality_Excellent"),
	[Item.CodeEnumItemQuality.Superb] 		= ApolloColor.new("ItemQuality_Superb"),
	[Item.CodeEnumItemQuality.Legendary] 	= ApolloColor.new("ItemQuality_Legendary"),
	[Item.CodeEnumItemQuality.Artifact] 	= ApolloColor.new("ItemQuality_Artifact"),
	[Item.CodeEnumItemQuality.Inferior] 	= ApolloColor.new("ItemQuality_Inferior"),
}

local knSaveVersion = 4
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function AdvancedCommunicators:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function AdvancedCommunicators:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

function AdvancedCommunicators:SetupComms()
	self.Comm = ICCommLib.JoinChannel(chanPCS, ICCommLib.CodeEnumICCommChannelType.Global)
	self.Comm:SetJoinResultFunction("OnJoinResult", self)
	self.Comm:SetReceivedMessageFunction("OnMessageReceived", self)
	self.Comm:SetSendMessageResultFunction("OnMessageSent", self)
	self.Comm:SetThrottledFunction("OnMessageThrottled", self)
end
 
-----------------------------------------------------------------------------------------------
-- AdvancedCommunicators OnLoad
-----------------------------------------------------------------------------------------------
function AdvancedCommunicators:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("AdvancedCommunicator.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- AdvancedCommunicators OnDocLoaded
-----------------------------------------------------------------------------------------------
function AdvancedCommunicators:OnDocLoaded()

	if  self.xmlDoc == nil then
		return
	end
	
	if self.wndMain == nil then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "AdvancedCommunicatorsForm", nil, self) -- Do not rename. Datachron.lua references this.
		self.wndMain:Show(false, true)

		local tOffsets = {self.wndMain:GetAnchorOffsets()}
		self.tDefaultOffsets = {tOffsets[1], tOffsets[2], tOffsets[1] + knDefaultWidth, tOffsets[2] + knDefaultHeight}
		self.nRewardLeft, self.nRewardTop, self.nRewardRight, self.nRewardBottom = self.wndMain:FindChild("RewardsContainer"):GetAnchorOffsets()
		self.nDialogLeft, self.nDialogTop, self.nDialogRight, self.nDialogBottom = self.wndMain:FindChild("DialogFraming"):GetAnchorOffsets()
	end

	Apollo.RegisterEventHandler("HideCommDisplay",				"OnHideCommDisplay", self)
	Apollo.RegisterEventHandler("CloseCommDisplay",				"OnHideCommDisplay", self)
	Apollo.RegisterEventHandler("StopTalkingCommDisplay",		"OnStopTalkingCommDisplay", self)
	Apollo.RegisterEventHandler("CommDisplayQuestText",			"OnCommDisplayQuestText", self)
	Apollo.RegisterEventHandler("CommDisplayRegularText",		"OnCommDisplayRegularText", self)
	Apollo.RegisterEventHandler("Communicator_ShowQueuedMsg",	"OnCommunicator_ShowQueuedMsg", self)

	self.tGivenRewardData = {}
	self.tGivenRewardIcons = {}

	self.tChoiceRewardData = {}
	self.tChoiceRewardIcons = {}

	self.wndCommPortraitLeft = self.wndMain:FindChild("CommPortraitLeft")
	self.wndCommPortraitRight = self.wndMain:FindChild("CommPortraitRight")

	Apollo.RegisterEventHandler("WindowManagementReady", 	"OnWindowManagementReady", self)
	
	self:OnWindowManagementReady()
	self:SetupComms()

	-- Register Libraries
	self.json = Apollo.GetPackage("Lib:dkJSON-2.5").tPackage
	
	-- Register API 
	Apollo.RegisterEventHandler("CommPlayerMessage",    	"OnPlayerCommunicate", self)
	Apollo.RegisterEventHandler("CommNPCMessage",    	    "OnNPCCommunicate", self)
	Apollo.RegisterEventHandler("CommScanbotMessage",    	"OnScanbotCommunicate", self)
		
	-- Register handlers for events, slash commands and timer, etc.
	Apollo.RegisterSlashCommand("cpm", "OnAdvancedCommunicatorsOn", self)
end

function AdvancedCommunicators:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementRegister", {strName = Apollo.GetString("InputAction_Communicator"), nSaveVersion=2})
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("InputAction_Communicator"), nSaveVersion=2})
end

function AdvancedCommunicators:OnCloseBtn()
	Event_FireGenericEvent("CommDisplay_Closed") -- Let the datachron know we exited early
end

-----------------------------------------------------------------------------------------------
-- AdvancedCommunicators API
-----------------------------------------------------------------------------------------------

function AdvancedCommunicators:OnPlayerCommunicate(input)
	local tMessage = {
		idCreature=input.player,
		strCreatureName=player,
		strType="Player",
		idMsg=4,
		tLayout={
			eBackground=0,
			ePortraitPlacement=0,
			eOverlay=0,
			fDuration=7.5000004768372
		},
		strMessageText=input.message
	}
	self:ProcsesCommunicatorMessage(tMessage) -- INJECT!
end

function AdvancedCommunicators:OnScanbotCommunicate(input)
	local tMessage = {
		idCreature=input.bot,
		strCreatureName="Testing",
		strType="Scanbot",
		idMsg=4,
		tLayout={
			eBackground=0,
			ePortraitPlacement=0,
			eOverlay=0,
			fDuration=7.5000004768372
		},
		strMessageText=input.message
	}
	self:ProcsesCommunicatorMessage(tMessage) -- INJECT!
end

function AdvancedCommunicators:OnNPCCommunicate(input)
	if input.idMsg == nil then
		input.idMsg = 4
	end
	local tMessage = {
		idCreature=input.npcId,
		strType="Spam",
		idMsg=input.idMsg,
		tLayout={
			eBackground=0,
			ePortraitPlacement=0,
			eOverlay=0,
			fDuration=7.5000004768372
		},
		strMessageText=input.message
	}
	self:OnCommunicator_ShowQueuedMsg(tMessage) -- INJECT!	
end

-----------------------------------------------------------------------------------------------
-- AdvancedCommunicators Functions
-----------------------------------------------------------------------------------------------

-- on SlashCommand "/cpm"
function AdvancedCommunicators:OnAdvancedCommunicatorsOn(cmd, arg)
	words = self:explodeString(" ", arg)
	local playerName = words[1] .. " " ..words[2]
	words[1] = ""
	words[2] = ""
	
	local Message = ""
	for id,part in ipairs(words) do
		Message = Message.. "" ..part.. " "
	end
	
	self:SendMessage(playerName, Message)
end

---------------------------------------------------------------------------------------------------
-- AdvancedCommunicators Events
---------------------------------------------------------------------------------------------------

function AdvancedCommunicators:OnShowCommDisplay()
	self.wndMain:Show(true)
	self.wndCommPortraitLeft:Show(true)
	self.wndCommPortraitRight:Show(true)
end

function AdvancedCommunicators:OnHideCommDisplay()
	self.wndMain:Show(false)
	self.wndCommPortraitLeft:Show(false)
	self.wndCommPortraitLeft:StopTalkSequence()
	self.wndCommPortraitRight:Show(false)
	self.wndCommPortraitRight:StopTalkSequence()
	self:OnCloseCommDisplay()
end

function AdvancedCommunicators:OnStopTalkingCommDisplay()
	self.wndMain:UnpauseAnim()
	self.wndCommPortraitLeft:StopTalkSequence()
	self.wndCommPortraitRight:StopTalkSequence()
end

function AdvancedCommunicators:OnCloseCommDisplay()
	local tOffsets = {self.wndMain:GetAnchorOffsets()}
	self.tDefaultOffsets = {tOffsets[1], tOffsets[2], tOffsets[1] + knDefaultWidth, tOffsets[2] + knDefaultHeight}
	self.tChoiceRewardData = {}
	self.tGivenRewardData = {}
	self.nCurTextHeight = 0

	if self.wndMain ~= nil then
		self.wndMain:Show(false)
	end
end

function AdvancedCommunicators:OnCommDisplayRegularText(idMsg, idCreature, strMessageText, tLayout)
	local pmMission = CommunicatorLib.GetPathMissionDelivered(idMsg)
	if pmMission then
		return
	end

	local tCommToQueue =
	{
		strType = "Spam",
		idMsg = idMsg,
		idCreature = idCreature,
		strMessageText = strMessageText,
		tLayout = tLayout,
	}
	
	CommunicatorLib.QueueMessage(tCommToQueue)
end

function AdvancedCommunicators:OnCommDisplayQuestText(idState, idQuest, bIsCommCall, tLayout)	
	local tCommToQueue =
	{
		strType = "Quest",
		idState = idState,
		idQuest = idQuest,
		bIsCommCall = bIsCommCall,
		tLayout = tLayout,
		cdDialog = DialogSys.GetNPCText(idQuest),
		idCreature = DialogSys.GetCommCreatureId()
	}
	
	CommunicatorLib.QueueMessage(tCommToQueue)
end

function AdvancedCommunicators:OnCommunicator_ShowQueuedMsg(tMessage)
	if tMessage == nil then
		return
	end

	if tMessage.strType == "Spam" or tMessage.strType == "Quest" then
		tMessage.strCreatureName = Creature_GetName(tMessage.idCreature)
	end
	self:ProcsesCommunicatorMessage(tMessage)
end

function AdvancedCommunicators:ProcsesCommunicatorMessage(tMessage)
	if tMessage == nil then
		return
	end

	if tMessage.strCreatureName == nil then
		tMessage.strCreatureName = "Static"
	end
	
	if tMessage.strType == "Quest" then
		-- From Datachron
		self.wndMain:DetachAnim()
	
		self:OnShowCommDisplay()
	
		self.wndCommPortraitLeft:PlayTalkSequence()
		self.wndCommPortraitRight:PlayTalkSequence()
		self.wndMain:FindChild("DialogText"):SetAML("")
		self.wndMain:FindChild("CloseBtn"):Show(false)
	
		self.tChoiceRewardData = {}
		self.tGivenRewardData = {}
		local strMessageText = ""
		
		if tMessage.cdDialog ~= nil then
			strMessageText = tMessage.cdDialog:GetText()
			if tMessage.cdDialog:HasVO() then
				tMessage.cdDialog:PlayVO()
			end
		end
		
		if strMessageText == nil or string.len(strMessageText) == 0 then
			strMessageText = ""
		end
	
		local tOffsets = {self.wndMain:GetAnchorOffsets()}
		self.tDefaultOffsets = {tOffsets[1], tOffsets[2], tOffsets[1] + knDefaultWidth, tOffsets[2] + knDefaultHeight}
	
		self:DrawText(tMessage.strType, strMessageText, "", tMessage.bIsCommCall, tMessage.tLayout, tMessage.idCreature, tMessage.strCreatureName, tMessage.idState, tMessage.idQuest)
		
	elseif tMessage.strType == "Spam" then
		self:OnShowCommDisplay()
	
		if CommunicatorLib.PlaySpamVO(tMessage.idMsg) then
			-- if we can play a real VO, then wait for the signal that that VO ended
			self.wndMain:SetAnimElapsedTime(9.0)
			self.wndMain:PauseAnim()
			Sound.Play(Sound.PlayUIDatachronSpam)
		else
			self.wndMain:PlayAnim(0)
			Sound.Play(Sound.PlayUIDatachronSpamNoVO)
		end
	
		self.wndCommPortraitLeft:PlayTalkSequence()
		self.wndCommPortraitRight:PlayTalkSequence()
	
		local tOffsets = {self.wndMain:GetAnchorOffsets()}
		self.tDefaultOffsets = {tOffsets[1], tOffsets[2], tOffsets[1] + knDefaultWidth, tOffsets[2] + knDefaultHeight}
	
		self.wndMain:FindChild("CloseBtn"):Show(true)
		self:DrawText(tMessage.strType, tMessage.strMessageText, "", true, tMessage.tLayout, tMessage.idCreature, tMessage.strCreatureName, nil, nil) -- 3rd argument: bIsCommCall
		
	elseif tMessage.strType == "Player" or tMessage.strType == "Scanbot" then
		self:OnShowCommDisplay()

		Sound.Play(Sound.PlayUIDatachronSpam)
	
		self.wndCommPortraitLeft:PlayTalkSequence()
		self.wndCommPortraitRight:PlayTalkSequence()
	
		local tOffsets = {self.wndMain:GetAnchorOffsets()}
		self.tDefaultOffsets = {tOffsets[1], tOffsets[2], tOffsets[1] + knDefaultWidth, tOffsets[2] + knDefaultHeight}
	
		self.wndMain:FindChild("CloseBtn"):Show(true)
		self:DrawText(tMessage.strType, tMessage.strMessageText, "", true, tMessage.tLayout, tMessage.idCreature, tMessage.strCreatureName, nil, nil) -- 3rd argument: bIsCommCall		
	end
end

-----------------------------------------------------------------------------------------------
-- AdvancedCommunicators Comm Functions
-----------------------------------------------------------------------------------------------

-- Sends a message as the current user to the ICCommLib channel
function AdvancedCommunicators:SendMessage(rec, msg)
	local packetRaw = {
		sender= GameLib:GetPlayerUnit():GetName(),
		receiver=rec,
		message=msg,
	}
	local packet = self.json.encode(packetRaw)
	if self.Comm:IsReady() then
		self.Comm:SendMessage(packet)
	end
	self:ProcessPacket(packet)
end

-- Decodes and processes a incoming packet from the ICCommLib channel
function AdvancedCommunicators:ProcessPacket(packetRaw)
	local json = self.json.decode(packetRaw)
	if json ~= nil then
		if json.receiver == GameLib:GetPlayerUnit():GetName() then
			local info = {player=GameLib.GetPlayerUnitByName(json.sender), message=json.message}
			self:OnPlayerCommunicate(info)
		end
	end
	return json
end

function AdvancedCommunicators:OnJoinResult(channel, eResult)
	local bBadName = eResult == ICCommLib.CodeEnumICCommJoinResult.BadName
	local bJoin = eResult == ICCommLib.CodeEnumICCommJoinResult.Join
	local bLeft = eResult == ICCommLib.CodeEnumICCommJoinResult.Left
	local bMissing = eResult == ICCommLib.CodeEnumICCommJoinResult.MissingEntitlement
	local bNoGroup = eResult == ICCommLib.CodeEnumICCommJoinResult.NoGroup
	local bNoGuild = eResult == ICCommLib.CodeEnumICCommJoinResult.NoGuild
	local bTooMany = eResult == ICCommLib.CodeEnumICCommJoinResult.TooManyChannels
	
	if bJoin then
		-- Do nothing
	elseif bLeft then
		Print('AdvancedCommunicators: Left ICComm Channel')
	elseif bBadName then
		Print('AdvancedCommunicators: Bad Channel Name')
	elseif bMissing then
		Print('AdvancedCommunicators: User doesn\'t have entitlement to job ICComm Channels')
	elseif bNoGroup then
		Print('AdvancedCommunicators: Group missing from channel Join attempt')
	elseif bNoGuild then
		Print('AdvancedCommunicators: Guild missing from channel Join attempt')
	elseif bTooMany then
		Print('AdvancedCommunicators: Too Many ICComm Channels exist')
	else
		Print('AdvancedCommunicators: Join Result didn\'t mat~h any of the Enum.')
	end
end

function AdvancedCommunicators:OnMessageReceived(channel, strMessage, strSender)
   --if channel == chanRPB then
		self:ProcessPacket(strMessage)
   --end
end

function AdvancedCommunicators:OnMessageSent(channel, eResult, idMessage)
	local mInvalid = eResult == ICCommLib.CodeEnumICCommMessageResult.InvalidText
	local mThrottled = eResult == ICCommLib.CodeEnumICCommMessageResult.Throttled
	local mMissing = eResult == ICCommLib.CodeEnumICCommMessageResult.MissingEntitlement
	local mNotIn = eResult == ICCommLib.CodeEnumICCommMessageResult.NotInChannel
    local mSent = eResult == ICCommLib.CodeEnumICCommMessageResult.Sent

	if mSent then
		--Do nothing
	elseif bInvalid then
		-- this one should never happen, but I'm including it for completeness
		-- and invalid message should never be resent
		Print(string.format('AdvancedCommunicators: Message Invalid, Id# %d', idMessage))
	elseif bMissing then
		-- if the recipient doesn't have rights, we shouldn't bother with a resend
		Print(string.format('AdvancedCommunicators: Recipient Can Not Receive, Id# %d', idMessage))
	elseif bNotIn then
		-- if there not in the channel, they're not a RPF user and they can be removed from tracking
		Print(string.format('AdvancedCommunicators: Recipient Not In Channel, Id# %d', idMessage))
	elseif bThrottled then
		-- if it's throttled, we need to wait for a bit, then attempt a resend
		-- we'll let OnMessageThrottled handle that
		-- move the message to the throttled queue
		Print(string.format('AdvancedCommunicators: Message Throttled, Id# %d', idMessage))
	else
		-- if none of those enums is true, something else has gone horribly wrong
		Print(string.format('AdvancedCommunicators: Unknown Error, Id# %d', idMessage))
	end	
end

---------------------------------------------------------------------------------------------------
-- AdvancedCommunicators private methods
---------------------------------------------------------------------------------------------------

function AdvancedCommunicators:DrawText(strType, strMessageText, strSubTitleText, bIsCommCall, tLayout, idCreature, strCreatureName, idState, idQuest)
	-- TODO Lots of format hardcoding
	--[[ Possible options on tLayout
		duration
		portraitPlacement: 0 left, 1 Right
		overlay: 0 default, 1 lightstatic, 2 heavystatic
		background: 0 default, 1 exiles, 2 dominion
	]]--
	self.wndMain:FindChild("PortraitContainerLeft"):Show(not tLayout or tLayout.ePortraitPlacement == CommunicatorLib.CommunicatorPortraitPlacement_Left)
	self.wndMain:FindChild("PortraitContainerRight"):Show(tLayout and tLayout.ePortraitPlacement == CommunicatorLib.CommunicatorPortraitPlacement_Right)
	self.wndMain:FindChild("HorizontalTopContainer"):ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.LeftOrTop)
	if tLayout then
		local wndFramingOrigin = self.wndMain:FindChild("Framing:SpecificFraming")
		local wndIconOrigin = self.wndMain:FindChild("SpecificIcon")
		if tLayout.eBackground == CommunicatorLib.CommunicatorBackground_Exiles then
			wndFramingOrigin:SetSprite("bk3:sprHolo_Alert_COMMAttachment_Exile")
			wndIconOrigin:SetSprite("bk3:sprHolo_Alert_COMMAttachment_ExileIcon")
		elseif tLayout.eBackground == CommunicatorLib.CommunicatorBackground_Dominion then
			wndFramingOrigin:SetSprite("bk3:sprHolo_Alert_COMMAttachment_Dominion")
			wndIconOrigin:SetSprite("bk3:sprHolo_Alert_COMMAttachment_DominionIcon")
		elseif tLayout.eBackground == CommunicatorLib.CommunicatorBackground_Drusera then
			wndFramingOrigin:SetSprite("bk3:sprHolo_Alert_COMMAttachment_Drusera")
			wndIconOrigin:SetSprite("bk3:sprHolo_Alert_COMMAttachment_DruseraIcon")
		elseif tLayout.eBackground == CommunicatorLib.CommunicatorBackground_TheEntity then
			wndFramingOrigin:SetSprite("bk3:sprHolo_Alert_COMMAttachment_Strain")
			wndIconOrigin:SetSprite("bk3:sprHolo_Alert_COMMAttachment_StrainIcon")
		else
			wndFramingOrigin:SetSprite("")
			wndIconOrigin:SetSprite("")
		end

		if tLayout.ePortraitPlacement == CommunicatorLib.CommunicatorPortraitPlacement_Right then
			self.wndMain:FindChild("HorizontalTopContainer"):ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.RightOrBottom)
		else
			self.wndMain:FindChild("HorizontalTopContainer"):ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.LeftOrTop)
		end
	end

	if not tLayout or tLayout.eOverlay == CommunicatorLib.CommunicatorOverlay_Default and idCreature ~= nil then
		self.wndMain:FindChild("StaticContainerL"):SetSprite("")
		self.wndMain:FindChild("StaticContainerR"):SetSprite("")
	elseif tLayout.eOverlay == CommunicatorLib.CommunicatorOverlay_LightStatic then
		self.wndMain:FindChild("StaticContainerL"):SetSprite("sprComm_StaticComposite")
		self.wndMain:FindChild("StaticContainerR"):SetSprite("sprComm_StaticComposite")
	elseif tLayout.eOverlay == CommunicatorLib.CommunicatorOverlay_HeavyStatic or idCreature == nil then
		self.wndMain:FindChild("StaticContainerL"):SetSprite("sprComm_StaticComposite")
		self.wndMain:FindChild("StaticContainerR"):SetSprite("sprComm_StaticComposite")
	end

	-- format the given text to display
	local strLeftOrRight = "Left"
	if strCreatureName == nil then
		strCreatureName = "Static"
	end

	if tLayout and tLayout.ePortraitPlacement == CommunicatorLib.CommunicatorPortraitPlacement_Right then
		strLeftOrRight = "Right"
	end

	if idCreature and idCreature ~= 0 then
		if strType == "Quest" or strType == "Spam" then
			if idCreature ~= nil then
				self.wndCommPortraitLeft:SetCostumeToCreatureId(idCreature)
				self.wndCommPortraitRight:SetCostumeToCreatureId(idCreature)
		
				if Creature_GetName(idCreature) then
					strCreatureName = Creature_GetName(idCreature)
				end
			else
				self.wndCommPortraitLeft:SetCostumeToCreatureId(nil)
				self.wndCommPortraitRight:SetCostumeToCreatureId(nil)
			end
		elseif strType == "Player" or strType == "Scanbot" then
			if idCreature ~= nil then
				self.wndCommPortraitLeft:SetCostume(idCreature)
				self.wndCommPortraitRight:SetCostume(idCreature)		
					
				strCreatureName = idCreature:GetName()	
			else
				self.wndCommPortraitLeft:SetCostume(nil)
				self.wndCommPortraitRight:SetCostume(nil)
			end
		end
	end

	local strSubtitleAppend = ""
	local strTextColor = "ff8096a8"

	if bIsCommCall then
		strTextColor = "ff62b383"
	end

	if strSubTitleText and strSubTitleText ~= "" then
		strSubtitleAppend = string.format("<P Font=\"CRB_InterfaceLarge_B\" TextColor=\"%s\" Align=\"%s\">%s</P>", strTextColor, strLeftOrRight, strSubTitleText)
	end

	self.wndMain:FindChild("DialogName"):SetAML(string.format("<P Font=\"CRB_HeaderMedium\" TextColor=\"%s\" Align=\"%s\">%s</P>", "UI_TextHoloTitle", strLeftOrRight, strCreatureName))
	self.wndMain:FindChild("DialogName"):SetHeightToContentHeight()
	self.wndMain:FindChild("DialogText"):SetAML(string.format("%s<P Font=\"CRB_InterfaceMedium\" TextColor=\"%s\" Align=\"%s\">%s</P>", strSubtitleAppend, strTextColor, strLeftOrRight, strMessageText))

	-- Draw Rewards
	local nRewardHeight = 0

	if idState ~= DialogSys.DialogState_TopicChoice then
		nRewardHeight = self:DrawRewards(self.wndMain, idState, idQuest)
	end

	self.wndMain:FindChild("RewardsContainer"):Show(nRewardHeight > 0)

	-- Resize for text over four lines (four lines is equal to 68 pixels at the moment) -- TODO Hardcoded formatting
	self.wndMain:FindChild("DialogText"):SetHeightToContentHeight()
	local nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("DialogText"):GetAnchorOffsets()
	local nContentX, nContentY = self.wndMain:FindChild("DialogName"):GetContentSize()
	local nOffsetY = 0
	self.wndMain:FindChild("DialogFraming"):SetAnchorOffsets(self.nDialogLeft, self.nDialogTop, self.nDialogRight, self.nDialogBottom)

	if (nTop + nBottom) > 68 and nContentY < 30 then -- 30 = 2 lines of text. Let's make everything 20px taller when the Title wraps
		nOffsetY = (nTop + nBottom) - 73
		self.wndMain:FindChild("DialogFraming"):SetAnchorOffsets(self.nDialogLeft, self.nDialogTop, self.nDialogRight, self.nDialogBottom + (nTop + nBottom) - 70)
	elseif (nTop + nBottom) > 68 and nContentY > 30 then
		nOffsetY = (nTop + nBottom) - 53
		self.wndMain:FindChild("DialogFraming"):SetAnchorOffsets(self.nDialogLeft, self.nDialogTop, self.nDialogRight, self.nDialogBottom + (nTop + nBottom) - 50)
	end

	-- Excess text expands down, & Rewards expand down
	self.wndMain:SetAnchorOffsets(self.tDefaultOffsets[1], self.tDefaultOffsets[2], self.tDefaultOffsets[3], self.tDefaultOffsets[4] + nRewardHeight + nOffsetY)
	self.wndMain:FindChild("RewardsContainer"):SetAnchorOffsets(self.nRewardLeft, self.nRewardTop + nOffsetY, self.nRewardRight, self.nRewardBottom)
end

function AdvancedCommunicators:DrawRewards(wndArg, idState, idQuest)
	-- Reset everything, especially if we don't even have rewards
	self.wndMain:FindChild("CashRewards"):Show(false)
	self.wndMain:FindChild("LootCashWindow"):Show(false)
	self.wndMain:FindChild("ReputationText"):Show(false)
	self.wndMain:FindChild("GivenContainer"):Show(false)
	self.wndMain:FindChild("ChoiceContainer"):Show(false)
	self.wndMain:FindChild("ChoiceRewardsText"):Show(false) -- Given Rewards Text lives in CashRewards
	self.wndMain:FindChild("GivenRewardsItems"):DestroyChildren()
	self.wndMain:FindChild("ChoiceRewardsItems"):DestroyChildren()

	if not idQuest or idQuest == 0 then
		return 0
	end

	local queView = DialogSys.GetViewableQuest(idQuest)

	if not queView then
		return 0
	end

	local tRewardInfo = queView:GetRewardData()

	local nGivenContainerHeight = 0
	if tRewardInfo.arFixedRewards and #tRewardInfo.arFixedRewards > 0 then
		for key, tCurrReward in ipairs(tRewardInfo.arFixedRewards) do
			if tCurrReward then
				wndArg:FindChild("CashRewards"):Show(true)
			end
			self:DrawLootItem(tCurrReward, wndArg:FindChild("GivenRewardsItems"))
		end

		nGivenContainerHeight = wndArg:FindChild("GivenRewardsItems"):ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
		wndArg:FindChild("GivenContainer"):SetAnchorOffsets(0, 0, 0, nGivenContainerHeight)
		wndArg:FindChild("GivenContainer"):Show(true)

		if wndArg:FindChild("CashRewards"):IsShown() then -- Since it can show twice
			nGivenContainerHeight = nGivenContainerHeight + wndArg:FindChild("CashRewards"):GetHeight()
		end -- Do resizing for the CashRewards after sizing the container
	end

	local nChoiceContainerHeight = 0
	if tRewardInfo.arRewardChoices and #tRewardInfo.arRewardChoices > 0 and idState ~= DialogSys.DialogState_QuestComplete then -- GOTCHA: Choices are shown in Player, not NPC for QuestComplete
		for key, tCurrReward in ipairs(tRewardInfo.arRewardChoices) do
			self:DrawLootItem(tCurrReward, wndArg:FindChild("ChoiceRewardsItems"))
		end

		nChoiceContainerHeight = wndArg:FindChild("ChoiceRewardsItems"):ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop, function(a,b) return b:FindChild("LootIconCantUse"):IsShown() end)
		wndArg:FindChild("ChoiceContainer"):SetAnchorOffsets(0, 0, 0, nChoiceContainerHeight)
		wndArg:FindChild("ChoiceContainer"):Show(true)
		wndArg:FindChild("ChoiceRewardsText"):Show(#tRewardInfo.arRewardChoices > 1)

		if #tRewardInfo.arRewardChoices > 1 then
			nChoiceContainerHeight = nChoiceContainerHeight + wndArg:FindChild("ChoiceRewardsText"):GetHeight()
		end -- Do text padding after SetAnchorOffsets so the box doesn't expand
	end

	wndArg:FindChild("RewardsArrangeVert"):ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
	if nGivenContainerHeight + nChoiceContainerHeight == 0 and not self.wndMain:FindChild("CashRewards"):IsShown() then
		return 0
	end
	return nGivenContainerHeight + nChoiceContainerHeight + 30 -- TODO hardcoded formatting
end

function AdvancedCommunicators:DrawLootItem(tCurrReward, wndParentArg)
	if tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_Money then
		local wndLootCashWindow = self.wndMain:FindChild("CashRewards"):FindChild("LootCashWindow")
		wndLootCashWindow:Show(true)
		wndLootCashWindow:SetMoneySystem(tCurrReward.eCurrencyType or 0)
		wndLootCashWindow:SetAmount(tCurrReward.nAmount, 0)
		wndLootCashWindow:FindChild("LootCashWindow"):SetTooltip(wndLootCashWindow:GetCurrency():GetMoneyString())
	end

	local strIconSprite = ""
	local wndCurrReward = nil
	if tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_Item then
		local itemReward = tCurrReward.itemReward
		wndCurrReward = Apollo.LoadForm(self.xmlDoc, "LootItem", wndParentArg, self)
		wndCurrReward:FindChild("LootIconCantUse"):Show(self:HelperPrereqFailed(itemReward))
		wndCurrReward:FindChild("LootDescription"):SetText(itemReward:GetName())
		wndCurrReward:FindChild("LootDescription"):SetTextColor(arEvalColors[itemReward:GetItemQuality()])
		wndCurrReward:SetData(tCurrReward.itemReward)
		Tooltip.GetItemTooltipForm(self, wndCurrReward, tCurrReward.itemReward, {bPrimary = true, bSelling = false, itemCompare = itemReward:GetEquippedItemForItemType()})
		strIconSprite = itemReward:GetIcon()

	elseif tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_TradeSkillXp then
		-- Tradeskill has overloaded fields: objectId is factionId. objectAmount is rep amount.
		wndCurrReward = Apollo.LoadForm(self.xmlDoc, "LootItem", wndParentArg, self)

		local strText = String_GetWeaselString(Apollo.GetString("CommDisp_TradeXPReward"), tCurrReward.nXP, tCurrReward.strTradeskill)
		wndCurrReward:FindChild("LootDescription"):SetText(strText)
		wndCurrReward:SetTooltip(strText)
		strIconSprite = "ClientSprites:Icon_ItemMisc_tool_0001"

	elseif tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_GrantTradeskill then
		-- Tradeskill has overloaded fields: objectId is tradeskillId.
		wndCurrReward = Apollo.LoadForm(self.xmlDoc, "LootItem", wndParentArg, self)
		wndCurrReward:FindChild("LootDescription"):SetText(tCurrReward.strTradeskill)
		wndCurrReward:SetTooltip("")
		strIconSprite = "ClientSprites:Icon_ItemMisc_tool_0001"

	elseif tCurrReward and tCurrReward.eType == Quest.Quest2RewardType_Reputation then
		wndCurrReward = Apollo.LoadForm(self.xmlDoc, "LootItem", wndParentArg, self)
		strIconSprite = "Icon_ItemMisc_UI_Item_Parchment"
		wndCurrReward:FindChild("LootDescription"):SetText(String_GetWeaselString(Apollo.GetString("Dialog_FactionRepReward"), tCurrReward.nAmount, tCurrReward.strFactionName))
		wndCurrReward:SetTooltip(String_GetWeaselString(Apollo.GetString("Dialog_FactionRepReward"), tCurrReward.nAmount, tCurrReward.strFactionName))
	end

	if wndCurrReward then
		wndCurrReward:FindChild("LootIcon"):SetSprite(strIconSprite)
	end
end

function AdvancedCommunicators:OnLootItemMouseUp(wndHandler, wndControl, eMouseButton)
	if eMouseButton == GameLib.CodeEnumInputMouse.Right and wndHandler:GetData() then
		Event_FireGenericEvent("GenericEvent_ContextMenuItem", wndHandler:GetData())
	end
end

function AdvancedCommunicators:OnGenerateTooltip(wndHandler, wndControl, eType, arg1, arg2)
	-- For reward icon events from XML
	local xml = nil
	if eType == Tooltip.TooltipGenerateType_ItemData then
		local itemCurr = arg1
		local itemEquipped = itemCurr:GetEquippedItemForItemType()

		Tooltip.GetItemTooltipForm(self, wndControl, itemCurr, {bPrimary = true, bSelling = self.bVendorOpen, itemCompare = itemEquipped})

	elseif eType == Tooltip.TooltipGenerateType_Reputation or tType == Tooltip.TooltipGenerateType_TradeSkill then
		xml = XmlDoc.new()
		xml:StartTooltip(Tooltip.TooltipWidth)
		xml:AddLine(arg1)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Money then
		xml = XmlDoc.new()
		xml:StartTooltip(Tooltip.TooltipWidth)
		xml:AddLine(arg1:GetMoneyString(), CColor.new(1, 1, 1, 1), "CRB_InterfaceMedium")
		wndControl:SetTooltipDoc(xml)
	else
		wndControl:SetTooltipDoc(nil)
	end
end

function AdvancedCommunicators:HelperPrereqFailed(tCurrItem)
	return tCurrItem and tCurrItem:IsEquippable() and not tCurrItem:CanEquip()
end

-----------------------------------------------------------------------------------------------
-- AdvancedCommunicators Utility functions
-----------------------------------------------------------------------------------------------

function AdvancedCommunicators:explodeString(div,str)
    if (div=='') then return false end
    local pos,arr = 0,{}
    for st,sp in function() return string.find(str,div,pos,true) end do
        table.insert(arr,string.sub(str,pos,st-1))
        pos = sp + 1
    end
    table.insert(arr,string.sub(str,pos))
    return arr
end

-----------------------------------------------------------------------------------------------
-- AdvancedCommunicators Instance
-----------------------------------------------------------------------------------------------
local AdvancedCommunicatorsInst = AdvancedCommunicators:new()
AdvancedCommunicatorsInst:Init()

----------------------------------------------------------------------------------------------
-- TaliLoot by Linda Giosue @Jabbit EU
-- Based on RollingDiceLootCouncil - Psyphil <Catharsis>
--
--TODO: Change those "check if item isn't already in table" with "removeDuplicates"

--[[local tStats = {
	[Unit.CodeEnumProperties.Strength]                   = {label = "Brutality",     short = "B"},
	[Unit.CodeEnumProperties.Dexterity]                  = {label = "Finesse",       short = "F"},
	[Unit.CodeEnumProperties.Technology]                 = {label = "Tech",          short = "T"},
	[Unit.CodeEnumProperties.Magic]                      = {label = "Moxie",         short = "M"},
	[Unit.CodeEnumProperties.Wisdom]                     = {label = "Insight",       short = "F"},
	[Unit.CodeEnumProperties.Stamina]                    = {label = "Grit",          short = "G"},
	[Unit.CodeEnumProperties.AssaultPower]               = {label = "Assault Power", short = "AP"},
	[Unit.CodeEnumProperties.SupportPower]               = {label = "Support Power", short = "SP"},
	[Unit.CodeEnumProperties.Rating_CritChanceIncrease]  = {label = "Crit",          short = "CHR"},
	[Unit.CodeEnumProperties.RatingCritSeverityIncrease] = {label = "Crit Severity", short = "CSR"},
	[Unit.CodeEnumProperties.Rating_AvoidReduce]         = {label = "Strikethrough", short = "SR"},
	[Unit.CodeEnumProperties.Armor]                      = {label = "Armor",         short = "A"},
	[Unit.CodeEnumProperties.ShieldCapacityMax]          = {label = "Shield",        short = "S"},
	[Unit.CodeEnumProperties.Rating_AvoidIncrease]       = {label = "Deflect",       short = "DR"},
	[Unit.CodeEnumProperties.Rating_CritChanceDecrease]  = {label = "Deflect Crit",  short = "DCR"},
	[Unit.CodeEnumProperties.PvPOffensiveRating]         = {label = "PvP Power",     short = " PvP PR"},
	[Unit.CodeEnumProperties.PvPDefensiveRating]         = {label = "PvP Defense",   short = " PvP DR"},
	[Unit.CodeEnumProperties.ManaPerFiveSeconds]         = {label = "Focus Regen",   short = "FR"},
	[Unit.CodeEnumProperties.BaseHealth]                 = {label = "Base Health",   short = "BH"},
}]]--

local tItemQualities = {
	[Item.CodeEnumItemQuality.Inferior]  = {label = "Inferior",  color = "ItemQuality_Inferior"},
	[Item.CodeEnumItemQuality.Average]   = {label = "Average",   color = "ItemQuality_Average"},
	[Item.CodeEnumItemQuality.Good]      = {label = "Good",      color = "ItemQuality_Good"},
	[Item.CodeEnumItemQuality.Excellent] = {label = "Excellent", color = "ItemQuality_Excellent"},
	[Item.CodeEnumItemQuality.Superb]    = {label = "Superb",    color = "ItemQuality_Superb"},
	[Item.CodeEnumItemQuality.Legendary] = {label = "Legendary", color = "ItemQuality_Legendary"},
	[Item.CodeEnumItemQuality.Artifact]  = {label = "Artifact",  color = "ItemQuality_Artifact"},
}
local tClassFromId = {
	"Warrior",
	"Engineer",
	"Esper",
	"Medic",
	"Stalker",
	"",
	"Spellslinger" 
}

--local [ChatSystemLib.ChatChannel_Party] = { Channel = "ChannelParty" }
local allChannels = ChatSystemLib.GetChannels()
local activeChannel = ChatSystemLib.ChatChannel_Party
local bCurrDistributing = false
local currItem = ""
local tLooters = ""
local tItemList = ""

-----------------------------------------------------------------------------------------------
-- Init

TaliLoot = {
	name = "TaliLoot",
	version = "0.1.3",

	nMaxItems = 80000,        -- FIXME: tune these
	nMaxDisplayedItems = 500, -- 
	nScanPerTick = 300,       --- probably needs something like
	nShowPerTick = 2000,      --- nShowPerTick/fShowInterval > nScanPerTick/fScanInterval
	fScanInterval = 1/20,     --- to ensure we display items faster than we scan them
	fShowInterval = 1/4,      --- so we don't hit 100% with more than nMaxDisplayedItems waiting to be drawn
 	
	tCategoryFilters = {},
	tSlotFilters = {},
	tStatFilters = {},
	tQualityFilters = {},
	tPriceFilters = {},
	nILvlMin = nil,
	nILvlMax = nil,
	
	tItems = {},
	nScanIndex = 1,
	nShowIndex = 1,
} 

-----------------------------------------------------------------------------------------------
-- TaliLoot OnLoad
-----------------------------------------------------------------------------------------------

function TaliLoot:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("TaliLoot.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
    self.wndMain = Apollo.LoadForm(self.xmlDoc, "TaliLoot", nil, self)

	self.wndItemList = self.wndMain:FindChild("ItemList")
	self.wndLeftSide = self.wndMain:FindChild("ToolTipContainer")
	self.HeaderNav = self.wndMain:FindChild("HeaderNav")
	self.wndStatusBar = self.wndMain:FindChild("StatusBar")
	self.btnDistribution = self.wndMain:FindChild("StartDistributionBtn")
	--Slash commands and events
	Apollo.RegisterSlashCommand("taliloot", "OnSlashCommand", self)
	Apollo.RegisterSlashCommand("tl", "OnSlashCommand", self)
	Apollo.RegisterSlashCommand("tltest", "OnTestCommand", self)
	Apollo.RegisterSlashCommand("tltime", "OnTimeCommand", self)
	Apollo.RegisterSlashCommand("tltimer", "OnTimerCommand", self)
	Apollo.RegisterSlashCommand("tlhelp", "OnHelpCommand", self)
	Apollo.RegisterSlashCommand("tlautocl", "OnAutoClCommand", self)
	Apollo.RegisterSlashCommand("tlautoadd", "OnAutoAddCommand", self)
	Apollo.RegisterSlashCommand("tlautorm", "OnAutoRmCommand", self)
	Apollo.RegisterSlashCommand("tlautols", "OnAutoLsCommand", self)
	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("ToggleTL", "OnSlashCommand", self)
	Apollo.RegisterEventHandler("ChatMessage", 					"OnChatMessage", self)
	Apollo.RegisterEventHandler("MasterLootUpdate",				"OnMasterLootUpdate", self)
	--Timer default values
	self.timerInterval=1 --Change it to 10 or something if you want. The timer doesn't have to be very precise
	self.timerTime= 60 --seconds

	--self.ICComm = ICCommLib.JoinChannel("LootCouncil", "OnICCommMessageReceived", self)
	tItemList = {}
end
function TaliLoot:OnDocLoaded()
	if GameLib.GetPlayerUnit() ~= nil then
		self.wndMain:FindChild("nameBox"):SetText(GameLib.GetPlayerUnit():GetName())
	end
	-- AUTO LIST == A LIST OF ITEMS TO AUTO REMOVE FROM MASTERLOOT(ex. Runes)
	-- The following list is the default one that will be overwritten if the a cusom one has been provided
	self.autoList= {"Divine Class Focus - Major","Divine Class Focus - Minor",
					"Divine Set Focus - Major","Divine Set Focus - Minor",
					"Pure Set Focus - Major","Pure Set Focus - Minor",
					"Pure Class Focus - Major","Pure Class Focus - Minor"}
	self.itemListAuto = {}
	self:restoreSettings()
	self.timer = ApolloTimer.Create(self.timerInterval, true, "OnRefresh", self)
	self.timer:Stop()
end

-----------------------------------------------------------------------------------------------
-- OnMasterLootUpdate
-----------------------------------------------------------------------------------------------
function TaliLoot:OnMasterLootUpdate()
--tMasterLoot contains the keys tLooters, itemDrop, nLootId, bIsMaster
	--tLooters: table with keys 1,2,3,etc contains Units viable for loot (in range)
	--itemDrop: contains Item that dropped
	--nLootId: individual item ID
	--bIsMaster}: true/false if you are masterlooter

	local tMasterLoot = GameLib.GetMasterLoot() 
	
	tLooters = {}
	tItemList = {}
	
	for i, value in pairs(tMasterLoot) do
	
		table.insert(tItemList, self:GetItemData(tMasterLoot[i]["itemDrop"]))
		
		for n, value in pairs(tMasterLoot[i]["tLooters"]) do
			table.insert(tLooters, tMasterLoot[i]["tLooters"][n])
		end
	end
	
	if table.getn(tItemList) == 0 then
		self.wndMain:FindChild("ItemCheckBtn"):SetText("No items found")
	elseif table.getn(tItemList) == 1 then
		self.wndMain:FindChild("ItemCheckBtn"):SetText(table.getn(tItemList) .. " item found")
	else
		self.wndMain:FindChild("ItemCheckBtn"):SetText(table.getn(tItemList) .. " items found")
	end
	
	self:CheckRaidAssist()
end

function TaliLoot:OnTestCommand()
	tItemList = {}
	for i = 69886, 69891 do
		local item = Item.GetDataFromId(i)
		table.insert(tItemList, self:GetItemData(item))
	end
end

-----------------------------------------------------------------------------------------------
-- UI Calls
-----------------------------------------------------------------------------------------------
--create ui
function TaliLoot:ShowItemTooltip(item)

	self.wndLeftSide:DestroyChildren()
	if item then
		self.currentlyShowedItem = item
		Tooltip.GetItemTooltipForm(self, self.wndLeftSide, item, {bPermanent = true, wndParent = self.wndLeftSide, bNotEquipped = true})
		local itemData = self:GetItemData(item)
		if self.wndItemList:GetChildren() ~= nil then
			for childk, childv in ipairs(self.wndItemList:GetChildren()) do
				if childv:GetData().strName == itemData.strName then
					childv:Show(true)
				else
					childv:Show(false)
				end
			end
		end
		self.wndItemList:ArrangeChildrenVert()
	end	
end

function TaliLoot:PopulateGearBtn(item)
	local btnUserGear = self.wndMain:FindChild("UserGearBtn")
	local item = self:GetItemData(item)
	itemEquipped = 0
	
	if item then
		local equipped = GameLib.GetPlayerUnit():GetEquippedItems()
		if not equipped then return end
		
		for _, iteminfo in pairs(equipped) do
			if item.eSlot == iteminfo:GetInventoryId() then
				local itemGear = self:GetItemData(iteminfo)
				btnUserGear:SetData(itemGear)
				btnUserGear:FindChild("ItemGearIcon"):GetWindowSubclass():SetItem(itemGear.item)
				itemEquipped = 1
			end
		end
	end
	if itemEquipped == 0 then
		btnUserGear:SetData({})
		btnUserGear:FindChild("ItemGearIcon"):GetWindowSubclass():SetItem("")
	end
end

function TaliLoot:OnOpenDropdown( wndHandler, wndControl, eMouseButton )

	wndDropdown = self.wndMain:FindChild("ItemDropDown")
	local wndDropdownList = wndDropdown:FindChild("ListDropDown")
	local EmptyLabel = wndDropdown:FindChild("EmptyLabel")
	
	EmptyLabel:Show(false)
	wndDropdown:Show(true)
	wndDropdownList:DestroyChildren()
	
	if not tItemList then
		EmptyLabel:Show(true)
		return
	end
	
	for i, v in pairs(tItemList) do
		local wndItem = Apollo.LoadForm(self.xmlDoc, "DropDownItem", wndDropdownList, self)
		wndItem:SetData(tItemList[i])
		wndItem:FindChild("ItemDropIcon"):GetWindowSubclass():SetItem(tItemList[i].item)
		
		local wndItemLabel = wndItem:FindChild("Label")
		wndItemLabel:SetText(tItemList[i].strName)
		wndItemLabel:SetTextColor(tItemQualities[tItemList[i].eQuality].color)
	end
	
	wndDropdownList:ArrangeChildrenVert()
end

function TaliLoot:ListItem(tSegment, sender, spec)
	-- List Item
	local item = self:GetItemData(tSegment.uItem)
	local wndItem = Apollo.LoadForm(self.xmlDoc, "Item", self.wndItemList, self)
	local wndItemText = wndItem:FindChild("ItemText")
	wndItem:SetData(item)
	wndItem:FindChild("ItemIcon"):GetWindowSubclass():SetItem(item.item)
	wndItemText:SetText(--[[item.strName .. "\n" 
						.. item.item:GetItemTypeName() 
						.. " - iLvl : "
						.. item.nEffectiveLevel
    		            .. "\n" .. spec )]]
						"\n".. spec .. "\n") 
						
	wndItemText:SetTextColor(tItemQualities[item.eQuality].color)
	for k,v in pairs(tItemQualities[item.eQuality]) do
	end
	--List character
	local wndChar = wndItem:FindChild("CharacterName")
	local wndClass = wndItem:FindChild("ClassIcon")
	
	wndChar:SetText(sender)

	if tLooters ~= "" then
		for i, value in pairs(tLooters) do
			if sender == tLooters[i]:GetName() then
				local strClass = tLooters[i]:GetClassId()
				if strClass == 1 then
					strClass = "Warrior"
				elseif strClass == 2 then
					strClass = "Engineer"
				elseif strClass == 3 then
					strClass = "Esper"
				elseif strClass == 4 then
					strClass = "Medic"
				elseif strClass == 5 then
					strClass = "Stalker"
				elseif strClass == 7 then
					strClass = "Spellslinger"
				end
				
				wndClass:SetSprite("Icon_Windows_UI_CRB_" .. strClass)
			end
		end
	else
		wndClass:SetSprite("")
	end
	self.wndItemList:ArrangeChildrenVert()
end

function TaliLoot:DeleteListing(tSegment, sender, spec)
	local itemData = self:GetItemData(tSegment.uItem)

	if itemData then
		if self.wndItemList:GetChildren() ~= nil then
			for childk, childv in ipairs(self.wndItemList:GetChildren()) do
				if childv:GetData().strName == itemData.strName and childv:FindChild("CharacterName"):GetText() == sender then
					childv:Destroy()
				end
			end
		end
		self.wndItemList:ArrangeChildrenVert()
	end	
end

--buttons
function TaliLoot:OnItemCheck( wndHandler, wndControl, eMouseButton )

	self.wndMain:FindChild("ItemCheckBtn"):SetCheck(false)
	currItem = wndControl:GetData().item
	self:ShowItemTooltip(currItem)
	--self:PopulateGearBtn(currItem)
	wndDropdown:Show(false)
end

function TaliLoot:OnItemClick(wndHandler, wndControl, eMouseButton)
	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		Event_FireGenericEvent("ItemLink", wndControl:GetData().item)
	end
end

function TaliLoot:OnClose()
	self.wndMain:Close()
end

--Mouse
function TaliLoot:OnItemMouseEnter(wndHandler, wndControl, x, y)
	if wndControl:GetData() then
		Tooltip.GetItemTooltipForm(self, wndControl, wndControl:GetData().item, {})
	end
end


-----------------------------------------------------------------------------------------------
-- SlashCommands
-----------------------------------------------------------------------------------------------
function TaliLoot:OnSlashCommand() 
	self:OnMasterLootUpdate()
	self.wndMain:Invoke()
end

function TaliLoot:OnHelpCommand()
	Print("=== Tali Loot ===")
	Print("/tl to show TaliLoot window")
	Print("/tltest to test addon")
	Print("/tltime [n] to set time distribution seconds (ex: \"/tltime 120\")")
	Print("/tltimer [n] to set timer interval seconds (ex: \"/tltimer 1\")")
	Print("/tlautoadd [string] to add an item to the auto loot list")
	Print("/tlautorm [string] to remove an item from the auto loot list")
	Print("/tlautocl to clear the auto loot list")
	Print("/tlautols [optionalString] to print the auto loot list")
end

function TaliLoot:OnTimeCommand(cmd, arg)
	local ban = tonumber(arg)
	if(ban>0 and ban<1000) then
		self.timerTime = ban
		Print("TL Time successfully setted to " .. ban)
	end
end

function TaliLoot:OnTimerCommand(cmd,arg)
	local ban = tonumber(arg)
	if(ban>0 and ban<20) then
		self.timerInterval = ban
		Print("TL Timer interval successfully setted to " .. ban)
	end
end

function TaliLoot:OnAutoClCommand(cmd,arg)
	self.autoList = {}
end

function TaliLoot:OnAutoAddCommand(cmd,arg)
	if arg ~= "" then
		local itemIsInList = false
		for k,v in pairs(self.autoList) do
			if v == tostring(arg) then
				itemIsInList = true
			end
		end
		if itemIsInList == false then
			table.insert(self.autoList,tostring(arg))
		end
	end
end

function TaliLoot:OnAutoRmCommand(cmd,arg)
	if arg ~= "" then
		for k,v in pairs(self.autoList) do
			if v == tostring(arg) then
				table.remove(self.autoList,k)
			end
		end
	end
end

function TaliLoot:OnAutoLsCommand(cmd, arg)
	Print("===Auto List==")
	for k,v in pairs(self.autoList) do
		if arg ~= "" then
			if string.match(string.lower(v), string.lower(arg)) then
				Print(v)
			end
		else
			Print(v)
		end
	end
end

Apollo.RegisterAddon(TaliLoot)
function TaliLoot:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "TaliLoot", {"ToggleTL", "", "IconSprites:Icon_ItemArmorNeck_Unidentified_Necklace_0004"})
end

---------------------------------------------------------------------------------------------------
-- TaliLoot Functions
---------------------------------------------------------------------------------------------------

function TaliLoot:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then return end
	local tsave = {}
	tsave.timer = {}
	tsave.timer[1] = tonumber(self.timerInterval)
	tsave.timer[2] = tonumber(self.timerTime)
	tsave.autoList = {}
	for k,v in pairs(self.autoList) do
	table.insert(tsave.autoList,v)
	end
	
	return tsave
end

function TaliLoot:OnRestore(eLevel, saveData)
	-- Just a common restore function
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then return end

	self.tSavedData = saveData
end

function TaliLoot:restoreSettings()
	if self.tSavedData ~= nil then
		if self.tSavedData["timer"] ~= nil and self.tSavedData["timer"][1] ~= nil and self.tSavedData["timer"][2] ~= nil then
			self.timerInterval = self.tSavedData["timer"][1]
			self.timerTime = self.tSavedData["timer"][2]
		end
		if table.getn(self.tSavedData["autoList"]) > 0 then
			self.autoList = {}
			for k,v in pairs(self.tSavedData["autoList"]) do
				table.insert(self.autoList,v)
			end
		end	
	end
end

function TaliLoot:removeDuplicates(tT)
	local hash = {}
	local res = {}

	for _,v in ipairs(tT) do
	   if (not hash[v]) then
		   res[#res+1] = v
		   hash[v] = true
	   end
	end
	return res
end

---------------------------------------------------------------------------------------------------
-- TaliLoot Button Functions
---------------------------------------------------------------------------------------------------
function TaliLoot:CheckRaidAssist()
	local groupMember = GroupLib.GetGroupMember(1)
	if groupMember and (groupMember.bIsLeader or groupMember.bMainTank or groupMember.bMainAssist or groupMember.bRaidAssistant) then
		self.wndStatusBar:Show(false)
		self.HeaderNav:Show(true)
	elseif groupMember then
		self.wndStatusBar:Show(true)
		self.HeaderNav:Show(false)
		self.wndMain:FindChild("extraButtons"):Show(false)	
	else
		self.wndStatusBar:Show(false)
		self.HeaderNav:Show(true)	
	end
end

function TaliLoot:OnStartDistribution( wndHandler, wndControl, eMouseButton)

	if table.getn(tItemList) ~= 0 then
		self.distributionTimeEnd = self:ConvertToSeconds(GameLib.GetLocalTime().nHour,GameLib.GetLocalTime().nMinute,GameLib.GetLocalTime().nSecond) + self.timerTime
		self.timer:Start()
		
		self.itemListAuto = {} -- Reset item assign to list (the one used for the "list to" button)
		
		allChannels[activeChannel]:Send( "==============================="						)
		allChannels[activeChannel]:Send( "== Distributing loot for " .. self.timerTime .. " seconds"		)
		allChannels[activeChannel]:Send( "== Write in party channel spec and item"	)
		allChannels[activeChannel]:Send( "== Example:\"MS <i9c99>\""	)
		allChannels[activeChannel]:Send( "==============================="						)

	else
		self.btnDistribution:SetCheck(false)
	end
end

function TaliLoot:OnStopDistribution( wndHandler, wndControl, eMouseButton, external )
	if bCurrDistributing then
		self.timer:Stop()
		allChannels[activeChannel]:Send( "== Distribution ended")
	end
end

function TaliLoot:LinkItem( wndHandler, wndControl, eMouseButton )
	Print(wndControl:GetData().item:GetName())
	if itemEquipped == 1 and bCurrDistributing then
		allChannels[activeChannel]:Send( wndControl:GetData().item:GetChatLinkString() )
	end
end

function TaliLoot:ConvertToSeconds(hours,minutes,seconds)
	local res = hours * 60 * 60 + minutes * 60 + seconds
	return res
end

function TaliLoot:NextRollItem( wndHandler, wndControl, eMouseButton )
	--local itemData = self:GetItemData(item)
	local firedEvent = false
	for i, v in pairs(tItemList) do
		if self.wndItemList:GetChildren() ~= nil then
			for childk, childv in ipairs(self.wndItemList:GetChildren()) do
				if childv:GetData().strName == tItemList[i].strName and firedEvent == false  then
					firedEvent=true
					self:ShowItemTooltip(childv:GetData().item)
				else
					--childv:Show(false)
				end
			end
		end
	end
end

function TaliLoot:AssignButtonPressed( wndHandler, wndControl, eMouseButton )
	local wndItem = wndHandler:GetParent()
	local wndChar = wndItem:FindChild("CharacterName")
	local tData = wndItem:GetData()
	local tItem = nil
	local looterID = nil
	local tMasterLoot = GameLib.GetMasterLoot() 
	for i, value in pairs(tMasterLoot) do
	
		if self:GetItemData(tMasterLoot[i]["itemDrop"]).strName == tData.strName then
			for k, v in pairs(tMasterLoot[i]["tLooters"]) do
				if wndChar:GetText() == v:GetName() then
					looterID = v
					tItem = i
				end
			end
		end
		
	end
	if looterID ~= nil and tItem ~= nil then
		GameLib.AssignMasterLoot(tMasterLoot[tItem].nLootId, looterID)
		local wndItemList= wndItem:GetParent()
		wndItem:Destroy()
		wndItemList:ArrangeChildrenVert()
	end
end

function TaliLoot:onListAdd( wndHandler, wndControl, eMouseButton )
	if self.currentlyShowedItem ~= nil then
		local itemData = self:GetItemData(self.currentlyShowedItem)
		local itemIsInList = false
		for k,v in pairs(self.itemListAuto) do
			if v == itemData.strName then
				itemIsInList = true
			end
		end
		if itemIsInList == false then
			table.insert(self.itemListAuto,itemData.strName)
		end
	end
end

function TaliLoot:onListRemove( wndHandler, wndControl, eMouseButton )
	if self.currentlyShowedItem ~= nil then
		local itemData = self:GetItemData(self.currentlyShowedItem)
		for k,v in pairs(self.itemListAuto) do
			if v == itemData.strName then
				table.remove(self.itemListAuto,k)
			end
		end
	end
end

function TaliLoot:onListClear( wndHandler, wndControl, eMouseButton )
	self.itemListAuto = {}
end

function TaliLoot:onListAssign( wndHandler, wndControl, eMouseButton )
	local name = self.wndMain:FindChild("nameBox"):GetText()
	if name ~= nil and name ~= "Character Nanme" then
		local tMasterLoot = GameLib.GetMasterLoot()
		local tItem = nil
		local looterID = nil
		for j, itemInList in pairs(self.itemListAuto) do
			looterID = nil
			tItem = nil
			for i, value in pairs(tMasterLoot) do
				if string.lower(self:GetItemData(tMasterLoot[i]["itemDrop"]).strName) == string.lower(itemInList) then
					for k, v in pairs(tMasterLoot[i]["tLooters"]) do
						if string.match(string.lower(v:GetName()),string.lower(name)) then
							looterID = v
							tItem = i
						end
					end
				end
			end
			if looterID ~= nil and tItem ~= nil then
				GameLib.AssignMasterLoot(tMasterLoot[tItem].nLootId, looterID)
				self.itemListAuto = {}
			end
		end
		
	end
end

function TaliLoot:onLeftoverBtn( wndHandler, wndControl, eMouseButton )
	local listOfItems = {}
	local itemFound = false
	local str
	local playerName = GameLib.GetPlayerUnit():GetName()
	local looterID = nil
	local tItem = nil
	local tMasterLoot = GameLib.GetMasterLoot()
	if self.wndItemList:GetChildren() ~= nil then
		for childk, childv in ipairs(self.wndItemList:GetChildren()) do
			itemFound = false
			str = childv:GetData().strName
			for k, v in pairs(listOfItems) do
				if str == v then
					itemFound = true
				end
			end
			if itemFound == false then
				table.insert(listOfItems,str)
			end	
		end
		for i, value in pairs(tMasterLoot) do
			looterID = nil
			tItem = nil
			itemFound = false
			for k, itemInList in pairs(listOfItems) do
				if self:GetItemData(tMasterLoot[i]["itemDrop"]).strName == itemInList then
					itemFound = true
				end
			end
			if itemFound == false then
				for k, v in pairs(tMasterLoot[i]["tLooters"]) do
					if v:GetName() == playerName then
						looterID = v
						tItem = i
					end
				end
				if looterID ~= nil and tItem ~= nil then
					GameLib.AssignMasterLoot(tMasterLoot[tItem].nLootId, looterID)
				end
			end
		end
	end
end

function TaliLoot:onListAuto( wndHandler, wndControl, eMouseButton )
	for k,v in pairs(self.autoList) do
		table.insert(self.itemListAuto,v)
	end
	self.itemListAuto=self:removeDuplicates(self.itemListAuto)

end
-----------------------------------------------------------------------------------------------
-- TaliLoot Chat Functions
-----------------------------------------------------------------------------------------------
function TaliLoot:OnChatMessage(channelCurrent, tMessage)
	if channelCurrent and channelCurrent:GetType() == activeChannel then
		local uItem = nil
		local fullStr = ""
		local segment
		local dListItem = 0
		for i, tSegment in ipairs( tMessage.arMessageSegments ) do
			fullStr = fullStr .. tSegment.strText
			if bCurrDistributing and tSegment.uItem ~= nil and self.checkItemInList(tSegment.uItem) then -- item link
				
				uItem = tSegment.uItem
				segment = tSegment
				if bBeingDistributed then
					self:ShowItemTooltip(uItem)
					--self:PopulateGearBtn(uItem)
					bBeingDistributed = false
				end
				
				
			elseif string.match(tSegment.strText,"== Distributing ") then -- starting distribution
				self.btnDistribution:SetText("Stop distribution (Started by: " .. tMessage.strSender ..")")
				self.wndStatusBar:SetText("Current Distribution By: " .. tMessage.strSender)
				self.btnDistribution:SetCheck(true)
				bCurrDistributing = true	
				bBeingDistributed = true
				self.wndItemList:DestroyChildren()
				
			elseif string.match(tSegment.strText ,"== Distribution ended") then -- ending distribution
			
				self.wndLeftSide:DestroyChildren()

				self.btnDistribution:SetText("Start New Distribution")
				self.wndStatusBar:SetText("No Distribution Active")
				self.btnDistribution:SetCheck(false)
				currItem = ""
				--self:PopulateGearBtn()
				bCurrDistributing = false

			end
		end
		if bCurrDistributing and uItem ~= nil then -- item link
			if bBeingDistributed then
				self:ShowItemTooltip(uItem)
				--self:PopulateGearBtn(uItem)
				bBeingDistributed = false
			else
				if string.match(string.lower(fullStr), "ms") then
					self:ListItem(segment, tMessage.strSender, "MS - Main Spec")
				elseif string.match(string.lower(fullStr), "os") then
					self:ListItem(segment, tMessage.strSender, "OS - Off Spec")
				elseif string.match(string.lower(fullStr),"cancel") or string.match(string.lower(fullStr),"pass") or string.match(string.lower(fullStr),"delete") then
					self:DeleteListing(segment,tMessage.strSender)
				else
					self:ListItem(segment, tMessage.strSender, "Other / Unspecified")
				end
					
			end
		end	
	end
end

-----------------------------------------------------------------------------------------------
-- TaliLoot Other Bullshit
-----------------------------------------------------------------------------------------------

function TaliLoot:GetItemData(item)
	--local item = Item.GetDataFromId(id)
	if item then
		local tItemInfo = item:GetDetailedInfo().tPrimary
		
		tItemInfo.item = item
		tItemInfo.eSlot = item:GetSlot()
		tItemInfo.tStats = {}
		
		for i=1,#(tItemInfo.arInnateProperties or {}) do
			local stat = tItemInfo.arInnateProperties[i]
			tItemInfo.tStats[stat.eProperty] = stat.nValue
		end
		
		for i=1,#(tItemInfo.arBudgetBasedProperties or {}) do
			local stat = tItemInfo.arBudgetBasedProperties[i]
			tItemInfo.tStats[stat.eProperty] = stat.nValue
		end
		
		return tItemInfo 
	end
end

function TaliLoot.StatsString(item)
	local tStrStats = {}
	
	for stat,value in pairs(item.tStats) do
		table.insert(tStrStats, string.format("%.0f", value)..(tStats[stat] and tStats[stat].short or "?"))
	end
	
 	return table.concat(tStrStats," | ")
end

function TaliLoot.checkItemInList(uItem)
	for i, v in pairs(tItemList) do
		if tItemList[i].item == uItem then return true end
	end
	return false
end

function TaliLoot:OnRefresh()
	local currentTime = self:ConvertToSeconds(GameLib.GetLocalTime().nHour,GameLib.GetLocalTime().nMinute,GameLib.GetLocalTime().nSecond)
	if currentTime > self.distributionTimeEnd then
		self.timer:Stop()
		self:OnStopDistribution()
	end
end

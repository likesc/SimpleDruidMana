
local UNIT_PLAYER = "player"
local POWERTYPE_MANA = 0 -- Enum.PowerType.Mana

local dummyTooltip -- Hooked for GameTooltip:SetShapeshift
local tmana = {
	["cur"] = -1,
	["max"] = 0,
	["sip"] = 0,
	["stance"] = 0,
}
local costCached = {0, 0, 0, 0, 0, 0, 0, 0, 0}
local function GetShapeshiftCost(i)
	if costCached[i] > 0 then return costCached[i] end
	dummyTooltip:SetShapeshift(i)
	local _, _, scost = string.find(dummyTooltip.costFontString:GetText() or "", "^(%d+)")
	local cost = tonumber(scost or "0")
	costCached[i] = cost
	return cost
end

local function GetCurrentStance()
	for i = 1, GetNumShapeshiftForms() do
		local _, _, active = GetShapeshiftFormInfo(i)
		if active then return i end
	end
	return 0
end

local function ManaBarUpdate(OnMana)
	local powerType = UnitPowerType(UNIT_PLAYER)
	if powerType == POWERTYPE_MANA then
		local cur = UnitMana(UNIT_PLAYER)
		local max = UnitManaMax(UNIT_PLAYER)
		local sip = cur - tmana.cur
		if OnMana and sip > 0 and cur < max and tmana.cur > -1 then
			if tmana.sip == 0 then DEFAULT_CHAT_FRAME:AddMessage("SimpleDruidMana is Ready") end
			tmana.sip = sip
		end
		tmana.cur = cur
		tmana.max = max
		tmana.stance = 0
		return
	end
	if tmana.cur == -1 then return end
	local stance = GetCurrentStance()
	local cur = OnMana and min(tmana.cur + tmana.sip, tmana.max) or tmana.cur
	if stance ~= tmana.stance then
		tmana.stance = stance
		cur = tmana.cur - GetShapeshiftCost(stance)
	end
	SimpleDruidManaBar:SetValue(cur / tmana.max)
	SimpleDruidManaBarText:SetText(cur)
	tmana.cur = cur
end

function SimpleDruidMana_OnLoad(self)
	local _, playerClass = UnitClass("player")
	if playerClass ~= "DRUID" then
		self:SetParent(nil)
		return
	end
	self:SetMinMaxValues(0, 1.0)
	self:SetValue(0)
	SimpleDruidManaBarText:SetText("unknown")
	self:RegisterEvent("PLAYER_LOGIN")
	self:RegisterEvent("UNIT_MANA")
	self:RegisterEvent("UNIT_DISPLAYPOWER")
	self:SetScript("OnEvent", function()
		local event, arg1 = event, arg1
		if arg1 == UNIT_PLAYER then
			if event == "UNIT_MANA" then
				ManaBarUpdate(true)
			elseif event == "UNIT_DISPLAYPOWER"  then
				local powerType = UnitPowerType(UNIT_PLAYER)
				if powerType == POWERTYPE_MANA then
					ManaBarUpdate(false)
					self:Hide()
				else
					self:Show()
				end
			end
		elseif event == "PLAYER_LOGIN" then
			-- for GameTooltip:SetShapeshift
			local frame = CreateFrame("GameTooltip")
			frame:SetOwner(WorldFrame, "ANCHOR_NONE")
			frame.costFontString = frame:CreateFontString()
			frame:AddFontStrings(frame:CreateFontString(), frame:CreateFontString())
			frame:AddFontStrings(frame.costFontString, frame:CreateFontString())
			dummyTooltip = frame
			-- Initialize
			SimpleDruidManaBarText:SetFont(PlayerFrameManaBarText:GetFont())
			ManaBarUpdate(false)
		end
	end)
end

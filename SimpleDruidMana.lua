
local UNIT_PLAYER = "player"
local POWERTYPE_MANA = 0 -- Enum.PowerType.Mana

local dummyTooltip -- Hooked for GameTooltip:SetShapeshift
local tmana = {
	["cur"] = -1,
	["max"] = 0,
	["sip"] = 0,
	["stance"] = 0,
	["mp5"] = 0,
}
local costCached = {0, 0, 0, 0, 0, 0, 0}
local function GetShapeshiftCost(i)
	if costCached[i] > 0 then return costCached[i] end
	dummyTooltip:SetShapeshift(i)
	local _, _, scost = string.find(dummyTooltip.costFontString:GetText() or "", "(%d+)")
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

-- TODO: Inaccurate mana
local function ManaBarUpdate(onManaEvent)
	local powerType = UnitPowerType(UNIT_PLAYER)
	local base = floor(UnitStat(UNIT_PLAYER, 5) / 5) + 15
	if powerType == POWERTYPE_MANA then
		local cur = UnitMana(UNIT_PLAYER)
		local max = UnitManaMax(UNIT_PLAYER)
		if onManaEvent and tmana.cur > -1 then
			local sip = cur - tmana.cur
			tmana.sip = sip > base and sip or base
			-- DEFAULT_CHAT_FRAME:AddMessage("mana-form sip : " .. sip .. ", base : " .. base)
		end
		tmana.cur = cur
		tmana.max = max
		tmana.stance = 0
		return
	end
	-- Bear/Cat form
	if tmana.cur == -1 then return end
	local stance = GetCurrentStance()
	if stance ~= tmana.stance then
		tmana.stance = stance
		tmana.cur = tmana.cur - GetShapeshiftCost(stance)
	elseif onManaEvent then
		local sip = tmana.sip
		if sip < base then
			sip = base
		elseif sip > base and tmana.mp5 > 0 then
			sip = sip - base
		end
		tmana.cur = min(tmana.cur + sip, tmana.max)
		-- DEFAULT_CHAT_FRAME:AddMessage("form:1/3 sip : " .. sip .. ", base : " .. base .. ", tmana.sip : " .. tmana.sip)
	end
	SimpleDruidManaBar:SetValue(tmana.cur / tmana.max)
	SimpleDruidManaBarText:SetText(tmana.cur)
end

local function OnUpdate()
	if tmana.mp5 > 0 then
		tmana.mp5 = tmana.mp5 - arg1
	end
end

function SimpleDruidMana_OnLoad(self)
	local _, playerClass = UnitClass(UNIT_PLAYER)
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
	self:RegisterEvent("SPELLCAST_STOP")

	self:SetScript("OnEvent", function()
		local event, arg1 = event, arg1
		if event == "UNIT_MANA" and arg1 == UNIT_PLAYER then
			ManaBarUpdate(true)
		elseif event == "UNIT_DISPLAYPOWER" and arg1 == UNIT_PLAYER  then
			local powerType = UnitPowerType(UNIT_PLAYER)
			if powerType == POWERTYPE_MANA then
				ManaBarUpdate(false)
				self:Hide()
			else
				self:Show()
			end
		elseif event == "SPELLCAST_STOP" then -- SPELLCAST_INTERRUPTED, SPELLCAST_FAILURE
			tmana.mp5 = 5.
		elseif event == "PLAYER_LOGIN" then
			-- Initialize
			local frame = CreateFrame("GameTooltip")
			frame:SetOwner(WorldFrame, "ANCHOR_NONE")
			frame.costFontString = frame:CreateFontString()
			frame:AddFontStrings(frame:CreateFontString(), frame:CreateFontString())
			frame:AddFontStrings(frame.costFontString, frame:CreateFontString())
			dummyTooltip = frame
			-- Sync
			SimpleDruidManaBarText:SetFont(PlayerFrameManaBarText:GetFont())
			ManaBarUpdate(false)
		end
	end)
	self:SetScript("OnUpdate", OnUpdate)
end

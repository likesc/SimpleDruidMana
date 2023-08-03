
local UNIT_PLAYER = "player"
local POWERTYPE_MANA = 0 -- Enum.PowerType.Mana
local SPELL_INNERVATE = "Interface\\Icons\\Spell_Nature_Lightning"

local scantip -- Hooked for GameTooltip:SetShapeshift
local tmana = {
	["cur"] = -1,
	["max"] = 0,
	["stance"] = 0,
	["timer"] = 0.,
	["reflection"] = 0, -- GetTalentInfo(3, 6)
	["base"] = 0,
	["innervate"] = false,  -- spell("innervate")
}
local costCached = {0, 0, 0, 0, 0, 0, 0}
local function GetShapeshiftCost(i)
	if costCached[i] > 0 then return costCached[i] end
	scantip:SetShapeshift(i)
	local _, _, scost = string.find(scantip.costFontString:GetText() or "", "(%d+)")
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

local function RefreshValues()
	local powerType = UnitPowerType(UNIT_PLAYER)
	if powerType == POWERTYPE_MANA then
		return
	end
	local statbase = UnitStat(UNIT_PLAYER, 5) / 5 + 15
	tmana.base = floor(statbase)
	-- reflection
	local _, _, _, _, rank = GetTalentInfo(3, 6)
	tmana.reflection = rank == 0 and 0 or floor(rank * 0.05 * statbase)
	-- innervate
	tmana.innervate = false
	local i, buff = 1
	repeat
		buff = UnitBuff("player", i)
		if buff == SPELL_INNERVATE then
			tmana.innervate = true
			break
		end
		i = i + 1
	until not buff
	-- DEFAULT_CHAT_FRAME:AddMessage("base : " .. tmana.base .. ", innervate : " .. tostring(tmana.innervate) .. ", reflection : " .. tmana.reflection)
	-- TODO detects Mana Per 5 Seconds from buffs
end

local function ManaBarUpdate(onManaEvent)
	local powerType = UnitPowerType(UNIT_PLAYER)
	if powerType == POWERTYPE_MANA then
		-- local prev = tmana.cur
		tmana.cur = UnitMana(UNIT_PLAYER)
		tmana.max = UnitManaMax(UNIT_PLAYER)
		tmana.stance = 0
		-- DEFAULT_CHAT_FRAME:AddMessage("sip : " .. (tmana.cur - prev) .. ", base : " .. (floor(UnitStat(UNIT_PLAYER, 5) / 5) + 15))
		return
	end
	-- Bear/Cat form
	if tmana.cur == -1 then return end
	local stance = GetCurrentStance()
	if stance ~= tmana.stance then
		tmana.stance = stance
		tmana.cur = tmana.cur - GetShapeshiftCost(stance)
	elseif onManaEvent then
		local regen
		if tmana.innervate then
			regen = tmana.base * 5
		else
			regen = tmana.timer > 0 and tmana.reflection or tmana.base
		end
		-- TODO: tmana.mp5 = Mana Per 5 Seconds
		tmana.cur = min(tmana.cur + regen, tmana.max)
	end
	SimpleDruidManaBar:SetValue(tmana.cur / tmana.max)
	SimpleDruidManaBarText:SetText(tmana.cur)
end

local function OnUpdate()
	if tmana.timer > 0 then
		tmana.timer = tmana.timer - arg1
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
	self:RegisterEvent("PLAYER_AURAS_CHANGED")
	self:RegisterEvent("UNIT_INVENTORY_CHANGED")

	self:SetScript("OnEvent", function()
		local event, arg1 = event, arg1
		if event == "UNIT_MANA" and arg1 == UNIT_PLAYER then
			ManaBarUpdate(true)
		elseif event == "UNIT_DISPLAYPOWER" and arg1 == UNIT_PLAYER then
			local powerType = UnitPowerType(UNIT_PLAYER)
			if powerType == POWERTYPE_MANA then
				ManaBarUpdate(false)
				self:Hide()
			else
				self:Show()
			end
		elseif event == "SPELLCAST_STOP" then
			-- SPELLCAST_STOP is before than UNIT_DISPLAYPOWER when shapeshift
			if UnitPowerType(UNIT_PLAYER) == POWERTYPE_MANA then
				tmana.timer = 5.0
			end
		elseif event == "PLAYER_AURAS_CHANGED" or (event == "UNIT_INVENTORY_CHANGED" and arg1 == UNIT_PLAYER) then
			RefreshValues()
		elseif event == "PLAYER_LOGIN" then
			-- Initialize
			local frame = CreateFrame("GameTooltip")
			frame:SetOwner(self, "ANCHOR_NONE")
			local notused = frame:CreateFontString()
			frame.lefts = {}
			for i = 1, 2 do
				local font = frame:CreateFontString()
				table.insert(frame.lefts, font)
				frame:AddFontStrings(font, notused)
			end
			frame.costFontString = frame.lefts[2]
			scantip = frame
			-- Sync
			SimpleDruidManaBarText:SetFontObject(PlayerFrameManaBarText:GetFontObject())
			SimpleDruidManaBarText:SetFont(PlayerFrameManaBarText:GetFont())
			ManaBarUpdate(false)
		end
	end)
	self:SetScript("OnUpdate", OnUpdate)
end
